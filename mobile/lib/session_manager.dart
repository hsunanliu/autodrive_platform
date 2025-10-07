import 'package:shared_preferences/shared_preferences.dart';

const _tokenKey = 'access_token';
const _userIdKey = 'user_id';
const _usernameKey = 'username';
const _roleKey = 'user_role';
const _walletKey = 'wallet_address';
const _phoneKey = 'phone_number';
const _emailKey = 'email';

class UserSession {
  const UserSession({
    required this.userId,
    required this.username,
    required this.role,
    required this.accessToken,
    this.walletAddress,
    this.phoneNumber,
    this.email,
  });

  final int userId;
  final String username;
  final String role;
  final String accessToken;
  final String? walletAddress;
  final String? phoneNumber;
  final String? email;

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'role': role,
      'accessToken': accessToken,
      'walletAddress': walletAddress,
      'phoneNumber': phoneNumber,
      'email': email,
    };
  }

  factory UserSession.fromPrefs(SharedPreferences prefs) {
    final userId = prefs.getInt(_userIdKey);
    final username = prefs.getString(_usernameKey);
    final role = prefs.getString(_roleKey);
    final token = prefs.getString(_tokenKey);

    if (userId == null || username == null || role == null || token == null) {
      throw StateError('missing session data');
    }

    return UserSession(
      userId: userId,
      username: username,
      role: role,
      accessToken: token,
      walletAddress: prefs.getString(_walletKey),
      phoneNumber: prefs.getString(_phoneKey),
      email: prefs.getString(_emailKey),
    );
  }
}

class SessionManager {
  static Future<void> saveSession(UserSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, session.accessToken);
    await prefs.setInt(_userIdKey, session.userId);
    await prefs.setString(_usernameKey, session.username);
    await prefs.setString(_roleKey, session.role);

    if (session.walletAddress != null) {
      await prefs.setString(_walletKey, session.walletAddress!);
    } else {
      await prefs.remove(_walletKey);
    }

    if (session.phoneNumber != null) {
      await prefs.setString(_phoneKey, session.phoneNumber!);
    } else {
      await prefs.remove(_phoneKey);
    }

    if (session.email != null) {
      await prefs.setString(_emailKey, session.email!);
    } else {
      await prefs.remove(_emailKey);
    }
  }

  static Future<UserSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_tokenKey)) {
      return null;
    }

    try {
      return UserSession.fromPrefs(prefs);
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_walletKey);
    await prefs.remove(_phoneKey);
    await prefs.remove(_emailKey);
  }
}
