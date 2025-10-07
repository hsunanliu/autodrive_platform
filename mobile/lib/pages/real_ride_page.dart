// mobile/lib/pages/real_ride_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import 'dart:async';

class RealRidePage extends StatefulWidget {
  const RealRidePage({super.key});

  @override
  State<RealRidePage> createState() => _RealRidePageState();
}

class _RealRidePageState extends State<RealRidePage> {
  final TextEditingController _controller = TextEditingController();
  final MapController _mapController = MapController();
  
  LatLng? _destination;
  LatLng _userLocation = const LatLng(25.0340, 121.5645); // 台北預設位置
  
  bool _confirmed = false;
  String _status = '';
  List<dynamic> _vehicles = [];
  Map<String, dynamic>? _selectedVehicle;
  Map<String, dynamic>? _currentTrip;
  Map<String, dynamic>? _tripEstimate;

  // 簡單的地址轉座標 (可以替換為真實的 geocoding 服務)
  Future<void> _geocodeAddress(String address) async {
    setState(() {
      _status = '搜尋中...';
      _destination = null;
    });

    // 簡單的地址映射 (實際應用中應該使用真實的 geocoding API)
    final addressMap = {
      '台北車站': const LatLng(25.0478, 121.5173),
      '西門町': const LatLng(25.0420, 121.5071),
      '信義區': const LatLng(25.0330, 121.5654),
      '松山區': const LatLng(25.0500, 121.5800),
      '大安區': const LatLng(25.0267, 121.5436),
    };

    LatLng? coords;
    
    // 尋找匹配的地址
    for (final entry in addressMap.entries) {
      if (address.contains(entry.key)) {
        coords = entry.value;
        break;
      }
    }

    if (coords != null) {
      setState(() {
        _destination = coords;
        _status = '✅ 目的地已設定';
        _mapController.move(_destination!, 15);
      });
      
      // 獲取行程預估
      await _getTripEstimate();
      
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _status = '');
        }
      });
    } else {
      setState(() => _status = '❌ 找不到該地址');
    }
  }

  // 獲取行程預估
  Future<void> _getTripEstimate() async {
    if (_destination == null) return;

    final result = await ApiService.getTripEstimate(
      pickupLat: _userLocation.latitude,
      pickupLng: _userLocation.longitude,
      dropoffLat: _destination!.latitude,
      dropoffLng: _destination!.longitude,
    );

    if (result['success']) {
      setState(() {
        _tripEstimate = result['data'];
      });
    }
  }

  // 載入附近車輛
  Future<void> _loadNearbyVehicles() async {
    setState(() => _status = '載入附近車輛...');

    final result = await ApiService.getAvailableVehicles(
      lat: _userLocation.latitude,
      lng: _userLocation.longitude,
      radiusKm: 5.0,
      limit: 10,
    );

    if (result['success']) {
      setState(() {
        _vehicles = result['data'];
        _status = '找到 ${_vehicles.length} 輛可用車輛';
      });
      
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _status = '');
        }
      });
    } else {
      setState(() => _status = '❌ 載入車輛失敗');
    }
  }

  // 確認目的地並載入車輛
  void _confirmDestination() async {
    if (_destination != null) {
      setState(() {
        _confirmed = true;
        _mapController.move(_userLocation, 15);
      });
      
      await _loadNearbyVehicles();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('目的地已確認！正在載入附近車輛...'),
        ),
      );
    }
  }

  // 選擇車輛
  void _selectVehicle(Map<String, dynamic> vehicle) {
    setState(() => _selectedVehicle = vehicle);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已選擇車輛：${vehicle['vehicle_id']}'),
        action: SnackBarAction(
          label: '叫車',
          onPressed: _requestRide,
        ),
      ),
    );
  }

  // 發送叫車請求
  Future<void> _requestRide() async {
    if (_destination == null || _selectedVehicle == null) return;

    setState(() => _status = '發送叫車請求...');

    final result = await ApiService.createTripRequest(
      pickupLat: _userLocation.latitude,
      pickupLng: _userLocation.longitude,
      pickupAddress: '當前位置',
      dropoffLat: _destination!.latitude,
      dropoffLng: _destination!.longitude,
      dropoffAddress: _controller.text,
      passengerCount: 1,
      preferredVehicleType: _selectedVehicle!['vehicle_type'],
      notes: '透過 AutoDrive 叫車',
    );

    if (result['success']) {
      setState(() {
        _currentTrip = result['data'];
        _status = '✅ 叫車成功！行程 ID: ${_currentTrip!['trip_id']}';
      });
      
      _showTripDetails();
    } else {
      setState(() => _status = '❌ 叫車失敗');
    }
  }

  // 顯示行程詳情
  void _showTripDetails() {
    if (_currentTrip == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '行程詳情',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildDetailRow('行程 ID', _currentTrip!['trip_id'].toString()),
            _buildDetailRow('狀態', _currentTrip!['status']),
            _buildDetailRow('距離', '${_currentTrip!['distance_km']?.toStringAsFixed(2)} 公里'),
            
            if (_currentTrip!['fare_breakdown'] != null) ...[
              const SizedBox(height: 12),
              const Text(
                '費用明細',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildDetailRow('基本費用', '${_currentTrip!['fare_breakdown']['base_fare']} micro IOTA'),
              _buildDetailRow('距離費用', '${_currentTrip!['fare_breakdown']['distance_fare']} micro IOTA'),
              _buildDetailRow('總金額', '${_currentTrip!['fare_breakdown']['total_amount']} micro IOTA'),
            ],
            
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB954),
                ),
                child: const Text('確定'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          // 地圖
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.mapbox.com/styles/v1/mapbox/light-v11/tiles/512/{z}/{x}/{y}@2x?access_token=pk.eyJ1IjoiaHkxaWlpIiwiYSI6ImNtYmM4a204djFiaHEyaXByZTkwYmNmZW0ifQ.Gbt4zAxe38-eS7b7pCC6HA',
                additionalOptions: const {
                  'access_token':
                      'pk.eyJ1IjoiaHkxaWlpIiwiYSI6ImNtYmM4a204djFiaHEyaXByZTkwYmNmZW0ifQ.Gbt4zAxe38-eS7b7pCC6HA',
                },
                tileSize: 512,
                zoomOffset: -1,
              ),

              MarkerLayer(
                markers: [
                  // 用戶位置
                  Marker(
                    width: 40,
                    height: 40,
                    point: _userLocation,
                    child: const Icon(
                      Icons.person_pin_circle,
                      color: Colors.blue,
                      size: 40,
                    ),
                  ),

                  // 目的地標記
                  if (_destination != null)
                    Marker(
                      point: _destination!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),

                  // 真實車輛標記
                  if (_confirmed)
                    ..._vehicles.map((vehicle) {
                      final lat = vehicle['location_lat'] ?? vehicle['current_lat'];
                      final lng = vehicle['location_lng'] ?? vehicle['current_lng'];
                      
                      if (lat == null || lng == null) return null;

                      return Marker(
                        point: LatLng(lat.toDouble(), lng.toDouble()),
                        width: 80,
                        height: 60,
                        child: GestureDetector(
                          onTap: () => _selectVehicle(vehicle),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  vehicle['vehicle_id'],
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.directions_car,
                                color: Colors.green,
                                size: 30,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).where((marker) => marker != null).cast<Marker>(),
                ],
              ),
            ],
          ),

          // 搜尋框
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: "要去哪裡？",
                ),
                onSubmitted: (text) {
                  if (text.isNotEmpty) _geocodeAddress(text);
                },
              ),
            ),
          ),

          // 行程預估信息
          if (_tripEstimate != null)
            Positioned(
              top: 120,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '行程預估',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '距離: ${_tripEstimate!['estimated_distance_km']?.toStringAsFixed(2)} 公里',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(
                      '預估費用: ${_tripEstimate!['estimated_fare']['total_amount']} micro IOTA',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(
                      '可用車輛: ${_tripEstimate!['available_vehicles_count']} 輛',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),

          // 狀態信息
          if (_status.isNotEmpty)
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _status,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // 確認目的地按鈕
          if (_destination != null && !_confirmed)
            Positioned(
              bottom: 90,
              left: 20,
              right: 20,
              child: ElevatedButton(
                onPressed: _confirmDestination,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB954),
                ),
                child: const Text("確認目的地"),
              ),
            ),
        ],
      ),
    );
  }
}