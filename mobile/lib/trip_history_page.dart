import 'package:flutter/material.dart';

import 'services/api_service.dart';
import 'session_manager.dart';

class TripHistoryPage extends StatefulWidget {
  const TripHistoryPage({super.key, required this.session});

  final UserSession? session;

  @override
  State<TripHistoryPage> createState() => _TripHistoryPageState();
}

class _TripHistoryPageState extends State<TripHistoryPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _trips = const [];
  String? _error;

  UserSession? get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    if (_session == null) {
      setState(() {
        _isLoading = false;
        _error = '帳戶尚未登入';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await ApiService.getUserTrips(limit: 50);
    if (!mounted) return;

    if (result['success'] == true && result['data'] is List) {
      final trips = (result['data'] as List)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
      setState(() {
        _trips = trips;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _error = result['error']?.toString() ?? '載入失敗';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('行程歷史'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadTrips,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1DB954)),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_trips.isEmpty) {
      return const Center(
        child: Text(
          '目前沒有行程紀錄',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _trips.length,
      itemBuilder: (_, index) {
        final trip = _trips[index];
        return _TripCard(trip: trip);
      },
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});

  final Map<String, dynamic> trip;

  @override
  Widget build(BuildContext context) {
    final tripId = trip['trip_id'] ?? '--';
    final status = trip['status']?.toString() ?? 'unknown';
    final pickup = trip['pickup_address']?.toString() ?? '未知';
    final dropoff = trip['dropoff_address']?.toString() ?? '未知';
    final distance = trip['distance_km'];
    final amountMicro = trip['total_amount'];
    final amountIota = amountMicro is num ? amountMicro / 1000000 : null;
    final requestedAt = trip['requested_at'];

    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_taxi, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '行程 #$tripId',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                _StatusChip(status: status),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(icon: Icons.location_on, label: '起點', value: pickup),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.flag, label: '終點', value: dropoff),
            if (distance != null) ...[
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.route,
                label: '距離',
                value: '${distance.toString()} 公里',
              ),
            ],
            if (requestedAt != null) ...[
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.access_time,
                label: '發起時間',
                value: requestedAt.toString(),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              amountIota != null
                  ? '總金額：約 ${amountIota.toStringAsFixed(2)} IOTA'
                  : '總金額：--',
              style: const TextStyle(color: Color(0xFF1DB954), fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.white60),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              Text(value, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  Color get _color {
    switch (status) {
      case 'completed':
        return const Color(0xFF1DB954);
      case 'cancelled':
        return Colors.redAccent;
      case 'matched':
        return Colors.orange;
      case 'accepted':
        return Colors.blueAccent;
      default:
        return Colors.white24;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      ),
    );
  }
}
