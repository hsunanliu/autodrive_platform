// mobile/lib/services/notification_service.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;

/// 推送通知服務（單例）
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  bool _isInitialized = false;

  /// 獲取 FCM Token
  String? get fcmToken => _fcmToken;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 初始化推送通知服務
  Future<void> initialize() async {
    if (_isInitialized) {
      print('⚠️ NotificationService 已經初始化');
      return;
    }

    try {
      // 1. 請求通知權限
      await _requestPermission();

      // 2. 配置本地通知
      await _configureLocalNotifications();

      // 3. 獲取 FCM Token
      _fcmToken = await _firebaseMessaging.getToken();
      print('✅ FCM Token: $_fcmToken');

      // 4. 監聽 Token 刷新
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        print('🔄 FCM Token 已更新: $newToken');
        // TODO: 將新 Token 發送到後端
      });

      // 5. 配置消息處理
      _configureMessageHandlers();

      _isInitialized = true;
      print('✅ NotificationService 初始化完成');
    } catch (e) {
      print('❌ NotificationService 初始化失敗: $e');
    }
  }

  /// 請求通知權限
  Future<void> _requestPermission() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ 用戶已授予通知權限');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('⚠️ 用戶已授予臨時通知權限');
    } else {
      print('❌ 用戶拒絕通知權限');
    }
  }

  /// 配置本地通知
  Future<void> _configureLocalNotifications() async {
    // Android 配置
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 配置
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    print('✅ 本地通知配置完成');
  }

  /// 配置消息處理器
  void _configureMessageHandlers() {
    // 1. 處理前台消息
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 2. 處理背景消息（應用在背景但未終止）
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // 3. 處理應用終止時的消息
    _checkInitialMessage();

    print('✅ 消息處理器配置完成');
  }

  /// 處理前台消息（應用在前台時收到推送）
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📨 收到前台消息: ${message.messageId}');
    print('   標題: ${message.notification?.title}');
    print('   內容: ${message.notification?.body}');
    print('   數據: ${message.data}');

    // 在前台時顯示本地通知
    await _showLocalNotification(message);
  }

  /// 處理從通知打開應用（應用在背景時）
  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    print('📲 用戶點擊通知打開應用: ${message.messageId}');
    print('   數據: ${message.data}');

    // 處理導航邏輯
    _handleNotificationNavigation(message.data);
  }

  /// 檢查初始消息（應用終止時）
  Future<void> _checkInitialMessage() async {
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();

    if (initialMessage != null) {
      print('📲 應用通過通知啟動: ${initialMessage.messageId}');
      _handleNotificationNavigation(initialMessage.data);
    }
  }

  /// 顯示本地通知
  Future<void> _showLocalNotification(RemoteMessage message) async {
    // Android 通知渠道配置
    const androidChannel = AndroidNotificationChannel(
      'autodrive_orders', // id
      'AutoDrive 訂單通知', // name
      description: '接收新訂單和行程更新通知',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // 創建通知渠道（僅 Android）
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // 通知詳情
    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            androidChannel.id,
            androidChannel.name,
            channelDescription: androidChannel.description,
            icon: '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: data['trip_id']?.toString(),
      );
    }
  }

  /// 處理通知點擊後的導航
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    final type = data['type'];
    final tripId = data['trip_id'];

    print('🔔 處理通知導航: type=$type, trip_id=$tripId');

    // TODO: 實現導航邏輯
    // 例如：導航到行程詳情頁面
    if (type == 'new_trip' && tripId != null) {
      // Navigator.pushNamed(context, '/trip_details', arguments: tripId);
    }
  }

  /// 用戶點擊本地通知
  void _onNotificationTapped(NotificationResponse response) {
    print('🔔 用戶點擊本地通知: ${response.payload}');

    if (response.payload != null) {
      final tripId = int.tryParse(response.payload!);
      if (tripId != null) {
        // TODO: 導航到行程詳情
        print('   導航到行程: $tripId');
      }
    }
  }

  /// 發送測試通知（開發用）
  Future<void> sendTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'autodrive_orders',
      'AutoDrive 訂單通知',
      channelDescription: '接收新訂單和行程更新通知',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      0,
      '🚗 新訂單',
      '從台北101到台北車站，預估收益 \$150',
      details,
    );
  }

  /// 清除所有通知
  Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
  }
}

/// 處理背景消息的頂層函數
/// 注意：這個函數必須是頂層函數或靜態函數
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 確保 Firebase 已初始化
  // await Firebase.initializeApp();

  print('🔔 處理背景消息: ${message.messageId}');
  print('   標題: ${message.notification?.title}');
  print('   內容: ${message.notification?.body}');
  print('   數據: ${message.data}');

  // 可以在這裡執行背景任務，但不要執行 UI 操作
}
