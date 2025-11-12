// mobile/lib/services/map_http_client.dart

import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';

/// 地圖專用的 HTTP Client（單例模式）
///
/// 功能：
/// 1. 為 FlutterMap 提供持久化的 HTTP Client
/// 2. 避免 "Client is already closed" 錯誤
/// 3. 獨立於 ApiService 的 HttpClientManager
class MapHttpClient {
  static final MapHttpClient _instance = MapHttpClient._internal();
  factory MapHttpClient() => _instance;
  MapHttpClient._internal();

  http.Client? _client;
  TileProvider? _tileProvider;

  /// 獲取 HTTP Client
  http.Client get client {
    if (_client == null) {
      _client = http.Client();
      print('✅ MapHttpClient: 創建新的地圖專用 HTTP Client');
    }
    return _client!;
  }

  /// 重置 Client（用於錯誤恢復）
  void reset() {
    if (_client != null) {
      try {
        _client!.close();
      } catch (e) {
        print('⚠️ MapHttpClient: 關閉舊 client 時發生錯誤 - $e');
      }
    }
    _client = null;
    _tileProvider = null;
    print('🔄 MapHttpClient: 已重置');
  }

  /// 獲取單例的 TileProvider（用於 FlutterMap）
  ///
  /// 使用持久化的 HTTP Client 來避免 "Client is already closed" 錯誤
  /// 注意：這個 TileProvider 會被所有地圖共享，以確保使用同一個 HTTP Client
  static TileProvider getTileProvider() {
    if (_instance._tileProvider == null) {
      _instance._tileProvider = NetworkTileProvider(
        headers: {
          'User-Agent': 'AutoDrive Mobile App',
        },
        // 使用自定義的 HTTP Client (Client extends BaseClient)
        httpClient: _instance.client as http.BaseClient,
      );
      print('✅ MapHttpClient: 創建單例 TileProvider');
    }
    return _instance._tileProvider!;
  }
}
