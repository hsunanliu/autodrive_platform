// mobile/lib/config/google_maps_config.dart
/**
 * Google Maps API 配置
 *
 * ⚠️ 重要：請勿將此檔案提交到 Git（已加入 .gitignore）
 *
 * 使用方法：
 * 1. 複製 google_maps_config.example.dart 為 google_maps_config.dart
 * 2. 填入您的 Google Maps API Key
 * 3. 確保 API Key 已啟用以下服務：
 *    - Maps SDK for Android
 *    - Maps SDK for iOS
 *    - Street View Static API
 */

class GoogleMapsConfig {
  /// Google Maps API Key
  /// 申請地址: https://console.cloud.google.com/google/maps-apis/credentials
  static const String apiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'YOUR_GOOGLE_MAPS_API_KEY_HERE',
  );

  /// 檢查 API Key 是否已設定
  static bool get isConfigured => apiKey != 'YOUR_GOOGLE_MAPS_API_KEY_HERE';
}
