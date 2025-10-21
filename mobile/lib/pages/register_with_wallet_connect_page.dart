// mobile/lib/pages/register_with_wallet_connect_page.dart

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/sui_wallet_connector.dart';
import '../session_manager.dart';

class RegisterWithWalletConnectPage extends StatefulWidget {
  const RegisterWithWalletConnectPage({super.key});

  @override
  State<RegisterWithWalletConnectPage> createState() =>
      _RegisterWithWalletConnectPageState();
}

class _RegisterWithWalletConnectPageState
    extends State<RegisterWithWalletConnectPage> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _walletAddressController = TextEditingController();

  bool _isLoading = false;
  bool _showPassword = false;
  String _userType = 'passenger';
  String? _connectedWalletAddress;
  int _currentStep = 0;

  // 開發模式：自動生成測試錢包地址
  static const bool _devMode = true;

  final _walletConnector = SuiWalletConnector();

  @override
  void initState() {
    super.initState();
    _walletConnector.initialize();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _walletAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('註冊帳號')),
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
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Text(_currentStep == 2 ? '完成註冊' : '下一步'),
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

          // 步驟 2: 連接錢包
          Step(
            title: const Text('連接錢包'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_connectedWalletAddress == null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '連接您的 Sui 錢包',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '您需要一個 Sui 錢包來使用本平台。\n'
                          '如果您還沒有錢包，請先從 App Store 安裝 Suiet 應用。',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 連接錢包按鈕
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _connectWallet,
                      icon: const Icon(Icons.account_balance_wallet),
                      label: const Text('連接 Suiet Wallet'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    '或者手動輸入錢包地址：',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _walletAddressController,
                    decoration: const InputDecoration(
                      labelText: '錢包地址',
                      hintText: '0x...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      if (value.startsWith('0x') && value.length == 66) {
                        setState(() => _connectedWalletAddress = value);
                      }
                    },
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '錢包已連接',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '錢包地址：',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          _connectedWalletAddress!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () {
                            setState(() => _connectedWalletAddress = null);
                            _walletAddressController.clear();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('重新連接'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
          ),

          // 步驟 3: 設置密碼
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
                          '此密碼用於登入平台，與您的錢包密碼無關',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

      // 檢查用戶名是否可用
      setState(() => _isLoading = true);
      try {
        final checkResult = await ApiService.checkUsername(
          _usernameController.text.trim(),
        );

        if (checkResult['success'] == true) {
          final data = checkResult['data'];
          if (data['available'] != true) {
            _showError('用戶名已被使用，請換一個');
            setState(() => _isLoading = false);
            return;
          }
        }
      } catch (e) {
        _showError('檢查用戶名失敗: $e');
        setState(() => _isLoading = false);
        return;
      }
      setState(() => _isLoading = false);

      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      // 驗證錢包連接
      if (_connectedWalletAddress == null) {
        _showError('請連接錢包或輸入錢包地址');
        return;
      }
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      // 驗證密碼並註冊
      if (_passwordController.text.length < 8) {
        _showError('密碼至少需要 8 個字符');
        return;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        _showError('兩次輸入的密碼不一致');
        return;
      }

      await _registerUser();
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    }
  }

  Future<void> _connectWallet() async {
    setState(() => _isLoading = true);

    try {
      final result = await _walletConnector.connectWallet();

      if (result['success'] == true) {
        if (result['pending'] == true) {
          _showInfo('請在 Suiet Wallet 中授權連接');
          // 等待用戶在錢包中授權
          // 實際應用中需要監聽 Deep Link 回調
        } else if (_walletConnector.walletAddress != null) {
          setState(() {
            _connectedWalletAddress = _walletConnector.walletAddress;
            _walletAddressController.text = _connectedWalletAddress!;
          });
          _showSuccess('錢包連接成功');
        }
      } else {
        _showError(result['error'] ?? '連接錢包失敗');
      }
    } catch (e) {
      _showError('連接錢包失敗: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _registerUser() async {
    setState(() => _isLoading = true);

    try {
      print('開始註冊用戶...');
      final registerResult = await ApiService.registerUser(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        walletAddress: _connectedWalletAddress!,
        email: _emailController.text.trim(),
        userType: _userType,
      );
      print('註冊結果: $registerResult');

      if (registerResult['success'] != true) {
        final errorMsg =
            registerResult['data']?['detail'] ??
            registerResult['error'] ??
            '註冊失敗';
        throw Exception(errorMsg);
      }

      // 自動登入
      print('開始登入...');
      final loginResult = await ApiService.loginUser(
        identifier: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      if (loginResult['success'] != true) {
        final errorMsg =
            loginResult['data']?['detail'] ?? loginResult['error'] ?? '登入失敗';
        throw Exception(errorMsg);
      }

      // 保存 session
      final userData = loginResult['data']['user'];
      final session = UserSession(
        userId: userData['id'],
        username: userData['username'],
        role: _userType,
        accessToken: loginResult['data']['access_token'],
        walletAddress: _connectedWalletAddress,
        phoneNumber: userData['phone_number'],
        email: _emailController.text.trim(),
      );

      await SessionManager.saveSession(session);

      // 跳轉到主頁
      if (mounted) {
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
    } catch (e) {
      print('註冊流程錯誤: $e');
      if (mounted) {
        _showError('註冊失敗: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.blue),
    );
  }
}
