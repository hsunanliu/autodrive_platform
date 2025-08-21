// 顯示所有車輛與 ETA 的地圖
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class VehicleMapPage extends StatefulWidget {
  const VehicleMapPage({super.key});

  @override
  State<VehicleMapPage> createState() => _VehicleMapPageState();
}

class _VehicleMapPageState extends State<VehicleMapPage> {
  List<Marker> _markers = [];
  LatLng? _center;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVehicleMarkers();
  }

  Future<void> _loadVehicleMarkers() async {
    final jsonStr = await rootBundle.loadString('assets/vehicles.json');
    final List<dynamic> data = json.decode(jsonStr);
    final List<Marker> markers = [];

    for (final v in data) {
      final lat = v['location'][0];
      final lon = v['location'][1];
      final id = v['id'];

      final eta = await _getEta(LatLng(lat, lon));

      markers.add(
        Marker(
          width: 150,
          height: 60,
          point: LatLng(lat, lon),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('$id\nETA: $eta min', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
              ),
              const Icon(Icons.directions_car, color: Colors.red),
            ],
          ),
        ),
      );
    }

    setState(() {
      _markers = markers;
      _center = _markers.firstOrNull?.point ?? LatLng(25.04, 121.56);
      _loading = false;
    });
  }

  Future<String> _getEta(LatLng from) async {
    // 模擬一個固定目的地：政治大學
    const dest = LatLng(25.0173, 121.4326);
    final url = Uri.parse(
        'http://localhost:5000/route?from=${from.latitude},${from.longitude}&to=${dest.latitude},${dest.longitude}');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['eta_minutes'].toString();
      }
    } catch (e) {
      debugPrint('Failed to get ETA: $e');
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('所有車輛與 ETA')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              options: MapOptions(center: _center, zoom: 13),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                ),
                MarkerLayer(markers: _markers),
              ],
            ),
    );
  }
}
