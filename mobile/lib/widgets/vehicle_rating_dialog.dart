import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// 車輛評價對話框
/// 在行程完成後顯示，讓乘客對車輛進行評價
class VehicleRatingDialog extends StatefulWidget {
  final int tripId;
  final String vehicleId;
  final String? vehicleModel;
  final VoidCallback? onSuccess;
  final VoidCallback? onCancel;

  const VehicleRatingDialog({
    super.key,
    required this.tripId,
    required this.vehicleId,
    this.vehicleModel,
    this.onSuccess,
    this.onCancel,
  });

  /// 顯示對話框
  static Future<bool?> show(
    BuildContext context, {
    required int tripId,
    required String vehicleId,
    String? vehicleModel,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => VehicleRatingDialog(
        tripId: tripId,
        vehicleId: vehicleId,
        vehicleModel: vehicleModel,
        onSuccess: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
  }

  @override
  State<VehicleRatingDialog> createState() => _VehicleRatingDialogState();
}

class _VehicleRatingDialogState extends State<VehicleRatingDialog> {
  int _rating = 0;
  final _commentController = TextEditingController();
  final Set<String> _selectedTags = {};
  bool _isLoading = false;
  bool _isSubmitted = false;
  String? _errorMessage;

  // 正面標籤
  final List<Map<String, dynamic>> _positiveTags = [
    {'key': 'clean', 'label': '車內整潔', 'icon': Icons.cleaning_services},
    {'key': 'smooth', 'label': '行駛平穩', 'icon': Icons.airline_seat_recline_normal},
    {'key': 'on_time', 'label': '準時到達', 'icon': Icons.schedule},
    {'key': 'comfortable', 'label': '空調舒適', 'icon': Icons.ac_unit},
    {'key': 'safe', 'label': '安全可靠', 'icon': Icons.verified_user},
  ];

  // 負面標籤
  final List<Map<String, dynamic>> _negativeTags = [
    {'key': 'dirty', 'label': '車內髒亂', 'icon': Icons.warning},
    {'key': 'bumpy', 'label': '行駛顛簸', 'icon': Icons.report_problem},
    {'key': 'detour', 'label': '路線繞遠', 'icon': Icons.wrong_location},
    {'key': 'ac_issue', 'label': '空調問題', 'icon': Icons.thermostat},
    {'key': 'unsafe', 'label': '感覺不安全', 'icon': Icons.dangerous},
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: _isSubmitted ? _buildSuccessContent() : _buildFormContent(),
      ),
    );
  }

  Widget _buildFormContent() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 標題
            Row(
              children: [
                Icon(Icons.star_rate, color: Colors.amber.shade600, size: 28),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '為這趟行程評分',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.vehicleModel ?? '車輛 ${widget.vehicleId}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),

            // 星級評分
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  return GestureDetector(
                    onTap: () => setState(() => _rating = starIndex),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        starIndex <= _rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 40,
                      ),
                    ),
                  );
                }),
              ),
            ),
            if (_rating > 0) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _getRatingText(_rating),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: _getRatingColor(_rating),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // 標籤選擇
            if (_rating > 0) ...[
              Text(
                _rating >= 4 ? '您喜歡什麼？' : (_rating <= 2 ? '哪裡需要改進？' : '選擇標籤（可選）'),
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (_rating >= 4 ? _positiveTags : (_rating <= 2 ? _negativeTags : [..._positiveTags, ..._negativeTags]))
                    .map((tag) => _buildTagChip(tag))
                    .toList(),
              ),
              const SizedBox(height: 20),
            ],

            // 評論輸入
            if (_rating > 0) ...[
              Text(
                '補充說明（可選）',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _commentController,
                maxLines: 3,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: '分享您的乘車體驗...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],

            // 錯誤訊息
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade400, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade400),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // 按鈕
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isLoading ? null : widget.onCancel,
                    child: const Text('稍後再說'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _rating > 0 && !_isLoading ? _submitRating : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('提交評價'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessContent() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              size: 56,
              color: Colors.green.shade400,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '感謝您的評價！',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '您的評價將幫助我們提升服務品質',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, size: 16, color: Colors.blue.shade400),
                const SizedBox(width: 4),
                Text(
                  '評價已上鏈存證',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onSuccess,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('完成'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(Map<String, dynamic> tag) {
    final isSelected = _selectedTags.contains(tag['key']);
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            tag['icon'] as IconData,
            size: 16,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
          const SizedBox(width: 4),
          Text(tag['label'] as String),
        ],
      ),
      selectedColor: _rating >= 4 ? Colors.green : Colors.orange,
      checkmarkColor: Colors.white,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedTags.add(tag['key'] as String);
          } else {
            _selectedTags.remove(tag['key']);
          }
        });
      },
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 5:
        return '非常滿意';
      case 4:
        return '滿意';
      case 3:
        return '一般';
      case 2:
        return '不滿意';
      case 1:
        return '非常不滿意';
      default:
        return '';
    }
  }

  Color _getRatingColor(int rating) {
    switch (rating) {
      case 5:
        return Colors.green;
      case 4:
        return Colors.lightGreen;
      case 3:
        return Colors.amber;
      case 2:
        return Colors.orange;
      case 1:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _submitRating() async {
    if (_rating == 0) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.post('/ratings/vehicle', {
        'trip_id': widget.tripId,
        'vehicle_id': widget.vehicleId,
        'rating': _rating,
        'comment': _commentController.text.isEmpty ? null : _commentController.text,
        'tags': _selectedTags.toList(),
      });

      if (response['id'] != null) {
        setState(() {
          _isSubmitted = true;
          _isLoading = false;
        });
      } else {
        throw Exception(response['detail'] ?? '提交評價失敗');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }
}
