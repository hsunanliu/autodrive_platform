import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'services/api_service.dart';
import 'session_manager.dart';
import 'trip_history_page.dart';

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key, required this.session});

  final UserSession? session;

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  final MapController _mapController = MapController();
  final LatLng _defaultCenter = const LatLng(25.0340, 121.5620);

  List<Map<String, dynamic>> _vehicles = [];
  bool _isLoading = false;
  double _totalEarnings = 0;
  Timer? _pollTimer;
  String? _statusMessage;

  UserSession? get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _refreshData(initial: true);
    _pollTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted) {
        _refreshData();
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshData({bool initial = false}) async {
    if (_session == null) return;
    setState(() {
      _isLoading = true;
      if (initial) {
        _statusMessage = '載入車輛資訊...';
      }
    });

    final result = await ApiService.getMyVehicles();

    if (!mounted) return;

    if (result['success'] == true && result['data'] is List) {
      final vehicles = (result['data'] as List)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
      vehicles.sort((a, b) => (a['vehicle_id'] ?? '').compareTo(b['vehicle_id'] ?? ''));

      double total = 0;
      for (final vehicle in vehicles) {
        final value = vehicle['total_earnings_micro_iota'];
        if (value is num) {
          total += value.toDouble();
        } else if (value is String) {
          total += double.tryParse(value) ?? 0;
        }
      }

      setState(() {
        _vehicles = vehicles;
        _totalEarnings = total / 1000000; // micro IOTA -> IOTA
        _statusMessage = '已更新 ${vehicles.length} 輛車輛狀態';
      });

      if (vehicles.isNotEmpty) {
        final vehicle = vehicles.first;
        final lat = vehicle['current_lat']?.toDouble();
        final lng = vehicle['current_lng']?.toDouble();
        if (lat != null && lng != null) {
          _mapController.move(LatLng(lat, lng), 13);
        }
      }
    } else {
      setState(() {
        _vehicles = [];
        _statusMessage = result['error']?.toString() ?? '取得車輛資料失敗';
      });
    }

    setState(() => _isLoading = false);
  }

  Future<void> _updateVehicleStatus(String vehicleId, String status) async {
    final result = await ApiService.updateVehicleStatus(
      vehicleId: vehicleId,
      status: status,
    );

    if (result['success'] == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('車輛 $vehicleId 狀態已更新為 $status')),
      );
      await _refreshData();
    } else if (mounted) {
      final message = result['data']?['detail'] ?? result['error'] ?? '更新失敗';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message.toString())),
      );
    }
  }

  void _openVehicleRegistration() {
    Navigator.pushNamed(context, '/register_vehicle', arguments: {'session': _session});
  }

  void _openTripHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TripHistoryPage(session: _session)),
    );
  }

  void _openProfile() {
    Navigator.pushNamed(context, '/profile', arguments: {'session': _session});
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/role_select'),
            child: const Text('請先登入'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('司機控制台'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重新整理',
            onPressed: _isLoading ? null : _refreshData,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '行程紀錄',
            onPressed: _openTripHistory,
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: '個人檔案',
            onPressed: _openProfile,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openVehicleRegistration,
        backgroundColor: const Color(0xFF1DB954),
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('新增車輛', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _defaultCenter,
                initialZoom: 12,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}@2x?access_token=pk.eyJ1IjoiaHkxaWlpIiwiYSI6ImNtZW4wcHdraDB3a3Mya3Nlc29mNGY3ZHAifQ.c1EtA8uDOpR7Q2-uPVJSaA',
                  userAgentPackageName: 'com.autodrive.driver',
                ),
                MarkerLayer(
                  markers: [
                    ..._vehicles.map((vehicle) {
                      final lat = vehicle['current_lat']?.toDouble();
                      final lng = vehicle['current_lng']?.toDouble();
                      if (lat == null || lng == null) {
                        return null;
                      }
                      return Marker(
                        point: LatLng(lat, lng),
                        width: 36,
                        height: 36,
                        child: const Icon(Icons.directions_car, color: Colors.lightBlueAccent),
                      );
                    }).whereType<Marker>(),
                  ],
                ),
              ],
            ),
          ),
          _buildBottomSheet(),
        ],
      ),
    );
  }

  Widget _buildBottomSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, -3))],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '車隊總收益：${_totalEarnings.toStringAsFixed(2)} IOTA',
            style: const TextStyle(
              color: Color(0xFF1DB954),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_statusMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _statusMessage!,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954)))
          else if (_vehicles.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  '您目前沒有註冊車輛，點擊右下角新增。',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _vehicles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) {
                final vehicle = _vehicles[index];
                return _VehicleCard(
                  vehicle: vehicle,
                  onUpdateStatus: _updateVehicleStatus,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.onUpdateStatus,
  });

  final Map<String, dynamic> vehicle;
  final void Function(String vehicleId, String status) onUpdateStatus;

  @override
  Widget build(BuildContext context) {
    final id = vehicle['vehicle_id']?.toString() ?? '未知';
    final model = vehicle['model']?.toString() ?? '未命名車輛';
    final plate = vehicle['plate_number']?.toString() ?? '未設定';
    final charge = vehicle['current_charge_percent'];
    final status = vehicle['status']?.toString() ?? 'unknown';
    final distance = vehicle['total_distance_km'];
    final trips = vehicle['total_trips'];

    return Card(
      color: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_car, color: Colors.lightBlueAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$model ($plate)',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'available' ? const Color(0xFF1DB954) : Colors.amber,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (charge != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('電量：${charge.toString()}%',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: (charge as num).clamp(0, 100) / 100,
                    backgroundColor: Colors.grey[800],
                    color: Colors.lightBlueAccent,
                    minHeight: 6,
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _InfoChip(icon: Icons.route, label: '總里程', value: '${distance ?? '--'} km'),
                _InfoChip(icon: Icons.assignment_turned_in, label: '完成行程', value: '${trips ?? '--'}'),
                _InfoChip(icon: Icons.fingerprint, label: 'ID', value: id),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onUpdateStatus(id, 'available'),
                    child: const Text('設定為可接單'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => onUpdateStatus(id, 'offline'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                    child: const Text('暫停出勤'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF323232),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white54),
          const SizedBox(width: 6),
          Text(
            '$label：$value',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
