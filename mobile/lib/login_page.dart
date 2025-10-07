import 'package:flutter/material.dart';

import 'services/api_service.dart';
import 'session_manager.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.role});

  final String role;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController identifierController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;
  String message = '';

  @override
  void dispose() {
    identifierController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final identifier = identifierController.text.trim();
    final password = passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      setState(() => message = '請輸入帳號與密碼');
      return;
    }

    setState(() {
      isLoading = true;
      message = '';
    });

    final result = await ApiService.loginUser(
      identifier: identifier,
      password: password,
    );

    setState(() => isLoading = false);

    if (result['success'] != true) {
      final error = result['data']?['detail'] ?? result['error'] ?? '登入失敗';
      setState(() => message = error.toString());
      return;
    }

    final data = result['data'];
    if (data is! Map || data['user'] is! Map) {
      setState(() => message = '登入回應格式不正確');
      return;
    }

    final user = data['user'] as Map;
    final accessToken = data['access_token']?.toString();
    if (accessToken == null) {
      setState(() => message = '登入回應缺少 token');
      return;
    }

    final session = UserSession(
      userId: (user['id'] as num).toInt(),
      username: user['username']?.toString() ?? identifier,
      role: user['user_type']?.toString() ?? widget.role,
      accessToken: accessToken,
      walletAddress: user['wallet_address']?.toString(),
      phoneNumber: user['phone_number']?.toString(),
      email: user['email']?.toString(),
    );

    await SessionManager.saveSession(session);
    ApiService.setToken(session.accessToken);

    if (!mounted) return;

    setState(() => message = '登入成功');

    final role = session.role;
    if (role == 'driver') {
      Navigator.pushReplacementNamed(
        context,
        '/driver',
        arguments: {'session': session},
      );
    } else {
      Navigator.pushReplacementNamed(
        context,
        '/passenger',
        arguments: {'session': session},
      );
    }
  }

  void _goToRegisterPage() {
    Navigator.pushNamed(
      context,
      '/register',
      arguments: {'role': widget.role},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: ListView(
            children: [
              const SizedBox(height: 60),
              Text(
                '登入',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF1DB954),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '以 ${widget.role == 'driver' ? '🚗 車主' : '🧍 乘客'} 身份登入',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 40),
              _buildTextField(
                controller: identifierController,
                hint: '帳號 / 電子郵件 / 手機 / 錢包地址',
                icon: Icons.person,
              ),
              const SizedBox(height: 18),
              _buildTextField(
                controller: passwordController,
                hint: '密碼',
                icon: Icons.lock,
                obscureText: obscurePassword,
                toggleObscure: () {
                  setState(() => obscurePassword = !obscurePassword);
                },
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DB954),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: isLoading ? null : _handleLogin,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          '登入',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              if (message.isNotEmpty)
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: message.contains('成功') ? Colors.green : Colors.red,
                    fontSize: 16,
                  ),
                ),
              const SizedBox(height: 30),
              TextButton(
                onPressed: _goToRegisterPage,
                child: const Text(
                  '尚未註冊？點我註冊',
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    VoidCallback? toggleObscure,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      obscureText: obscureText,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white60),
        suffixIcon: toggleObscure == null
            ? null
            : IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white60,
                ),
                onPressed: toggleObscure,
              ),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
