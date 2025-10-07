import 'package:flutter/material.dart';

import 'driver_earnings_page.dart';
import 'driver_home_page.dart';
import 'login_page.dart' as login;
import 'passenger_home_page.dart';
import 'payment_page.dart';
import 'profile_page.dart';
import 'register_page.dart' as register;
import 'role_select_page.dart';
import 'services/api_service.dart';
import 'session_manager.dart';
import 'trip_history_page.dart';
import 'vehicle_register_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = await SessionManager.loadSession();
  if (session != null) {
    ApiService.setToken(session.accessToken);
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
        '/register': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
          final role = args['role']?.toString() ?? 'passenger';
          return register.RegisterPage(role: role);
        },
        '/passenger': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final session = args?['session'] as UserSession? ?? initialSession;
          return PassengerHomePage(session: session);
        },
        '/driver': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final session = args?['session'] as UserSession? ?? initialSession;
          return DriverHomePage(session: session);
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
      },
    );
  }

  Widget _buildInitialHome() {
    if (initialSession == null) {
      return const RoleSelectPage();
    }

    if (initialSession!.role == 'driver') {
      return DriverHomePage(session: initialSession);
    }

    return PassengerHomePage(session: initialSession);
  }
}
