// mobile/lib/services/http_client_manager.dart

import 'package:http/http.dart' as http;

/// HTTP Client 管理器
///
/// 功能：
/// 1. 單例 HTTP Client，避免重複創建
/// 2. 自動檢測 client 狀態，防止操作已關閉的 client
/// 3. 提供優雅關閉機制
/// 4. 防止 "Client is already closed" 錯誤
class HttpClientManager {
  static final HttpClientManager _instance = HttpClientManager._internal();
  factory HttpClientManager() => _instance;
  HttpClientManager._internal();

  http.Client? _client;
  bool _isClosing = false;

  /// 獲取 HTTP Client
  ///
  /// 如果 client 已關閉或不存在，自動創建新的 client
  http.Client get client {
    if (_client == null || _isClosing) {
      _client = http.Client();
      _isClosing = false;
      print('✅ HTTP Client: 已創建新的 client');
    }
    return _client!;
  }

  /// 檢查 client 是否可用
  bool get isAvailable => _client != null && !_isClosing;

  /// 重置 client（用於錯誤恢復）
  void reset() {
    if (_client != null) {
      try {
        _client!.close();
      } catch (e) {
        print('⚠️ HTTP Client: 關閉舊 client 時發生錯誤 - $e');
      }
    }
    _client = null;
    _isClosing = false;
    print('🔄 HTTP Client: 已重置');
  }

  /// 優雅關閉 client
  void close() {
    if (_client != null && !_isClosing) {
      _isClosing = true;
      try {
        _client!.close();
        print('🔌 HTTP Client: 已關閉');
      } catch (e) {
        print('❌ HTTP Client: 關閉時發生錯誤 - $e');
      } finally {
        _client = null;
        _isClosing = false;
      }
    }
  }

  /// 執行請求並自動處理錯誤
  ///
  /// 如果遇到 "Client is already closed" 錯誤，自動重試一次
  Future<http.Response> executeRequest(
    Future<http.Response> Function(http.Client) request,
  ) async {
    try {
      return await request(client);
    } on http.ClientException catch (e) {
      // 如果是 client 已關閉錯誤，重置並重試
      if (e.message.contains('Client is already closed') ||
          e.message.contains('Connection closed')) {
        print('⚠️ HTTP Client: 檢測到 client 已關閉，正在重試...');
        reset();
        return await request(client);
      }
      rethrow;
    }
  }
}
