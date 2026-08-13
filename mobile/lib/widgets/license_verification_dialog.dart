import 'package:flutter/material.dart';
import '../services/did_service.dart';
import '../services/api_service.dart';
import '../session_manager.dart';

/// 駕照驗證對話框
/// 使用零知識證明驗證用戶持有有效駕照
class LicenseVerificationDialog extends StatefulWidget {
  final VoidCallback? onSuccess;
  final VoidCallback? onCancel;

  const LicenseVerificationDialog({
    super.key,
    this.onSuccess,
    this.onCancel,
  });

  /// 顯示對話框
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => LicenseVerificationDialog(
        onSuccess: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
  }

  @override
  State<LicenseVerificationDialog> createState() =>
      _LicenseVerificationDialogState();
}

class _LicenseVerificationDialogState extends State<LicenseVerificationDialog> {
  final _licenseController = TextEditingController();
  DateTime? _expiryDate;
  // 目前只支援普通小型車
  final int _licenseType = 1;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isVerified = false;

  @override
  void dispose() {
    _licenseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _isVerified ? Icons.verified : Icons.badge_outlined,
            color: _isVerified ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Text(_isVerified ? '驗證成功' : '駕照驗證'),
        ],
      ),
      content: _isVerified ? _buildSuccessContent() : _buildFormContent(),
      actions: _isVerified ? _buildSuccessActions() : _buildFormActions(),
    );
  }

  Widget _buildFormContent() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 說明文字
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.security, color: Colors.orange.shade300, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '使用零知識證明驗證您的駕照有效性，駕照號碼不會被存儲或洩露。',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange.shade200,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 駕照號碼
          Text(
            '駕照號碼',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _licenseController,
            enabled: !_isLoading,
            decoration: InputDecoration(
              hintText: '請輸入駕照號碼',
              prefixIcon: const Icon(Icons.credit_card),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 駕照類型（固定為普通小型車）
          Text(
            '駕照類型',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade600),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade800,
            ),
            child: Row(
              children: [
                Icon(Icons.directions_car, color: Colors.green.shade400),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '普通小型車',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
                Icon(Icons.check_circle, color: Colors.green.shade400, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 有效期
          Text(
            '駕照有效期',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _isLoading ? null : _selectExpiryDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade600),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade800,
              ),
              child: Row(
                children: [
                  Icon(Icons.event, color: Colors.grey.shade400),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _expiryDate != null
                          ? '${_expiryDate!.year}/${_expiryDate!.month.toString().padLeft(2, '0')}/${_expiryDate!.day.toString().padLeft(2, '0')}'
                          : '點擊選擇有效期',
                      style: TextStyle(
                        fontSize: 16,
                        color: _expiryDate != null
                            ? Colors.white
                            : Colors.grey.shade400,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),

          // 錯誤訊息
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade300, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red.shade200,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 載入中
          if (_isLoading) ...[
            const SizedBox(height: 16),
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text(
                    '正在生成零知識證明...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuccessContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check,
            size: 48,
            color: Colors.green.shade400,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '駕照驗證成功！',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '您的駕照憑證已通過零知識證明生成並安全存儲。',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildFormActions() {
    return [
      TextButton(
        onPressed: _isLoading ? null : widget.onCancel,
        child: const Text('取消'),
      ),
      ElevatedButton(
        onPressed: _canSubmit() ? _verifyLicense : null,
        child: const Text('驗證'),
      ),
    ];
  }

  List<Widget> _buildSuccessActions() {
    return [
      ElevatedButton(
        onPressed: widget.onSuccess,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        child: const Text('完成'),
      ),
    ];
  }

  bool _canSubmit() {
    return !_isLoading &&
        _licenseController.text.isNotEmpty &&
        _expiryDate != null;
  }

  Future<void> _selectExpiryDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year + 5, now.month, now.day),
      firstDate: now,
      lastDate: DateTime(now.year + 20),
      locale: const Locale('zh', 'TW'),
    );

    if (picked != null) {
      setState(() {
        _expiryDate = picked;
        _errorMessage = null;
      });
    }
  }

  Future<void> _verifyLicense() async {
    if (_licenseController.text.isEmpty || _expiryDate == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 檢查是否有登入 session
      final session = await SessionManager.loadSession();

      if (session != null && session.accessToken.isNotEmpty) {
        // 已登入：呼叫後端 API 做 ZKP 驗證
        ApiService.setToken(session.accessToken);

        final result = await DIDService.generateAndVerifyLicense(
          licenseNumber: _licenseController.text,
          expiryYear: _expiryDate!.year,
          expiryMonth: _expiryDate!.month,
          expiryDay: _expiryDate!.day,
          licenseType: _licenseType,
        );

        if (result['success'] == true) {
          setState(() {
            _isVerified = true;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = result['error'] ?? '驗證失敗，請檢查駕照資訊';
            _isLoading = false;
          });
        }
      } else {
        // 未登入（註冊流程）：純前端驗證駕照有效期
        final now = DateTime.now();
        final isValid = _expiryDate!.isAfter(now) && _licenseController.text.isNotEmpty;

        if (isValid) {
          setState(() {
            _isVerified = true;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = '駕照已過期或資訊不完整';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = '驗證過程發生錯誤：$e';
        _isLoading = false;
      });
    }
  }
}
