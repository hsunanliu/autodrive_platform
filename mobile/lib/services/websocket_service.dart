import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:project_dapp/session_manager.dart';
import 'package:project_dapp/services/api_service.dart';

/// WebSocket 服務
/// 負責管理 Socket.IO 連接、事件監聽和推送通知
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;
  String? _currentToken;

  // 事件監聽器回調
  final Map<String, List<Function(dynamic)>> _eventListeners = {};

  /// 是否已連接
  bool get isConnected => _isConnected;

  /// 初始化並連接 WebSocket
  Future<void> connect() async {
    // 如果已經連接，先斷開
    if (_socket != null) {
      disconnect();
    }

    // 獲取 token
    final session = await SessionManager.loadSession();
    if (session == null || session.accessToken.isEmpty) {
      print('❌ WebSocket: 無法連接，缺少 token');
      return;
    }

    _currentToken = session.accessToken;

    // 獲取 API 基礎 URL
    final apiUrl = ApiService.getBaseUrl();

    print('🔌 WebSocket: 嘗試連接到 $apiUrl');

    try {
      _socket = IO.io(
        apiUrl,
        IO.OptionBuilder()
            .setTransports(['websocket']) // 使用 WebSocket 傳輸
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(1000)
            .setAuth({'token': _currentToken}) // 傳遞 JWT Token
            .build(),
      );

      _setupSocketListeners();

      print('✅ WebSocket: 初始化完成');
    } catch (e) {
      print('❌ WebSocket: 連接失敗 - $e');
    }
  }

  /// 設置 Socket.IO 內建事件監聽器
  void _setupSocketListeners() {
    if (_socket == null) return;

    // 連接成功
    _socket!.onConnect((_) {
      _isConnected = true;
      print('✅ WebSocket: 已連接');
      _notifyListeners('connection_status', {'connected': true});
    });

    // 連接失敗
    _socket!.onConnectError((error) {
      print('❌ WebSocket: 連接錯誤 - $error');
      _isConnected = false;
      _notifyListeners('connection_status', {'connected': false, 'error': error});
    });

    // 斷開連接
    _socket!.onDisconnect((_) {
      _isConnected = false;
      print('🔌 WebSocket: 已斷開連接');
      _notifyListeners('connection_status', {'connected': false});
    });

    // 重連中
    _socket!.on('reconnecting', (attempt) {
      print('🔄 WebSocket: 重連中 (第 $attempt 次)');
    });

    // 連接成功響應
    _socket!.on('connected', (data) {
      print('📡 WebSocket: 收到連接確認 - $data');
    });

    // 錯誤事件
    _socket!.on('error', (error) {
      print('❌ WebSocket: 錯誤 - $error');
    });

    // 心跳回應
    _socket!.on('pong', (data) {
      print('💓 WebSocket: Pong - $data');
    });

    // 業務事件監聽
    _setupBusinessEventListeners();
  }

  /// 設置業務相關事件監聽器
  void _setupBusinessEventListeners() {
    if (_socket == null) return;

    // 行程相關事件
    _socket!.on('trip_accepted', (data) {
      print('📨 WebSocket: 收到 trip_accepted - $data');
      _notifyListeners('trip_accepted', data);
    });

    _socket!.on('trip_started', (data) {
      print('📨 WebSocket: 收到 trip_started - $data');
      _notifyListeners('trip_started', data);
    });

    _socket!.on('trip_arrived', (data) {
      print('📨 WebSocket: 收到 trip_arrived - $data');
      _notifyListeners('trip_arrived', data);
    });

    _socket!.on('trip_completed', (data) {
      print('📨 WebSocket: 收到 trip_completed - $data');
      _notifyListeners('trip_completed', data);
    });

    _socket!.on('trip_cancelled', (data) {
      print('📨 WebSocket: 收到 trip_cancelled - $data');
      _notifyListeners('trip_cancelled', data);
    });

    // 位置更新事件
    _socket!.on('driver_location_update', (data) {
      print('📍 WebSocket: 收到 driver_location_update');
      _notifyListeners('driver_location_update', data);
    });

    // 支付事件
    _socket!.on('payment_processing', (data) {
      print('📨 WebSocket: 收到 payment_processing - $data');
      _notifyListeners('payment_processing', data);
    });

    _socket!.on('payment_completed', (data) {
      print('📨 WebSocket: 收到 payment_completed - $data');
      _notifyListeners('payment_completed', data);
    });

    _socket!.on('payment_failed', (data) {
      print('📨 WebSocket: 收到 payment_failed - $data');
      _notifyListeners('payment_failed', data);
    });

    // 新行程通知（司機端）
    _socket!.on('new_trip_available', (data) {
      print('📨 WebSocket: 收到 new_trip_available - $data');
      _notifyListeners('new_trip_available', data);
    });

    // 加入房間確認
    _socket!.on('joined_trip', (data) {
      print('📨 WebSocket: 已加入行程房間 - $data');
      _notifyListeners('joined_trip', data);
    });

    // 離開房間確認
    _socket!.on('left_trip', (data) {
      print('📨 WebSocket: 已離開行程房間 - $data');
      _notifyListeners('left_trip', data);
    });

    // 新訊息（未來功能）
    _socket!.on('new_message', (data) {
      print('📨 WebSocket: 收到 new_message - $data');
      _notifyListeners('new_message', data);
    });
  }

  /// 通知所有監聽該事件的回調
  void _notifyListeners(String event, dynamic data) {
    if (_eventListeners.containsKey(event)) {
      for (var callback in _eventListeners[event]!) {
        try {
          callback(data);
        } catch (e) {
          print('❌ WebSocket: 事件監聽器執行失敗 ($event) - $e');
        }
      }
    }
  }

  /// 註冊事件監聽器
  ///
  /// [event] 事件名稱
  /// [callback] 回調函數
  void on(String event, Function(dynamic) callback) {
    if (!_eventListeners.containsKey(event)) {
      _eventListeners[event] = [];
    }
    _eventListeners[event]!.add(callback);
    print('✅ WebSocket: 已註冊監聽器 - $event');
  }

  /// 移除事件監聽器
  void off(String event, [Function(dynamic)? callback]) {
    if (callback == null) {
      _eventListeners.remove(event);
      print('✅ WebSocket: 已移除所有監聽器 - $event');
    } else {
      _eventListeners[event]?.remove(callback);
      print('✅ WebSocket: 已移除監聽器 - $event');
    }
  }

  /// 加入行程房間
  void joinTrip(int tripId) {
    if (_socket == null || !_isConnected) {
      print('❌ WebSocket: 無法加入房間，未連接');
      return;
    }

    _socket!.emit('join_trip', {'trip_id': tripId});
    print('📤 WebSocket: 發送 join_trip - trip_id: $tripId');
  }

  /// 離開行程房間
  void leaveTrip(int tripId) {
    if (_socket == null || !_isConnected) {
      print('❌ WebSocket: 無法離開房間，未連接');
      return;
    }

    _socket!.emit('leave_trip', {'trip_id': tripId});
    print('📤 WebSocket: 發送 leave_trip - trip_id: $tripId');
  }

  /// 更新司機位置（司機端使用）
  void updateLocation(int tripId, double lat, double lng) {
    if (_socket == null || !_isConnected) {
      print('❌ WebSocket: 無法更新位置，未連接');
      return;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _socket!.emit('update_location', {
      'trip_id': tripId,
      'lat': lat,
      'lng': lng,
      'timestamp': timestamp,
    });
    print('📤 WebSocket: 發送 update_location - trip: $tripId, lat: $lat, lng: $lng');
  }

  /// 發送聊天訊息（未來功能）
  void sendMessage(int tripId, String message) {
    if (_socket == null || !_isConnected) {
      print('❌ WebSocket: 無法發送訊息，未連接');
      return;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _socket!.emit('send_message', {
      'trip_id': tripId,
      'message': message,
      'timestamp': timestamp,
    });
    print('📤 WebSocket: 發送 send_message - trip: $tripId');
  }

  /// 發送心跳
  void ping() {
    if (_socket == null || !_isConnected) {
      return;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _socket!.emit('ping', {'timestamp': timestamp});
  }

  /// 通用的 emit 方法
  ///
  /// 發送任意事件到服務器
  /// [event] 事件名稱
  /// [data] 要發送的數據
  void emit(String event, dynamic data) {
    if (_socket == null || !_isConnected) {
      print('❌ WebSocket: 無法發送事件 $event，未連接');
      return;
    }

    _socket!.emit(event, data);
    print('📤 WebSocket: 發送 $event');
  }

  /// 斷開連接
  void disconnect() {
    if (_socket != null) {
      print('🔌 WebSocket: 主動斷開連接');
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    _isConnected = false;
    _eventListeners.clear();
  }

  /// 重新連接（例如 token 更新後）
  Future<void> reconnect() async {
    print('🔄 WebSocket: 重新連接');
    disconnect();
    await connect();
  }
}
