/// 應用配置
///
/// 開發時可以創建 app_config.local.dart 來覆蓋這些設置
/// app_config.local.dart 不會被提交到 git

// 嘗試導入本地配置
import 'app_config.local.dart' as local;

class AppConfig {
  // 後端 API 配置
  static String get backendUrl {
    // 嘗試從本地配置讀取（如果存在）
    try {
      return local.localBackendUrl;
    } catch (e) {
      // 本地配置不存在，使用默認值
      print('⚠️ 未找到本地配置，使用默認 URL: $defaultBackendUrl');
      return defaultBackendUrl;
    }
  }

  // 默認後端 URL（提交到 git 的版本）
  static const String defaultBackendUrl = 'http://localhost:8000/api/v1';

  // WebSocket URL
  static String get websocketUrl {
    final baseUrl = backendUrl.replaceAll('/api/v1', '');
    return baseUrl;
  }

  // OSM 地圖配置
  static const String osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
}
