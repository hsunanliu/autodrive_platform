import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uni_links/uni_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'driver_earnings_page.dart';
import 'driver_home_page_new.dart';
import 'pages/trip_in_progress_page.dart';
import 'login_page.dart' as login;
import 'passenger_home_page.dart';
import 'payment_page.dart';
import 'profile_page.dart';
import 'role_select_page.dart';
import 'services/api_service.dart';
import 'services/websocket_service.dart';
import 'services/sui_wallet_connector.dart';
import 'services/notification_service.dart';
import 'session_manager.dart';
import 'trip_history_page.dart';
import 'vehicle_register_page.dart';
// 新增錢包相關頁面
import 'pages/wallet_page.dart';
import 'pages/wallet_setup_page.dart';
import 'pages/register_with_wallet_connect_page.dart';
import 'pages/auth_page.dart';
import 'pages/available_trips_page.dart';

// 全域 WalletConnector 實例
final globalWalletConnector = SuiWalletConnector();

// Deep Link 訂閱
StreamSubscription? _linkSubscription;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Firebase（如果配置文件存在）
  try {
    await Firebase.initializeApp();
    print('✅ Firebase 初始化成功');

    // 設置背景消息處理器
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 初始化通知服務
    await NotificationService().initialize();
  } catch (e) {
    print('⚠️ Firebase 初始化失敗（可能未配置）: $e');
    print('   請參考 FIREBASE_SETUP_GUIDE.md 進行配置');
  }

  // 初始化 WalletConnector
  await globalWalletConnector.initialize();

  // 處理應用啟動時的 Deep Link
  try {
    final initialUri = await getInitialUri();
    if (initialUri != null) {
      print('📱 Initial Deep Link: $initialUri');
      await globalWalletConnector.handleWalletCallback(initialUri);
    }
  } catch (e) {
    print('❌ Failed to get initial URI: $e');
  }

  // 監聽應用運行時的 Deep Link
  _linkSubscription = uriLinkStream.listen((Uri? uri) {
    if (uri != null) {
      print('📱 Received Deep Link: $uri');
      globalWalletConnector.handleWalletCallback(uri);
    }
  }, onError: (err) {
    print('❌ Deep link error: $err');
  });

  final session = await SessionManager.loadSession();
  if (session != null) {
    ApiService.setToken(session.accessToken);
    // 如果用戶已登入，初始化 WebSocket 連接
    await WebSocketService().connect();
  }
  runApp(ProjectDappApp(initialSession: session));
}

class ProjectDappApp extends StatelessWidget {
  const ProjectDappApp({super.key, this.initialSession});

  final UserSession? initialSession;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Decentralized Ride App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF1DB954),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1DB954),
            foregroundColor: Colors.black,
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
          bodyLarge: TextStyle(color: Colors.white),
          titleLarge: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: _buildInitialHome(),
      routes: {
        '/role_select': (context) => const RoleSelectPage(),
        '/login': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
          final role = args['role']?.toString() ?? 'passenger';
          return login.LoginPage(role: role);
        },
        '/passenger': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final session = args?['session'] as UserSession? ?? initialSession;
          return PassengerHomePage(session: session);
        },
        '/driver': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final session = args?['session'] as UserSession? ?? initialSession;
          return DriverHomePageNew(session: session);
        },
        '/register_vehicle': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final session = args?['session'] as UserSession? ?? initialSession;
          return RegisterVehiclePage(session: session);
        },
        '/profile': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
          final session = args['session'] as UserSession? ?? initialSession;
          return ProfilePage(session: session);
        },
        '/payment': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
          final session = args['session'] as UserSession? ?? initialSession;
          return PaymentPage(
            fare: args['fare'],
            session: session,
            startAddress: args['start_address'],
            endAddress: args['end_address'],
            vehicleId: args['vehicle_id'],
            tripId: args['trip_id'] as int?,
          );
        },
        '/trip_history': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
          final session = args['session'] as UserSession? ?? initialSession;
          return TripHistoryPage(session: session);
        },
        '/driver_earnings': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
          final session = args['session'] as UserSession? ?? initialSession;
          return DriverEarningsPage(session: session);
        },
        '/trip_in_progress': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
          final session = args['session'] as UserSession? ?? initialSession;
          final tripId = args['tripId'] as int;
          return TripInProgressPage(session: session, tripId: tripId);
        },
        // 錢包相關路由
        '/wallet': (context) => const WalletPage(),
        '/wallet/setup': (context) => const WalletSetupPage(),
        '/register_with_wallet_connect': (context) => const RegisterWithWalletConnectPage(),
        // 認證路由
        '/auth': (context) => const AuthPage(),
        // 司機功能路由
        '/available_trips': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
          final session = args['session'] as UserSession? ?? initialSession;
          return AvailableTripsPage(session: session);
        },
      },
    );
  }

  Widget _buildInitialHome() {
    if (initialSession == null) {
      // 未登入時先顯示角色選擇頁面
      return const RoleSelectPage();
    }

    // 已登入：根據用戶類型跳轉
    if (initialSession!.role == 'driver') {
      return DriverHomePageNew(session: initialSession);
    } else if (initialSession!.role == 'both') {
      // "both" 類型用戶預設進入乘客頁面，可以在個人資料中切換
      return PassengerHomePage(session: initialSession);
    }

    return PassengerHomePage(session: initialSession);
  }
}
