import 'package:flutter/material.dart';

import 'services/api_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.role});

  final String role;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final walletController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final displayNameController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  String message = '';

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    walletController.dispose();
    emailController.dispose();
    phoneController.dispose();
    displayNameController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();
    final wallet = walletController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final displayName = displayNameController.text.trim();

    if (username.isEmpty || password.isEmpty || wallet.isEmpty) {
      setState(() => message = '請填寫必填欄位');
      return;
    }

    if (password.length < 8) {
      setState(() => message = '密碼至少需要 8 個字元');
      return;
    }

    if (password != confirmPassword) {
      setState(() => message = '兩次輸入的密碼不一致');
      return;
    }

    setState(() {
      isLoading = true;
      message = '';
    });

    final result = await ApiService.registerUser(
      username: username,
      password: password,
      walletAddress: wallet,
      email: email,
      userType: widget.role,
      phoneNumber: phone.isEmpty ? null : phone,
      displayName: displayName.isEmpty ? null : displayName,
    );

    setState(() => isLoading = false);

    if (result['success'] == true) {
      setState(() => message = '註冊成功，請登入');
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/login',
        arguments: {'role': widget.role},
      );
    } else {
      final error = result['data']?['detail'] ?? result['error'] ?? '註冊失敗';
      setState(() => message = error.toString());
    }
  }

  void _backToLogin() {
    Navigator.pushReplacementNamed(
      context,
      '/login',
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
              const SizedBox(height: 40),
              Text(
                '建立帳號',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF1DB954),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '註冊為 ${widget.role == 'driver' ? '🚗 車主' : '🧍 乘客'}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 30),
              _buildTextField(
                controller: usernameController,
                label: '使用者名稱 *',
                icon: Icons.person,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: displayNameController,
                label: '顯示名稱 (可選)',
                icon: Icons.badge,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: phoneController,
                label: '手機號碼 (可選)',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: emailController,
                label: '電子郵件 (可選)',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: walletController,
                label: '錢包地址 (0x...)*',
                icon: Icons.account_balance_wallet,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: passwordController,
                label: '密碼 (至少 8 碼)*',
                icon: Icons.lock,
                obscureText: obscurePassword,
                toggleObscure: () {
                  setState(() => obscurePassword = !obscurePassword);
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: confirmPasswordController,
                label: '再次輸入密碼*',
                icon: Icons.lock_outline,
                obscureText: obscureConfirmPassword,
                toggleObscure: () {
                  setState(() => obscureConfirmPassword = !obscureConfirmPassword);
                },
              ),
              const SizedBox(height: 24),
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
                  onPressed: isLoading ? null : _register,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          '註冊',
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
              const SizedBox(height: 20),
              TextButton(
                onPressed: _backToLogin,
                child: const Text(
                  '已有帳號？前往登入',
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
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? toggleObscure,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
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
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
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
