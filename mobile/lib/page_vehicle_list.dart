import 'package:flutter/material.dart';

import 'services/api_service.dart';

class VehicleListPage extends StatefulWidget {
  const VehicleListPage({super.key});

  @override
  State<VehicleListPage> createState() => _VehicleListPageState();
}

class _VehicleListPageState extends State<VehicleListPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _vehicles = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await ApiService.getAvailableVehicles(
      lat: 25.0330,
      lng: 121.5654,
      radiusKm: 5,
      limit: 20,
    );

    if (!mounted) return;

    if (result['success'] == true && result['data'] is List) {
      setState(() {
        _vehicles = (result['data'] as List)
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
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
      appBar: AppBar(
        title: const Text('可用車輛'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadVehicles,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954)))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
              : ListView.builder(
                  itemCount: _vehicles.length,
                  itemBuilder: (_, index) {
                    final vehicle = _vehicles[index];
                    return ListTile(
                      leading: const Icon(Icons.directions_car, color: Colors.lightBlueAccent),
                      title: Text(vehicle['model']?.toString() ?? '未知車輛',
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        '距離: ${vehicle['distance_km'] ?? '--'} km · 預計 ${vehicle['estimated_arrival_minutes'] ?? '--'} 分鐘',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    );
                  },
                ),
    );
  }
}
