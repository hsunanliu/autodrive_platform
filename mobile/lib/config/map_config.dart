// Mapbox 圖磚設定。
//
// token 只存在 gitignored 的 map_config.local.dart（CLAUDE.md 鐵律 3）。
// 首次設定：複製 map_config.local.dart.example 為 map_config.local.dart 並填入
// 你的 Mapbox public token（pk. 開頭）。
// 未設定 token 時退回 OSM 圖磚（樣式較陽春，功能不受影響）。
import 'map_config.local.dart' as local;

class MapConfig {
  static String get mapboxToken => local.mapboxToken;
  static bool get _hasToken => mapboxToken.isNotEmpty;

  static const String _osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// dark-v11、256px @2x 圖磚（TileLayer 預設 tileSize 即可）
  static String get darkTileUrl => _hasToken
      ? 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}@2x?access_token=$mapboxToken'
      : _osmTileUrl;

  /// light-v11、512px @2x 圖磚；搭配 [lightTileSize] 與 [lightZoomOffset] 使用，
  /// 退回 OSM 時兩者自動回到 256 / 0。
  static String get lightTileUrl512 => _hasToken
      ? 'https://api.mapbox.com/styles/v1/mapbox/light-v11/tiles/512/{z}/{x}/{y}@2x?access_token=$mapboxToken'
      : _osmTileUrl;
  static double get lightTileSize => _hasToken ? 512 : 256;
  static double get lightZoomOffset => _hasToken ? -1 : 0;
}
