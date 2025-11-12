// mobile/lib/pages/trip_history_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/price_service.dart';
import '../services/refund_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TripHistoryPage extends StatefulWidget {
  const TripHistoryPage({super.key});

  @override
  State<TripHistoryPage> createState() => _TripHistoryPageState();
}

class _TripHistoryPageState extends State<TripHistoryPage> {
  List<dynamic> _trips = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await ApiService.getUserTrips(limit: 50);

    if (result['success']) {
      setState(() {
        _trips = result['data'];
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result['error'] ?? '載入失敗';
        _isLoading = false;
      });
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'requested':
        return '已請求';
      case 'matched':
        return '已配對';
      case 'accepted':
        return '已接受';
      case 'picked_up':
        return '已上車';
      case 'completed':
        return '已完成';
      case 'cancelled':
        return '已取消';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'picked_up':
        return Colors.blue;
      case 'accepted':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return '未知時間';

    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.year}/${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '時間格式錯誤';
    }
  }

  // 顯示退款請求對話框
  void _showRefundDialog(Map<String, dynamic> trip) {
    final reasonController = TextEditingController();
    final amountController = TextEditingController(
      text: trip['total_amount']?.toString() ?? '0',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          '申請退款',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '行程 #${trip['trip_id']}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                '退款原因（至少 10 個字）',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reasonController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '請說明退款原因...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '退款金額（SUI）',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '輸入退款金額',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              final amountStr = amountController.text.trim();

              if (reason.length < 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('退款原因至少需要 10 個字'), backgroundColor: Colors.red),
                );
                return;
              }

              final amount = double.tryParse(amountStr);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('請輸入有效的退款金額'), backgroundColor: Colors.red),
                );
                return;
              }

              Navigator.pop(context);
              await _submitRefundRequest(trip['trip_id'], reason, amount);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB954),
            ),
            child: const Text('提交申請'),
          ),
        ],
      ),
    );
  }

  // 載入保存的付款資訊
  Future<Map<String, dynamic>?> _loadSavedPaymentInfo(int tripId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'payment_$tripId';
      final paymentInfoStr = prefs.getString(key);

      if (paymentInfoStr != null) {
        return json.decode(paymentInfoStr) as Map<String, dynamic>;
      }
    } catch (e) {
      print('⚠️  載入付款資訊失敗: $e');
    }
    return null;
  }

  // 驗證保存的付款資訊
  Future<void> _verifyStoredPayment(int tripId, String? txHash) async {
    if (txHash == null || txHash.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ 交易 Hash 不存在'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ 請先登入'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 調用驗證 API
      final result = await ApiService.verifyTripPayment(
        tripId: tripId,
        txHash: txHash,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // 驗證成功，刪除本地保存的資訊
        await prefs.remove('payment_$tripId');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 付款驗證成功！'),
            backgroundColor: Colors.green,
          ),
        );

        // 重新載入行程列表
        _loadTrips();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 驗證失敗: ${result['error'] ?? '未知錯誤'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ 驗證失敗: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 提交退款請求
  Future<void> _submitRefundRequest(int tripId, String reason, double amount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請先登入'), backgroundColor: Colors.red),
        );
        return;
      }

      final result = await RefundService.createRefundRequest(
        tripId: tripId,
        reason: reason,
        refundAmountSui: amount,
        token: token,
      );

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 退款請求已提交！'),
            backgroundColor: Colors.green,
          ),
        );
        _loadTrips(); // 重新載入行程列表
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ 提交失敗: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("行程歷史"),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTrips,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF1DB954),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              '載入失敗',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTrips,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
              ),
              child: const Text('重試'),
            ),
          ],
        ),
      );
    }

    if (_trips.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              color: Colors.white70,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              '暫無行程記錄',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '開始您的第一次行程吧！',
              style: TextStyle(
                color: Colors.white70,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTrips,
      color: const Color(0xFF1DB954),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _trips.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final trip = _trips[index];
          return _buildTripCard(trip);
        },
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 標題行
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '行程 #${trip['trip_id']}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(trip['status']),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStatusText(trip['status']),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // 地址信息
          if (trip['pickup_address'] != null)
            _buildAddressRow(
              Icons.my_location,
              '起點',
              trip['pickup_address'],
            ),
          
          if (trip['dropoff_address'] != null)
            _buildAddressRow(
              Icons.location_pin,
              '終點',
              trip['dropoff_address'],
            ),
          
          const SizedBox(height: 12),
          
          // 行程信息
          Row(
            children: [
              if (trip['distance_km'] != null)
                Expanded(
                  child: _buildInfoItem(
                    '距離',
                    '${trip['distance_km'].toStringAsFixed(2)} 公里',
                  ),
                ),
              
              if (trip['total_amount'] != null)
                Expanded(
                  child: FutureBuilder<String>(
                    future: PriceService.formatDualCurrency(
                      double.tryParse(trip['total_amount'].toString()) ?? 0.0,
                    ),
                    builder: (context, snapshot) {
                      return _buildInfoItem(
                        '費用',
                        snapshot.data ?? '${trip['total_amount']} SUI',
                      );
                    },
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // 時間信息
          Text(
            '請求時間：${_formatDateTime(trip['requested_at'])}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          
          if (trip['completed_at'] != null)
            Text(
              '完成時間：${_formatDateTime(trip['completed_at'])}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),

          // 查看保存的付款信息按鈕（針對待驗證的行程）
          FutureBuilder<Map<String, dynamic>?>(
            future: _loadSavedPaymentInfo(trip['trip_id']),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                final paymentInfo = snapshot.data!;
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.info_outline, color: Colors.blue, size: 16),
                            SizedBox(width: 8),
                            Text(
                              '已保存付款資訊',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'TX Hash: ${paymentInfo['tx_hash']?.substring(0, 20)}...',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => _verifyStoredPayment(trip['trip_id'], paymentInfo['tx_hash']),
                          icon: const Icon(Icons.verified, size: 16),
                          label: const Text('立即驗證'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // 退款按鈕（僅顯示給已完成的行程）
          if (trip['status'] == 'completed')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showRefundDialog(trip),
                  icon: const Icon(Icons.money_off, size: 18),
                  label: const Text('申請退款'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFf59e0b),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddressRow(IconData icon, String label, String address) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white70,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            '$label：',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              address,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}