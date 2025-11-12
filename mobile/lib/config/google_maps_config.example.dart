// mobile/lib/config/google_maps_config.example.dart
/**
 * Google Maps API 配置範例檔案
 *
 * 使用方法：
 * 1. 複製此檔案為 google_maps_config.dart
 * 2. 在 google_maps_config.dart 中填入您的實際 API Key
 * 3. 確保 google_maps_config.dart 已加入 .gitignore
 */

class GoogleMapsConfig {
  /// Google Maps API Key
  /// 申請地址: https://console.cloud.google.com/google/maps-apis/credentials
  static const String apiKey = 'YOUR_GOOGLE_MAPS_API_KEY_HERE';

  /// 檢查 API Key 是否已設定
  static bool get isConfigured => apiKey != 'YOUR_GOOGLE_MAPS_API_KEY_HERE';
}
