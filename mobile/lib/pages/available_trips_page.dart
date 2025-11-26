// mobile/lib/pages/available_trips_page.dart

import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/price_service.dart';
import '../session_manager.dart';
import '../widgets/street_view_image.dart';

class AvailableTripsPage extends StatefulWidget {
  const AvailableTripsPage({super.key, required this.session});

  final UserSession? session;

  @override
  State<AvailableTripsPage> createState() => _AvailableTripsPageState();
}

class _AvailableTripsPageState extends State<AvailableTripsPage> {
  List<Map<String, dynamic>> _availableTrips = [];
  bool _isLoading = false;
  Timer? _refreshTimer;
  final WebSocketService _ws = WebSocketService();

  @override
  void initState() {
    super.initState();
    _loadAvailableTrips();
    _setupWebSocket();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _ws.off('new_trip_available');
    _ws.off('joined_drivers_room');
    // 離開司機在線房間
    _ws.emit('leave_drivers_room', {});
    print('📡 司機端：已離開 drivers_online 房間');
    super.dispose();
  }

  /// 設置 WebSocket 事件監聽
  void _setupWebSocket() {
    // 監聽加入房間確認
    _ws.on('joined_drivers_room', (data) {
      print('✅ 司機端：成功加入 drivers_online 房間 - $data');
    });

    // 監聽新訂單通知
    _ws.on('new_trip_available', (data) {
      print('📨 司機端收到新訂單通知: $data');
      if (mounted) {
        // 重新載入訂單列表
        _loadAvailableTrips();
        // 顯示通知
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚖 新訂單可接！'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });

    // 加入司機在線房間，接收新訂單通知
    _ws.emit('join_drivers_room', {});
    print('📡 司機端：請求加入 drivers_online 房間');
  }

  Future<void> _loadAvailableTrips() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);

    final result = await ApiService.getAvailableTrips(limit: 20);
    
    if (!mounted) return;

    if (result['success'] == true && result['data'] is List) {
      final trips = (result['data'] as List)
          .whereType<Map<String, dynamic>>()
          .toList();
      
      setState(() {
        _availableTrips = trips;
        _isLoading = false;
      });
    } else {
      setState(() {
        _availableTrips = [];
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('載入失敗: ${result['error'] ?? '未知錯誤'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _acceptTrip(int tripId) async {
    // 顯示確認對話框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認接單'),
        content: const Text('確定要接受這個行程嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('確認接單'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    final result = await ApiService.acceptTrip(
      tripId: tripId,
      etaMinutes: 10,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ 接單成功！'),
          backgroundColor: Colors.green,
        ),
      );
      // 跳轉到行程進行頁面
      Navigator.pushNamed(
        context,
        '/trip_in_progress',
        arguments: {
          'session': widget.session,
          'tripId': tripId,
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ 接單失敗: ${result['error']}'),
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
        title: const Text('可接單行程'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAvailableTrips,
          ),
        ],
      ),
      body: _isLoading && _availableTrips.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _availableTrips.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 80,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '目前沒有可接單的行程',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _loadAvailableTrips,
                        icon: const Icon(Icons.refresh),
                        label: const Text('重新整理'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAvailableTrips,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _availableTrips.length,
                    itemBuilder: (context, index) {
                      final trip = _availableTrips[index];
                      return _buildTripCard(trip);
                    },
                  ),
                ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final tripId = trip['trip_id'] as int;
    final pickupAddress = trip['pickup_address'] as String? ?? '未知';
    final dropoffAddress = trip['dropoff_address'] as String? ?? '未知';
    final distance = trip['distance_km'] as double? ?? 0.0;

    // 獲取經緯度座標用於街景圖片
    final pickupLat = trip['pickup_lat'] as double?;
    final pickupLng = trip['pickup_lng'] as double?;

    // 處理金額：使用與 trip_history 相同的三層判斷邏輯
    final rawAmount = trip['total_amount'];
    double fare = 0.0;
    if (rawAmount != null && rawAmount is num) {
      if (rawAmount > 100000000) {
        // 原始 MIST 格式
        fare = rawAmount / 1000000000;
      } else if (rawAmount > 1000) {
        // 錯誤的中間格式（之前除以 1000 的結果）
        fare = rawAmount / 1000000;
      } else {
        // 正確的 SUI 格式
        fare = rawAmount.toDouble();
      }
    }

    final passengerCount = trip['passenger_count'] as int? ?? 1;

    // 動態定價資訊
    final priority = trip['priority'] as int? ?? 2;
    final priceType = trip['price_type'] as String? ?? 'standard';
    final surgeMultiplier = trip['surge_multiplier'] as double? ?? 1.0;
    final surgeReason = trip['surge_reason'] as String?;

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 行程 ID 和優先級標籤
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      '行程 #$tripId',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Priority 標籤
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: priority == 1
                            ? const Color(0xFFFFB84D) // 快速叫車 - 橘色
                            : Colors.grey.shade700, // 標準叫車 - 灰色
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            priority == 1 ? Icons.flash_on : Icons.schedule,
                            size: 14,
                            color: priority == 1 ? Colors.black : Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            priority == 1 ? '快速' : '標準',
                            style: TextStyle(
                              color: priority == 1 ? Colors.black : Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                FutureBuilder<String>(
                  future: PriceService.formatDualCurrency(fare),
                  builder: (context, snapshot) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        snapshot.data ?? '${fare.toStringAsFixed(4)} SUI',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            // 動態加價資訊
            if (surgeMultiplier > 1.0 && surgeReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFFB84D).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Color(0xFFFFB84D),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        surgeReason,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Text(
                      '${surgeMultiplier}x',
                      style: const TextStyle(
                        color: Color(0xFFFFB84D),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // 上車點
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pickupAddress,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 下車點
            Row(
              children: [
                const Icon(
                  Icons.flag,
                  color: Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dropoffAddress,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 行程信息
            Row(
              children: [
                _buildInfoChip(
                  Icons.straighten,
                  '${distance.toStringAsFixed(1)} km',
                ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  Icons.person,
                  '$passengerCount 人',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 上車點街景圖片（如果有座標）
            if (pickupLat != null && pickupLng != null) ...[
              ExpandableStreetViewCard(
                latitude: pickupLat,
                longitude: pickupLng,
                title: '上車點街景',
                subtitle: pickupAddress,
              ),
              const SizedBox(height: 12),
            ],

            // 接單按鈕
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _acceptTrip(tripId),
                icon: const Icon(Icons.check_circle),
                label: const Text(
                  '接受行程',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
