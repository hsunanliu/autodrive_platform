// mobile/lib/pages/available_trips_page.dart

import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../session_manager.dart';

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

  @override
  void initState() {
    super.initState();
    _loadAvailableTrips();
    // 每10秒刷新一次
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _loadAvailableTrips();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
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
      Navigator.pushReplacementNamed(
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
    
    // total_amount 是 micro SUI，需要轉換
    final totalAmountMicro = trip['total_amount'];
    final fare = totalAmountMicro != null 
        ? (totalAmountMicro is int ? totalAmountMicro / 1000000.0 : 0.0)
        : 0.0;
    
    final passengerCount = trip['passenger_count'] as int? ?? 1;

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 行程 ID
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '行程 #$tripId',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${fare.toStringAsFixed(0)} SUI',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
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
