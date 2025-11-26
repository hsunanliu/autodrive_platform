// 後端 API URL
// 現在使用 config/app_config.dart 來管理配置
// 本地開發時修改 config/app_config.local.dart（不提交到 git）
import 'config/app_config.dart';

final String backendUrl = AppConfig.backendUrl;

// 使用 OpenStreetMap 替代 Mapbox（免費、無需 API Key）
const osmTileUrl = AppConfig.osmTileUrl;
