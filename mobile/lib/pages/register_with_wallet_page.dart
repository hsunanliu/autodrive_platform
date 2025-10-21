// mobile/lib/pages/register_with_wallet_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../session_manager.dart';

class RegisterWithWalletPage extends StatefulWidget {
  const RegisterWithWalletPage({super.key});

  @override
  State<RegisterWithWalletPage> createState() => _RegisterWithWalletPageState();
}

class _RegisterWithWalletPageState extends State<RegisterWithWalletPage> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _showPassword = false;
  String _userType = 'passenger';
  String? _generatedMnemonic;
  String? _walletAddress;
  int _currentStep = 0;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('註冊帳號'),
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _onStepContinue,
        onStepCancel: _onStepCancel,
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                if (_currentStep > 0)
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('上一步'),
                  ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : details.onStepContinue,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_currentStep == 2 ? '完成' : '下一步'),
                ),
              ],
            ),
          );
        },
        steps: [
          // 步驟 1: 基本信息
          Step(
            title: const Text('基本信息'),
            content: Column(
              children: [
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: '用戶名',
                    hintText: '3-50 個字符',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: '郵箱',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _userType,
                  decoration: const InputDecoration(
                    labelText: '用戶類型',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'passenger', child: Text('乘客')),
                    DropdownMenuItem(value: 'driver', child: Text('司機')),
                    DropdownMenuItem(value: 'both', child: Text('乘客和司機')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _userType = value);
                    }
                  },
                ),
              ],
            ),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          
          // 步驟 2: 設置密碼
          Step(
            title: const Text('設置密碼'),
            content: Column(
              children: [
                TextField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: '密碼',
                    hintText: '至少 8 個字符',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _showPassword = !_showPassword);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: !_showPassword,
                  decoration: const InputDecoration(
                    labelText: '確認密碼',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '此密碼用於加密您的錢包私鑰，請妥善保管',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
          ),
          
          // 步驟 3: 備份助記詞
          Step(
            title: const Text('備份助記詞'),
            content: _generatedMnemonic != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning_amber, color: Colors.orange.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  '請備份您的助記詞',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SelectableText(
                              _generatedMnemonic!,
                              style: const TextStyle(
                                fontSize: 14,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '這是恢復錢包的唯一方式，請抄寫並妥善保管！',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: _generatedMnemonic!),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('已複製到剪貼板')),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_walletAddress != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '錢包地址',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              SelectableText(
                                _walletAddress!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  )
                : const Center(child: CircularProgressIndicator()),
            isActive: _currentStep >= 2,
            state: StepState.indexed,
          ),
        ],
      ),
    );
  }

  Future<void> _onStepContinue() async {
    if (_currentStep == 0) {
      // 驗證基本信息
      if (_usernameController.text.trim().isEmpty ||
          _emailController.text.trim().isEmpty) {
        _showError('請填寫所有欄位');
        return;
      }
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      // 驗證密碼並創建帳號
      if (_passwordController.text.length < 8) {
        _showError('密碼至少需要 8 個字符');
        return;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        _showError('兩次輸入的密碼不一致');
        return;
      }
      
      await _registerAndCreateWallet();
    } else if (_currentStep == 2) {
      // 完成註冊，根據用戶類型跳轉
      if (mounted) {
        final session = await SessionManager.loadSession();
        if (_userType == 'driver') {
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
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    }
  }

  Future<void> _registerAndCreateWallet() async {
    setState(() => _isLoading = true);

    try {
      // 1. 先檢查用戶名是否可用
      print('檢查用戶名是否可用...');
      final checkResult = await ApiService.checkUsername(
        _usernameController.text.trim(),
      );
      
      if (checkResult['success'] == true) {
        final data = checkResult['data'];
        if (data['available'] != true) {
          throw Exception('用戶名已被使用，請換一個');
        }
      }
      
      // 2. 創建錢包
      print('開始創建錢包...');
      final walletResult = await ApiService.createWallet(
        password: _passwordController.text,
      );
      print('錢包創建結果: $walletResult');

      if (walletResult['success'] != true) {
        throw Exception(walletResult['error'] ?? '創建錢包失敗');
      }

      final walletData = walletResult['data'];
      if (walletData == null) {
        throw Exception('錢包數據為空');
      }
      
      final walletAddress = walletData['address'];
      final mnemonic = walletData['mnemonic'];
      
      if (walletAddress == null || mnemonic == null) {
        throw Exception('錢包地址或助記詞為空');
      }
      
      print('錢包創建成功: $walletAddress');

      // 2. 使用錢包地址註冊用戶
      print('開始註冊用戶...');
      final registerResult = await ApiService.registerUser(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        walletAddress: walletAddress,
        email: _emailController.text.trim(),
        userType: _userType,
      );
      print('註冊結果: $registerResult');

      if (registerResult['success'] != true) {
        final errorMsg = registerResult['data']?['detail'] ?? registerResult['error'] ?? '註冊失敗';
        throw Exception(errorMsg);
      }

      // 3. 自動登入
      print('開始登入...');
      final loginResult = await ApiService.loginUser(
        identifier: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      print('登入結果: ${loginResult['success']}');

      if (loginResult['success'] != true) {
        final errorMsg = loginResult['data']?['detail'] ?? loginResult['error'] ?? '登入失敗';
        throw Exception(errorMsg);
      }

      // 4. 保存 session
      final userData = loginResult['data']['user'];
      final session = UserSession(
        userId: userData['id'],
        username: userData['username'],
        role: _userType,
        accessToken: loginResult['data']['access_token'],
        walletAddress: walletAddress,
        phoneNumber: userData['phone_number'],
        email: _emailController.text.trim(),
      );
      
      await SessionManager.saveSession(session);

      // 5. 顯示助記詞
      setState(() {
        _generatedMnemonic = mnemonic;
        _walletAddress = walletAddress;
        _currentStep = 2;
        _isLoading = false;
      });

    } catch (e) {
      print('註冊流程錯誤: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        _showError('註冊失敗: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
