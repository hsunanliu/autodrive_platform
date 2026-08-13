import 'package:flutter/material.dart';
import '../services/did_service.dart';
import '../services/api_service.dart';
import '../session_manager.dart';

/// 年齡驗證對話框
/// 使用零知識證明驗證用戶年齡 >= 18 歲
class AgeVerificationDialog extends StatefulWidget {
  final VoidCallback? onSuccess;
  final VoidCallback? onCancel;

  const AgeVerificationDialog({
    super.key,
    this.onSuccess,
    this.onCancel,
  });

  /// 顯示對話框
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AgeVerificationDialog(
        onSuccess: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
  }

  @override
  State<AgeVerificationDialog> createState() => _AgeVerificationDialogState();
}

class _AgeVerificationDialogState extends State<AgeVerificationDialog> {
  DateTime? _selectedDate;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isVerified = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _isVerified ? Icons.verified : Icons.person_outline,
            color: _isVerified ? Colors.green : Colors.blue,
          ),
          const SizedBox(width: 8),
          Text(_isVerified ? '驗證成功' : '年齡驗證'),
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
              color: Colors.blue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade300, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '使用零知識證明驗證您已年滿 18 歲，您的出生日期不會被存儲或洩露。',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade200,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 日期選擇
          Text(
            '請選擇您的出生日期',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _isLoading ? null : _selectDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade600),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade800,
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.grey.shade400),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedDate != null
                          ? '${_selectedDate!.year}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.day.toString().padLeft(2, '0')}'
                          : '點擊選擇日期',
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedDate != null
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
          '年齡驗證成功！',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '您的年齡憑證已通過零知識證明生成並安全存儲。',
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
        onPressed: _isLoading || _selectedDate == null ? null : _verifyAge,
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

  Future<void> _selectDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      locale: const Locale('zh', 'TW'),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _errorMessage = null;
      });
    }
  }

  Future<void> _verifyAge() async {
    if (_selectedDate == null) return;

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

        final result = await DIDService.generateAndVerifyAge(
          birthYear: _selectedDate!.year,
          birthMonth: _selectedDate!.month,
          birthDay: _selectedDate!.day,
          minAge: 18,
        );

        if (result['success'] == true) {
          setState(() {
            _isVerified = true;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = result['error'] ?? '驗證失敗，請確認您已年滿 18 歲';
            _isLoading = false;
          });
        }
      } else {
        // 未登入（註冊流程）：純前端驗證年齡
        final now = DateTime.now();
        int age = now.year - _selectedDate!.year;
        if (now.month < _selectedDate!.month ||
            (now.month == _selectedDate!.month && now.day < _selectedDate!.day)) {
          age--;
        }

        if (age >= 18) {
          setState(() {
            _isVerified = true;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = '您尚未年滿 18 歲，無法註冊';
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
