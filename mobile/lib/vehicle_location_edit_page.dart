import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'constants.dart';
import 'services/api_service.dart';

class VehicleLocationEditPage extends StatefulWidget {
  const VehicleLocationEditPage({super.key, required this.vehicle});

  final Map<String, dynamic> vehicle;

  @override
  State<VehicleLocationEditPage> createState() => _VehicleLocationEditPageState();
}

class _VehicleLocationEditPageState extends State<VehicleLocationEditPage> {
  late LatLng _selectedLocation;
  bool _isSubmitting = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    final lat = (widget.vehicle['current_lat'] ?? widget.vehicle['lat'] ?? 25.033).toDouble();
    final lng = (widget.vehicle['current_lng'] ?? widget.vehicle['lon'] ?? 121.565).toDouble();
    _selectedLocation = LatLng(lat, lng);
  }

  Future<void> _updateLocation() async {
    final vehicleId = widget.vehicle['vehicle_id']?.toString() ?? widget.vehicle['id']?.toString();
    if (vehicleId == null) {
      setState(() => _statusMessage = '無法取得車輛 ID');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = '更新中...';
    });

    final result = await ApiService.updateVehicleLocation(
      vehicleId: vehicleId,
      lat: _selectedLocation.latitude,
      lng: _selectedLocation.longitude,
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      setState(() => _statusMessage = '位置已更新');
      Navigator.pop(context, true);
    } else {
      setState(() => _statusMessage = result['error']?.toString() ?? '更新失敗');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('修改車輛位置')),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _selectedLocation,
                initialZoom: 15,
                onTap: (_, latLng) => setState(() => _selectedLocation = latLng),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://api.mapbox.com/styles/v1/mapbox/light-v11/tiles/{z}/{x}/{y}?access_token=$mapboxAccessToken',
                  userAgentPackageName: 'com.autodrive.driver',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on, color: Colors.redAccent, size: 38),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_statusMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _statusMessage!,
                style: const TextStyle(color: Colors.white60),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _updateLocation,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.check, color: Colors.black),
              label: const Text('更新位置', style: TextStyle(color: Colors.black)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
