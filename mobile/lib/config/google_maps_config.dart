// mobile/lib/config/google_maps_config.dart
/**
 * Google Maps API 配置
 *
 * 使用方法：
 * 1. 複製 google_maps_config.local.dart.example 為 google_maps_config.local.dart
 * 2. 填入您的 Google Maps API Key
 * 3. 確保 API Key 已啟用以下服務：
 *    - Maps SDK for Android
 *    - Maps SDK for iOS
 *    - Street View Static API
 */

// 嘗試導入本地配置（如果存在）
import 'google_maps_config.local.dart' as local;

class GoogleMapsConfig {
  /// Google Maps API Key
  /// 申請地址: https://console.cloud.google.com/google/maps-apis/credentials
  static String get apiKey {
    try {
      return local.localGoogleMapsApiKey;
    } catch (e) {
      print('⚠️ 未找到本地 Google Maps API Key 配置');
      print('⚠️ 請複製 google_maps_config.local.dart.example 為 google_maps_config.local.dart');
      return 'YOUR_GOOGLE_MAPS_API_KEY_HERE';
    }
  }

  /// 檢查 API Key 是否已設定
  static bool get isConfigured => apiKey != 'YOUR_GOOGLE_MAPS_API_KEY_HERE';

  /// iOS Bundle ID（與 ios/Runner 的 PRODUCT_BUNDLE_IDENTIFIER 一致）。
  /// 用於讓 GCP 對此 key 的「iOS App 限制」能驗證 REST 呼叫來源。
  static const String iosBundleId = 'com.example.projectDapp';

  /// REST 呼叫要帶上的限制驗證 header。
  /// GCP 對「iOS App」限制的 key，會檢查此 header 是否等於允許的 bundle id；
  /// 原生 Maps SDK 會自動帶，但我們是用 http 直打 REST，需手動補上。
  static Map<String, String> get restrictionHeaders => {
        'X-Ios-Bundle-Identifier': iosBundleId,
      };
}
