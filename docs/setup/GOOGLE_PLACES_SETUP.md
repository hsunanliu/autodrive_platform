# Google Places API 設置指南

## 📋 完整設置步驟

### 1. 申請 Google Cloud API Key

#### 步驟 1.1：創建 Google Cloud 項目

1. 前往 [Google Cloud Console](https://console.cloud.google.com/)
2. 點擊頂部的項目選擇器
3. 點擊「新增專案」
4. 輸入項目名稱：`AutoDrive`
5. 點擊「建立」

#### 步驟 1.2：啟用 Places API

1. 在左側選單選擇「API 和服務」→「資料庫」
2. 搜尋「Places API」
3. 點擊「Places API」
4. 點擊「啟用」

#### 步驟 1.3：啟用 Geocoding API（用於反向地理編碼）

1. 搜尋「Geocoding API」
2. 點擊「Geocoding API」
3. 點擊「啟用」

#### 步驟 1.4：創建 API 金鑰

1. 在左側選單選擇「API 和服務」→「憑證」
2. 點擊「建立憑證」→「API 金鑰」
3. 複製生成的 API 金鑰
4. 點擊「限制金鑰」（推薦）

#### 步驟 1.5：設置 API 金鑰限制（推薦）

**應用程式限制：**
- 選擇「iOS 應用程式」
- 添加套件識別碼：`com.autodrive.app`（或你的實際套件名稱）

**API 限制：**
- 選擇「限制金鑰」
- 勾選：
  - ✅ Places API
  - ✅ Geocoding API
- 點擊「儲存」

### 2. 設置計費（必需）

⚠️ **重要：即使使用免費額度，也必須設置計費帳戶**

1. 在左側選單選擇「帳單」
2. 點擊「連結帳單帳戶」
3. 創建新的帳單帳戶或選擇現有帳戶
4. 輸入信用卡資訊

**不用擔心：**
- 每月有 $200 免費額度
- 約 11,000 次免費請求
- 測試階段不會超過免費額度

### 3. 更新代碼中的 API Key

在 `mobile/lib/services/google_places_service.dart` 中：

```dart
// 替換這一行
static const String _apiKey = 'YOUR_GOOGLE_PLACES_API_KEY';

// 改為你的 API Key
static const String _apiKey = 'AIzaSy...你的API金鑰';
```

### 4. 安裝依賴

```bash
cd mobile
flutter pub get
```

### 5. 測試 API

創建測試腳本 `test_google_places.py`：

```python
import requests

API_KEY = 'YOUR_API_KEY'

# 測試自動完成
url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json'
params = {
    'input': '台北101',
    'key': API_KEY,
    'language': 'zh-TW',
    'components': 'country:tw'
}

response = requests.get(url, params=params)
print(response.json())
```

## 💰 費用說明

### 免費額度

每月免費：
- **$200 美元額度**
- 約 **11,000 次** Places API 請求
- 約 **40,000 次** Geocoding API 請求

### 計費方式

**Places API - Autocomplete:**
- 每次請求：$0.00283
- 每 1,000 次：$2.83

**Places API - Place Details:**
- 每次請求：$0.017
- 每 1,000 次：$17

**Geocoding API:**
- 每次請求：$0.005
- 每 1,000 次：$5

### 實際使用估算

假設每天：
- 100 次搜尋（Autocomplete）
- 20 次地點詳情（Place Details）
- 50 次反向地理編碼（Geocoding）

每月成本：
```
Autocomplete: 100 × 30 × $0.00283 = $8.49
Place Details: 20 × 30 × $0.017 = $10.20
Geocoding: 50 × 30 × $0.005 = $7.50
總計: $26.19
```

**結論：在 $200 免費額度內！**

## 🔒 安全性建議

### 1. 限制 API Key

✅ **應該做的：**
- 限制為 iOS 應用程式
- 限制為特定 API
- 設置每日配額

❌ **不應該做的：**
- 公開 API Key 到 GitHub
- 使用無限制的 API Key
- 在網頁中使用同一個 Key

### 2. 使用環境變量（生產環境）

創建 `mobile/lib/config/api_keys.dart`：

```dart
class ApiKeys {
  static const String googlePlaces = String.fromEnvironment(
    'GOOGLE_PLACES_API_KEY',
    defaultValue: 'YOUR_DEFAULT_KEY',
  );
}
```

在 `.gitignore` 中添加：
```
lib/config/api_keys.dart
```

### 3. 監控使用量

1. 前往 [Google Cloud Console](https://console.cloud.google.com/)
2. 選擇「API 和服務」→「資訊主頁」
3. 查看 API 使用量圖表
4. 設置配額警示

## 🎯 使用範例

### 在乘客主頁使用

```dart
import 'widgets/google_place_search_field.dart';

// 在 build 方法中
GooglePlaceSearchField(
  controller: _searchController,
  hintText: '搜尋目的地（地址、景點、地標）',
  userLocation: _userLocation,
  onPlaceSelected: (coordinates, address) {
    setState(() {
      _destination = coordinates;
      _destinationAddress = address;
    });
    _mapController.move(coordinates, 15);
    _getEstimate();
  },
)
```

### 點擊地圖獲取地址

```dart
FlutterMap(
  options: MapOptions(
    onTap: (tapPosition, point) async {
      final address = await GooglePlacesService.reverseGeocode(point);
      if (address != null) {
        setState(() {
          _destination = point;
          _destinationAddress = address;
          _searchController.text = address;
        });
      }
    },
  ),
  // ...
)
```

## ✅ 測試清單

- [ ] Google Cloud 項目已創建
- [ ] Places API 已啟用
- [ ] Geocoding API 已啟用
- [ ] API 金鑰已創建
- [ ] API 金鑰已設置限制
- [ ] 計費帳戶已連結
- [ ] API Key 已更新到代碼中
- [ ] 依賴已安裝 (`flutter pub get`)
- [ ] 測試搜尋「台北101」成功
- [ ] 測試搜尋「台北車站」成功
- [ ] 測試點擊地圖獲取地址成功

## 🐛 常見問題

### Q: API 請求返回 "REQUEST_DENIED"

**原因：**
- 沒有啟用 Places API
- 沒有設置計費帳戶
- API Key 限制設置錯誤

**解決：**
1. 確認 Places API 已啟用
2. 確認計費帳戶已連結
3. 檢查 API Key 限制設置

### Q: 搜尋沒有結果

**原因：**
- API Key 錯誤
- 網絡連接問題
- 搜尋關鍵字太短

**解決：**
1. 檢查 API Key 是否正確
2. 檢查網絡連接
3. 輸入至少 2 個字符

### Q: 費用超出預期

**原因：**
- 過於頻繁的 API 調用
- 沒有使用 debounce

**解決：**
1. 使用 debounce（已實現，400ms）
2. 設置每日配額限制
3. 監控 API 使用量

## 📚 相關文檔

- [Google Places API 文檔](https://developers.google.com/maps/documentation/places/web-service)
- [Geocoding API 文檔](https://developers.google.com/maps/documentation/geocoding)
- [計費說明](https://developers.google.com/maps/billing-and-pricing/pricing)

---

最後更新：2025-10-12
