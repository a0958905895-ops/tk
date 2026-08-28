import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path/path.dart' as path; // 使用別名避免 BuildContext 衝突

void main() {
  runApp(const MaterialApp(
    home: Home(),
    debugShowCheckedModeBanner: false,
  ));
}

// 模擬資料庫類別
class DB {
  static Future<void> save(Map<String, dynamic> data, [dynamic id]) async {}
  static Future<void> del(dynamic id) async {}
}

const List<String> cols = [
  '日期',
  '請購單號',
  '來料交期',
  '料號',
  '替代料號',
  '基板材質',
  '套數',
  '工單尺寸',
  'PP層數',
  '是否請購',
  '使用庫存'
];

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String q = '';
  List<Map<String, dynamic>> rows = [];

  Future<void> load() async {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('板材庫存管理｜單機測試版'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: importExcel,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => edit(),
        icon: const Icon(Icons.add),
        label: const Text('新增'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜尋料號、請購單號、尺寸、PP規格',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onChanged: (v) {
                q = v;
                load();
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FilledButton.icon(
                onPressed: scanBarcode,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('掃描條碼'),
              ),
              OutlinedButton.icon(
                onPressed: photoOCR,
                icon: const Icon(Icons.camera_alt),
                label: const Text('拍照找料號'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final r = rows[i];
                return Card(
                  child: ListTile(
                    title: Text(r['料號'] ?? ''),
                    subtitle: Text(
                      '請購單：${r['請購單號'] ?? ''}\n尺寸：${r['工單尺寸'] ?? ''}',
                    ),
                    isThreeLine: true,
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if ((r['是否請購'] ?? '').toString().isNotEmpty)
                          const Icon(Icons.check_circle),
                        if ((r['使用庫存'] ?? '').toString().isNotEmpty)
                          const Text('庫存'),
                      ],
                    ),
                    onTap: () => edit(r),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> scanBarcode() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const Scanner()),
    );
    if (code != null) {
      q = code;
      await load();
      if (rows.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('找不到：$code')),
        );
      }
    }
  }

  Future<void> photoOCR() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera);
    if (x == null) return;
    final rec = TextRecognizer(script: TextRecognitionScript.latin);
    final text = await rec.processImage(InputImage.fromFilePath(x.path));
    await rec.close();
    final found = RegExp(r'[A-Za-z][A-Za-z0-9\-]{5,}')
        .allMatches(text.text)
        .map((m) => m.group(0)!)
        .toList();
    if (!mounted) return;
    final pick = found.isEmpty ? text.text : found.first;
    q = pick;
    await load();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('辨識結果'),
        content: Text('搜尋：$pick\n候選：${found.take(8).join(', ')}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  Future<void> edit([Map<String, dynamic>? r]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Edit(row: r)),
    );
    load();
  }

  Future<void> importExcel() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (res == null) return;
    final bytes = await File(res.files.single.path!).readAsBytes();
    final ex = Excel.decodeBytes(bytes);
    int n = 0;
    for (final sh in ex.tables.values) {
      if (sh.rows.isEmpty) continue;
      final heads =
          sh.rows.first.map((e) => e?.value.toString().trim() ?? '').toList();
      for (final row in sh.rows.skip(1)) {
        final m = <String, dynamic>{};
        for (int i = 0; i < cols.length; i++) {
          final j = heads.indexOf(cols[i]);
          m[cols[i]] =
              j >= 0 && j < row.length ? (row[j]?.value?.toString() ?? '') : '';
        }
        if (m.values.any((e) => e.toString().isNotEmpty)) {
          await DB.save(m);
          n++;
        }
      }
      break;
    }
    await load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已匯入 $n 筆')),
      );
    }
  }
}

class Scanner extends StatelessWidget {
  const Scanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('掃描條碼')),
      body: MobileScanner(
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              Navigator.pop(context, barcode.rawValue);
              break;
            }
          }
        },
      ),
    );
  }
}

class Edit extends StatefulWidget {
  final Map<String, dynamic>? row;
  const Edit({super.key, this.row});

  @override
  State<Edit> createState() => _EditState();
}

class _EditState extends State<Edit> {
  late final Map<String, TextEditingController> cs;
  bool req = false;
  bool stock = false;

  @override
  void initState() {
    super.initState();
    cs = {
      for (final c in cols.take(cols.length - 2))
        c: TextEditingController(text: widget.row?[c]?.toString() ?? '')
    };
    req = (widget.row?['是否請購'] ?? '').toString().isNotEmpty;
    stock = (widget.row?['使用庫存'] ?? '').toString().isNotEmpty;
  }

  @override
  void dispose() {
    for (final x in cs.values) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    final m = {
      for (final e in cs.entries) e.key: e.value.text.trim(),
      '是否請購': req ? 'V' : '',
      '使用庫存': stock ? 'V' : '',
    };
    await DB.save(m, widget.row?['id']);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.row == null ? '新增資料' : '編輯資料'),
        actions: [
          if (widget.row != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                await DB.del(widget.row!['id']);
                if (context.mounted) Navigator.pop(context);
              },
            )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...cs.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: e.value,
                  decoration: InputDecoration(
                    labelText: e.key,
                    border: const OutlineInputBorder(),
                  ),
                ),
              )),
          SwitchListTile(
            title: const Text('是否請購'),
            value: req,
            onChanged: (v) => setState(() => req = v),
          ),
          SwitchListTile(
            title: const Text('使用庫存'),
            value: stock,
            onChanged: (v) => setState(() => stock = v),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: save,
            icon: const Icon(Icons.save),
            label: const Text('儲存資料'),
          ),
        ],
      ),
    );
  }
}
