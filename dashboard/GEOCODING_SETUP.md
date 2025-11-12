# Google Geocoding API 設置指南

## 📋 功能說明

本系統整合了 Google Geocoding API，可將行程記錄中的經緯度座標自動轉換為易讀的文字地址。

### 主要特性

✅ **自動地址轉換**: 在行程詳細頁面中，自動將座標轉換為地址
✅ **智能緩存**: 使用 localStorage 緩存已查詢的地址，30 天有效期
✅ **節省 API 次數**: 相同座標只查詢一次，大幅減少 API 用量
✅ **緩存匯出**: 可匯出所有地址緩存為 JSON 檔案備份
✅ **中文地址**: 自動返回繁體中文地址（language=zh-TW）

## 🔑 獲取 Google Geocoding API Key

### 步驟 1: 建立 Google Cloud 專案

1. 前往 [Google Cloud Console](https://console.cloud.google.com/)
2. 點擊頂部的專案選擇器
3. 點擊「新增專案」
4. 輸入專案名稱（例如：AutoDrive Platform）
5. 點擊「建立」

### 步驟 2: 啟用 Geocoding API

1. 在左側選單中選擇「API 和服務」→「程式庫」
2. 搜尋「Geocoding API」
3. 點擊「Geocoding API」
4. 點擊「啟用」按鈕

### 步驟 3: 建立 API 金鑰

1. 在左側選單中選擇「API 和服務」→「憑證」
2. 點擊「+ 建立憑證」→「API 金鑰」
3. 複製產生的 API 金鑰（格式類似：`AIzaSyD...`）
4. **重要**: 點擊「限制金鑰」設定安全限制

### 步驟 4: 設定 API 金鑰限制（建議）

#### 應用程式限制
- 選擇「HTTP 參照位址（網站）」
- 新增您的網站網址，例如：
  - `http://localhost:3000/*`
  - `https://yourdomain.com/*`

#### API 限制
- 選擇「限制金鑰」
- 勾選「Geocoding API」
- 點擊「儲存」

## ⚙️ 本地設定

### 1. 設定環境變數

編輯 `dashboard/.env` 檔案：

```bash
# 將 YOUR_API_KEY 替換為您的實際 API Key
REACT_APP_GOOGLE_GEOCODING_API_KEY=AIzaSyD...

# Backend API URL（通常不需要改）
REACT_APP_API_URL=http://localhost:8000
```

### 2. 重新啟動開發伺服器

```bash
cd dashboard
npm start
```

**注意**: React 需要重新啟動才能讀取新的環境變數。

## 📊 使用說明

### 在行程詳細頁面查看地址

1. 進入「行程詳細」頁面
2. 點擊任一行程的「查看」按鈕
3. 系統會自動將經緯度轉換為地址（首次查詢需要 1-2 秒）
4. 地址會自動緩存，下次查看立即顯示

### 匯出地址緩存

1. 在「行程詳細」頁面，點擊右上角的「匯出地址緩存」按鈕
2. 系統會下載 `geo_cache.json` 檔案
3. 檔案包含所有已緩存的地址資訊

## 🔍 快取管理

### 查看快取統計

打開瀏覽器開發者工具（F12），在 Console 中輸入：

```javascript
// 查看快取統計
geocodingService.getCacheStats()

// 輸出範例：
// {
//   totalEntries: 42,
//   oldestEntryDate: "2025-01-15T10:30:00.000Z",
//   cacheSize: 15234
// }
```

### 清除快取

如需清除所有快取：

```javascript
geocodingService.clearCache()
```

## 💰 費用說明

### Google Geocoding API 定價

- **免費額度**: 每月前 40,000 次請求免費
- **超額費用**: 每 1,000 次請求 $5 USD

### 本系統優化

由於本系統使用 localStorage 緩存：
- 相同座標只查詢一次
- 緩存有效期 30 天
- 實際 API 查詢次數大幅減少
- 一般使用情況下，不太會超過免費額度

### 預估用量

假設每日有 100 筆新行程（200 個新座標）：
- 每月約需 6,000 次 API 查詢
- 完全在免費額度內

## 🛠️ 技術細節

### 緩存機制

```javascript
// 緩存結構
{
  "timestamp": 1737900000000,
  "addresses": {
    "25.033964,121.564472": {
      "address": "台北市信義區市府路1號",
      "lat": 25.033964,
      "lng": 121.564472,
      "timestamp": 1737900000000
    }
  }
}
```

### 座標精度

- 系統將座標四捨五入到小數點後 6 位
- 精度約為 0.11 公尺
- 足以識別相同地點並復用緩存

### 批次查詢

系統支援批次查詢地址，並自動限速：
- 每批最多 10 個地址
- 批次之間延遲 1 秒
- 避免超過 API 速率限制

## 🐛 疑難排解

### 問題 1: 地址顯示為座標

**可能原因**:
- API Key 未設定或無效
- API 尚未啟用
- API Key 設定了錯誤的限制

**解決方法**:
1. 檢查 `.env` 檔案中的 API Key
2. 確認已啟用 Geocoding API
3. 檢查 API Key 限制設定
4. 開啟瀏覽器 Console 查看錯誤訊息

### 問題 2: 顯示 "REQUEST_DENIED"

**原因**: API Key 限制設定錯誤

**解決方法**:
1. 前往 Google Cloud Console
2. 編輯 API Key 的「應用程式限制」
3. 確認已新增 `http://localhost:3000/*`

### 問題 3: 顯示 "OVER_QUERY_LIMIT"

**原因**: 超過 API 配額或速率限制

**解決方法**:
1. 等待幾分鐘後重試
2. 檢查是否超過每日配額
3. 考慮啟用計費以提高配額

## 📚 相關檔案

- `dashboard/src/services/geocoding.js` - Geocoding 服務實作
- `dashboard/src/pages/TripDetails.jsx` - 行程詳細頁面（使用地址轉換）
- `dashboard/.env` - 環境變數設定檔
- `dashboard/.env.example` - 環境變數範本

## 🔗 參考資源

- [Google Geocoding API 文檔](https://developers.google.com/maps/documentation/geocoding)
- [Google Cloud Console](https://console.cloud.google.com/)
- [API 定價說明](https://developers.google.com/maps/documentation/geocoding/usage-and-billing)
