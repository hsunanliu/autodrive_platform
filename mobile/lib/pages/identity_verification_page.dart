/// Identity Verification Page
/// 身份驗證頁面
///
/// 提供 DID 註冊、年齡驗證、駕照驗證功能
library;

import 'package:flutter/material.dart';
import '../services/did_service.dart';
import '../services/api_service.dart';
import '../session_manager.dart';
import '../widgets/age_verification_dialog.dart';
import '../widgets/license_verification_dialog.dart';

class IdentityVerificationPage extends StatefulWidget {
  const IdentityVerificationPage({super.key});

  @override
  State<IdentityVerificationPage> createState() =>
      _IdentityVerificationPageState();
}

class _IdentityVerificationPageState extends State<IdentityVerificationPage> {
  DIDInfo? _didInfo;
  List<dynamic> _credentials = [];
  bool _isLoading = true;
  String? _errorMessage;

  // 驗證狀態
  bool _isRegisteringDID = false;
  bool _isVerifyingAge = false;
  bool _isVerifyingLicense = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 確保 Token 已設置
      final session = await SessionManager.loadSession();
      if (session == null || session.accessToken.isEmpty) {
        setState(() {
          _errorMessage = '請先登入';
          _isLoading = false;
        });
        return;
      }

      // 設置 Token（確保 API 請求帶上認證）
      ApiService.setToken(session.accessToken);
      print('身份驗證頁面：Token 已設置 ${session.accessToken.substring(0, 20)}...');

      // 並行載入 DID 信息和憑證列表
      final results = await Future.wait([
        DIDService.getDIDInfo(),
        DIDService.getCredentials(),
      ]);

      setState(() {
        _didInfo = results[0] as DIDInfo?;
        final credResult = results[1] as Map<String, dynamic>;
        _credentials = credResult['credentials'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '載入身份信息失敗: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDIDInfo() async {
    await _loadData();
  }

  Future<void> _registerDID() async {
    setState(() => _isRegisteringDID = true);

    try {
      // 從 SessionManager 獲取錢包地址並設置 Token
      final session = await SessionManager.loadSession();
      if (session == null || session.accessToken.isEmpty) {
        _showError('請先登入');
        setState(() => _isRegisteringDID = false);
        return;
      }

      ApiService.setToken(session.accessToken);

      final walletAddress = session.walletAddress;
      if (walletAddress == null || walletAddress.isEmpty) {
        _showError('請先連接錢包');
        setState(() => _isRegisteringDID = false);
        return;
      }

      final result = await DIDService.registerDID(
        walletAddress: walletAddress,
        publicKeyHex: walletAddress, // 暫時使用地址作為公鑰
      );

      if (result['success'] == true) {
        _showSuccess('身份標識已創建');
        await _loadDIDInfo();
      } else {
        _showError(result['error'] ?? '註冊失敗');
      }
    } catch (e) {
      _showError('註冊失敗: $e');
    } finally {
      setState(() => _isRegisteringDID = false);
    }
  }

  Future<void> _verifyAge() async {
    // 確保 Token 已設置
    final session = await SessionManager.loadSession();
    if (session == null || session.accessToken.isEmpty) {
      _showError('請先登入');
      return;
    }
    ApiService.setToken(session.accessToken);

    // 使用新的驗證對話框
    final result = await AgeVerificationDialog.show(context);

    if (result == true) {
      _showSuccess('年齡驗證成功');
      await _loadData();
    }
  }

  Future<void> _verifyLicense() async {
    // 確保 Token 已設置
    final session = await SessionManager.loadSession();
    if (session == null || session.accessToken.isEmpty) {
      _showError('請先登入');
      return;
    }
    ApiService.setToken(session.accessToken);

    // 使用新的駕照驗證對話框
    final result = await LicenseVerificationDialog.show(context);

    if (result == true) {
      _showSuccess('駕照驗證成功');
      await _loadData();
    }
  }

  Future<void> _revokeDID() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('撤銷身份標識'),
        content: const Text(
          '確定要撤銷您的身份標識嗎？\n\n'
          '這將清除所有驗證狀態，您需要重新驗證。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('撤銷'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // 確保 Token 已設置
      final session = await SessionManager.loadSession();
      if (session == null || session.accessToken.isEmpty) {
        _showError('請先登入');
        return;
      }
      ApiService.setToken(session.accessToken);

      final result = await DIDService.revokeDID();
      if (result['success'] == true) {
        _showSuccess('身份標識已撤銷');
        await _loadDIDInfo();
      } else {
        _showError(result['error'] ?? '撤銷失敗');
      }
    } catch (e) {
      _showError('撤銷失敗: $e');
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

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('身份驗證'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _buildContent(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red.shade300),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadDIDInfo,
            child: const Text('重試'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadDIDInfo,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // DID 狀態卡片
            _buildDIDStatusCard(),
            const SizedBox(height: 16),

            // 驗證項目
            if (_didInfo?.hasDID == true) ...[
              _buildVerificationCard(
                title: '年齡驗證',
                subtitle: '證明您已年滿 18 歲',
                icon: Icons.cake,
                isVerified: _didInfo?.ageVerified ?? false,
                isLoading: _isVerifyingAge,
                onVerify: _verifyAge,
              ),
              const SizedBox(height: 12),
              _buildVerificationCard(
                title: '駕照驗證',
                subtitle: '證明您持有有效駕照',
                icon: Icons.drive_eta,
                isVerified: _didInfo?.licenseVerified ?? false,
                isLoading: _isVerifyingLicense,
                onVerify: _verifyLicense,
              ),
            ],

            const SizedBox(height: 24),

            // 憑證列表
            if (_credentials.isNotEmpty) ...[
              _buildCredentialsSection(),
              const SizedBox(height: 24),
            ],

            // 說明文字
            _buildInfoSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.badge, color: Colors.blue.shade300),
            const SizedBox(width: 8),
            const Text(
              '我的憑證',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...(_credentials.map((cred) => _buildCredentialItem(cred)).toList()),
      ],
    );
  }

  Widget _buildCredentialItem(dynamic cred) {
    final type = cred['credential_type']?.toString() ?? '';
    final status = cred['status']?.toString() ?? '';
    final isValid = cred['is_valid'] == true;
    final isSimulated = cred['is_simulated'] == true;
    final verifiedAt = cred['verified_at']?.toString();

    IconData icon;
    String title;
    Color color;

    switch (type.toLowerCase()) {
      case 'age':
        icon = Icons.cake;
        title = '年齡驗證憑證';
        color = Colors.orange;
        break;
      case 'license':
        icon = Icons.drive_eta;
        title = '駕照驗證憑證';
        color = Colors.blue;
        break;
      default:
        icon = Icons.verified;
        title = type;
        color = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isValid
                              ? Colors.green.shade100
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isValid ? '有效' : status,
                          style: TextStyle(
                            fontSize: 11,
                            color: isValid
                                ? Colors.green.shade700
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                      if (isSimulated) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '模擬模式',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (verifiedAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '驗證時間: ${_formatDateTime(verifiedAt)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              isValid ? Icons.check_circle : Icons.pending,
              color: isValid ? Colors.green : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dt = DateTime.parse(dateTimeStr);
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }

  Widget _buildDIDStatusCard() {
    final hasDID = _didInfo?.hasDID == true;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: hasDID
                ? [Colors.blue.shade600, Colors.blue.shade800]
                : [Colors.grey.shade400, Colors.grey.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    hasDID ? Icons.verified_user : Icons.person_outline,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasDID ? '去中心化身份標識' : '尚未建立身份標識',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (hasDID) ...[
                        const SizedBox(height: 4),
                        Text(
                          _formatDID(_didInfo!.did!),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (hasDID)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _revokeDID,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('撤銷'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.5)),
                      ),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isRegisteringDID ? null : _registerDID,
                  icon: _isRegisteringDID
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.blue,
                          ),
                        )
                      : const Icon(Icons.add_circle_outline),
                  label: Text(_isRegisteringDID ? '建立中...' : '建立身份標識'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isVerified,
    required bool isLoading,
    required VoidCallback onVerify,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isVerified
                ? Colors.green.shade100
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isVerified ? Colors.green : Colors.grey.shade600,
          ),
        ),
        title: Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (isVerified) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '已驗證',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade400),
          ),
        ),
        trailing: isVerified
            ? null
            : isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : ElevatedButton(
                    onPressed: onVerify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('驗證'),
                  ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade900.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade700.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade300),
              const SizedBox(width: 8),
              Text(
                '關於身份驗證',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade300,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '我們使用去中心化身份（DID）和零知識證明（ZKP）技術，'
            '讓您可以驗證身份而不揭露個人敏感資料。\n\n'
            '您的出生日期、駕照號碼等資訊永遠不會上傳到服務器，'
            '只有驗證結果會被記錄。',
            style: TextStyle(
              color: Colors.blue.shade100,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDID(String did) {
    if (did.length <= 24) return did;
    return '${did.substring(0, 16)}...${did.substring(did.length - 8)}';
  }
}

/// 駕照輸入對話框
class _LicenseInputDialog extends StatefulWidget {
  @override
  State<_LicenseInputDialog> createState() => _LicenseInputDialogState();
}

class _LicenseInputDialogState extends State<_LicenseInputDialog> {
  final _licenseController = TextEditingController();
  DateTime? _expiryDate;

  @override
  void dispose() {
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      helpText: '選擇駕照到期日',
    );

    if (date != null) {
      setState(() => _expiryDate = date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('駕照驗證'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _licenseController,
            decoration: const InputDecoration(
              labelText: '駕照號碼',
              hintText: '請輸入駕照號碼',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _selectDate,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _expiryDate != null
                          ? '${_expiryDate!.year}/${_expiryDate!.month}/${_expiryDate!.day}'
                          : '選擇到期日',
                      style: TextStyle(
                        color: _expiryDate != null
                            ? Colors.white
                            : Colors.grey.shade400,
                      ),
                    ),
                  ),
                  Icon(Icons.calendar_today, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '您的駕照號碼不會上傳，僅用於本地生成驗證證明',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _licenseController.text.isNotEmpty && _expiryDate != null
              ? () => Navigator.pop(context, {
                    'licenseNumber': _licenseController.text,
                    'expiryDate': _expiryDate,
                  })
              : null,
          child: const Text('驗證'),
        ),
      ],
    );
  }
}
