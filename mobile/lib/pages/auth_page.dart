// mobile/lib/pages/auth_page.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _walletController = TextEditingController();
  
  bool _isLogin = true;
  bool _isLoading = false;
  String _userType = 'passenger';

  Future<void> _handleAuth() async {
    if (_usernameController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _showSnackBar('請填寫所有必填欄位');
      return;
    }

    setState(() => _isLoading = true);

    try {
      Map<String, dynamic> result;

      if (_isLogin) {
        // 登入
        result = await ApiService.loginUser(
          identifier: _usernameController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        // 註冊
        if (_emailController.text.trim().isEmpty ||
            _walletController.text.trim().isEmpty) {
          _showSnackBar('註冊需要填寫所有欄位');
          setState(() => _isLoading = false);
          return;
        }

        result = await ApiService.registerUser(
          username: _usernameController.text.trim(),
          password: _passwordController.text.trim(),
          walletAddress: _walletController.text.trim(),
          email: _emailController.text.trim(),
          userType: _userType,
        );
      }

      if (result['success']) {
        if (_isLogin) {
          // 登入成功，跳轉到主頁
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          // 註冊成功，切換到登入模式
          _showSnackBar('註冊成功！請登入');
          setState(() => _isLogin = true);
        }
      } else {
        // 處理錯誤
        String errorMessage = '操作失敗';
        if (result['data'] != null && result['data']['detail'] != null) {
          errorMessage = result['data']['detail'].toString();
        } else if (result['error'] != null) {
          errorMessage = result['error'].toString();
        }
        _showSnackBar(errorMessage);
      }
    } catch (e) {
      _showSnackBar('網絡錯誤：$e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 350,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                Text(
                  _isLogin ? "登入" : "註冊",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                
                // 用戶名
                _buildTextField(
                  controller: _usernameController,
                  hintText: "用戶名",
                  icon: Icons.person,
                ),
                const SizedBox(height: 16),
                
                // 密碼
                _buildTextField(
                  controller: _passwordController,
                  hintText: "密碼",
                  icon: Icons.lock,
                  obscureText: true,
                ),
                
                // 註冊額外欄位
                if (!_isLogin) ...[
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _emailController,
                    hintText: "電子郵件",
                    icon: Icons.email,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _walletController,
                    hintText: "錢包地址 (0x...)",
                    icon: Icons.account_balance_wallet,
                  ),
                  const SizedBox(height: 16),
                  
                  // 用戶類型選擇
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<String>(
                      value: _userType,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1E1E1E),
                      style: const TextStyle(color: Colors.white),
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(
                          value: 'passenger',
                          child: Text('乘客'),
                        ),
                        DropdownMenuItem(
                          value: 'driver',
                          child: Text('司機'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _userType = value);
                        }
                      },
                    ),
                  ),
                ],
                
                const SizedBox(height: 20),
                
                // 主按鈕
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleAuth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _isLogin ? "登入" : "註冊",
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 切換按鈕
                TextButton(
                  onPressed: () {
                    setState(() => _isLogin = !_isLogin);
                  },
                  child: Text(
                    _isLogin ? "沒有帳號？註冊" : "已有帳號？登入",
                    style: const TextStyle(
                      color: Color(0xFF1DB954),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}