# 板材庫存管理 Android 單機測試版

此版本已內建最新的 `板材庫存.xlsx`，APP 第一次建立資料庫時可作為初始資料來源使用。

## GitHub Actions 雲端編譯 APK

1. 用 GitHub 建立新的 Repository。
2. 將此專案全部檔案上傳。
3. 打開 Repository 的 **Actions**。
4. 選擇 **Build Android APK**。
5. 點 **Run workflow**。
6. 建置成功後，在該次 workflow 的 **Artifacts** 下載 `board-inventory-apk`。
7. 解壓縮後取得 `app-release.apk`，傳到 Android 手機安裝。

> 若 GitHub 提示 workflow 權限，允許 Actions 執行即可。
