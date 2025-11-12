import 'package:flutter/material.dart';

class RoleSelectPage extends StatefulWidget {
  const RoleSelectPage({super.key});

  @override
  State<RoleSelectPage> createState() => _RoleSelectPageState();
}

class _RoleSelectPageState extends State<RoleSelectPage> {
  String? selectedRole; // 用來記錄選擇的角色（passenger or driver）

  // 登入按鈕動作
  void navigateToLogin() {
    if (selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先選擇角色')),
      );
      return;
    }

    // ✅ 使用 pushNamed 而非 pushReplacementNamed，允許用戶返回
    Navigator.pushNamed(
      context,
      '/login',
      arguments: {'role': selectedRole},
    );
  }

  // 註冊按鈕動作
  void navigateToRegister() {
    // 使用新的錢包整合註冊頁面（支援 Slush Wallet + 手動輸入）
    Navigator.pushNamed(
      context,
      '/register_with_wallet_connect',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '選擇您的身分',
              style: TextStyle(fontSize: 24, color: Colors.white),
            ),
            const SizedBox(height: 40),

            // 選擇角色按鈕
            ToggleButtons(
              isSelected: [
                selectedRole == 'passenger',
                selectedRole == 'driver',
              ],
              onPressed: (index) {
                setState(() {
                  selectedRole = index == 0 ? 'passenger' : 'driver';
                });
              },
              borderRadius: BorderRadius.circular(10),
              selectedColor: Colors.black,
              fillColor: Colors.greenAccent,
              color: Colors.white,
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('乘客'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('車主'),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // 登入按鈕
            ElevatedButton(
              onPressed: navigateToLogin,
              child: const Text('登入'),
            ),

            const SizedBox(height: 20),

            // 註冊按鈕（不需要選擇角色，新註冊頁面內建角色選擇）
            OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, '/register_with_wallet_connect'),
              child: const Text('註冊'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.greenAccent,
                side: const BorderSide(color: Colors.greenAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
