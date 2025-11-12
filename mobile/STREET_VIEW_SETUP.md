# Google Street View Static API 設置指南

## 📋 功能說明

Flutter 移動應用已整合 Google Street View Static API，可在司機接單介面顯示上車點的街景圖片。

### 主要特性

✅ **動態載入街景**: 根據行程的經緯度座標自動載入街景圖片
✅ **可展開卡片**: 點擊展開/收起街景圖片，不佔用過多空間
✅ **失敗處理**: 如果街景圖片載入失敗，顯示預設 placeholder
✅ **不儲存至 IPFS**: 街景圖片直接從 Google API 載入，不佔用鏈上或 IPFS 儲存空間
✅ **自動緩存**: Flutter 的 Image.network 會自動緩存圖片

## 🔑 獲取 Google Maps API Key

### 步驟 1: 建立 Google Cloud 專案

1. 前往 [Google Cloud Console](https://console.cloud.google.com/)
2. 點擊頂部的專案選擇器
3. 點擊「新增專案」
4. 輸入專案名稱（例如：AutoDrive Mobile）
5. 點擊「建立」

### 步驟 2: 啟用必要的 API

在左側選單中選擇「API 和服務」→「程式庫」，依序啟用以下 API：

1. **Street View Static API** ⭐（必需）
2. **Maps SDK for Android** （如果要在 Android 上使用）
3. **Maps SDK for iOS** （如果要在 iOS 上使用）

### 步驟 3: 建立 API 金鑰

1. 在左側選單中選擇「API 和服務」→「憑證」
2. 點擊「+ 建立憑證」→「API 金鑰」
3. 複製產生的 API 金鑰（格式類似：`AIzaSyD...`）
4. **重要**: 點擊「限制金鑰」設定安全限制

### 步驟 4: 設定 API 金鑰限制（建議）

#### 應用程式限制

**Android 應用程式**:
- 選擇「Android 應用程式」
- 新增套件名稱：`com.example.autodrive`（根據實際修改）
- 新增 SHA-1 憑證指紋（可用 `keytool` 命令取得）

**iOS 應用程式**:
- 選擇「iOS 應用程式」
- 新增 Bundle ID：`com.example.autodrive`（根據實際修改）

#### API 限制
- 選擇「限制金鑰」
- 勾選以下 API：
  - ✅ Street View Static API
  - ✅ Maps SDK for Android
  - ✅ Maps SDK for iOS
- 點擊「儲存」

## ⚙️ 本地設定

### 1. 配置 API Key

#### 方法一：使用配置檔案（推薦）

```bash
cd mobile/lib/config
cp google_maps_config.example.dart google_maps_config.dart
```

編輯 `google_maps_config.dart`：

```dart
class GoogleMapsConfig {
  static const String apiKey = 'AIzaSyD...'; // 替換為您的實際 API Key
  static bool get isConfigured => apiKey != 'YOUR_GOOGLE_MAPS_API_KEY_HERE';
}
```

#### 方法二：使用環境變數

```bash
flutter run --dart-define=GOOGLE_MAPS_API_KEY=AIzaSyD...
```

或在 VS Code 的 `launch.json` 中設定：

```json
{
  "configurations": [
    {
      "name": "Flutter",
      "request": "launch",
      "type": "dart",
      "args": [
        "--dart-define=GOOGLE_MAPS_API_KEY=AIzaSyD..."
      ]
    }
  ]
}
```

### 2. 更新 .gitignore

確保 API Key 不會被提交到 Git：

```bash
echo "mobile/lib/config/google_maps_config.dart" >> .gitignore
```

### 3. Android 設定（如果需要）

編輯 `android/app/src/main/AndroidManifest.xml`：

```xml
<manifest>
    <application>
        <!-- Google Maps API Key -->
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="YOUR_API_KEY_HERE"/>
    </application>
</manifest>
```

### 4. iOS 設定（如果需要）

編輯 `ios/Runner/AppDelegate.swift`：

```swift
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_API_KEY_HERE")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

## 📊 使用說明

### 在司機端查看街景

1. 登入為司機身份
2. 前往「可接單行程」頁面
3. 每個行程卡片都會顯示「上車點街景」選項
4. 點擊展開即可查看街景圖片
5. 如果該位置沒有街景資料，會顯示 placeholder

### 小部件使用範例

#### 基本使用

```dart
import 'package:autodrive/widgets/street_view_image.dart';

StreetViewImage(
  latitude: 25.033964,
  longitude: 121.564472,
  width: 600,
  height: 300,
)
```

#### 可展開卡片

```dart
ExpandableStreetViewCard(
  latitude: 25.033964,
  longitude: 121.564472,
  title: '上車點街景',
  subtitle: '台北市信義區市府路1號',
)
```

#### 自訂參數

```dart
StreetViewImage(
  latitude: 25.033964,
  longitude: 121.564472,
  width: 800,
  height: 400,
  fov: 120,           // Field of View (0-120)
  heading: 90.0,      // 朝向東方
  pitch: 10.0,        // 向上傾斜 10 度
  borderRadius: 16.0,
)
```

## 💰 費用說明

### Google Street View Static API 定價

- **免費額度**: 每月前 28,000 次請求免費
- **超額費用**: 每 1,000 次請求 $7 USD

### 本應用優化

由於本應用的特性：
- 街景圖片僅在司機查看可接單行程時載入
- Flutter 的 Image.network 會自動緩存圖片
- 相同行程的街景圖片只會載入一次
- 圖片是展開式，不會自動載入

### 預估用量

假設每日有 200 個司機，每人查看 10 個行程的街景：
- 每月約需 60,000 次 API 查詢
- 超過免費額度約 32,000 次
- 每月額外成本約 $224 USD

## 🛠️ 技術細節

### API 端點

```
GET https://maps.googleapis.com/maps/api/streetview
```

### 請求參數

| 參數 | 說明 | 範例 |
|------|------|------|
| size | 圖片大小（最大 640x640） | 600x300 |
| location | 經緯度座標 | 25.033964,121.564472 |
| fov | 視野範圍 (0-120) | 90 |
| heading | 朝向角度 (0-360) | 0 |
| pitch | 俯仰角度 (-90~90) | 0 |
| key | API Key | AIzaSyD... |

### 回應格式

- 成功：返回 JPEG 圖片
- 失敗：返回錯誤狀態碼（如 404, 403）

### 錯誤處理

```dart
Image.network(
  streetViewUrl,
  errorBuilder: (context, error, stackTrace) {
    return PlaceholderWidget();
  },
)
```

## 🐛 疑難排解

### 問題 1: 圖片顯示 403 Forbidden

**可能原因**:
- API Key 無效或未設定
- API Key 限制設定錯誤
- Street View Static API 未啟用

**解決方法**:
1. 檢查 `google_maps_config.dart` 中的 API Key
2. 確認已啟用 Street View Static API
3. 檢查 API Key 的應用程式限制（Bundle ID / Package Name）

### 問題 2: 圖片顯示 placeholder

**可能原因**:
- 該位置沒有街景資料
- 網路連線問題
- API 配額已用完

**解決方法**:
1. 嘗試其他已知有街景的位置（如台北 101）
2. 檢查網路連線
3. 前往 Google Cloud Console 查看配額使用情況

### 問題 3: 圖片載入緩慢

**原因**: 圖片需要從 Google 伺服器下載

**解決方法**:
1. 減少圖片大小（如 400x200）
2. 使用展開式卡片，避免一次載入多張圖片
3. 考慮使用縮圖預覽

### 問題 4: Android 編譯錯誤

**錯誤訊息**: `Unresolved reference: GMSServices`

**解決方法**:
確認已在 `android/build.gradle` 中添加 Google Services：

```gradle
dependencies {
    classpath 'com.google.gms:google-services:4.3.15'
}
```

## 📚 相關檔案

- `mobile/lib/widgets/street_view_image.dart` - Street View 小部件實作
- `mobile/lib/config/google_maps_config.dart` - API Key 配置檔（不提交到 Git）
- `mobile/lib/config/google_maps_config.example.dart` - 配置檔範本
- `mobile/lib/pages/available_trips_page.dart` - 使用範例（司機接單頁面）

## 🔗 參考資源

- [Street View Static API 文檔](https://developers.google.com/maps/documentation/streetview/overview)
- [Google Cloud Console](https://console.cloud.google.com/)
- [API 定價說明](https://developers.google.com/maps/documentation/streetview/usage-and-billing)
- [Flutter Image.network 文檔](https://api.flutter.dev/flutter/widgets/Image/Image.network.html)

## ⚡ 最佳實踐

1. **延遲載入**: 使用展開式卡片，避免一次載入所有圖片
2. **圖片大小**: 行動裝置建議使用 600x300 或更小
3. **錯誤處理**: 總是提供 placeholder 以應對載入失敗
4. **API Key 安全**: 使用應用程式限制保護 API Key
5. **成本控制**: 監控 API 使用量，避免超額費用

## 📝 待辦事項

- [ ] 添加圖片載入進度指示器
- [ ] 支援多角度街景（向左/向右旋轉）
- [ ] 添加「在 Google Maps 中開啟」按鈕
- [ ] 實作圖片緩存策略（減少 API 查詢次數）
- [ ] 支援街景歷史版本（查看過去的街景）
