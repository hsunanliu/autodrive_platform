import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'payment_page.dart';
import 'services/api_service.dart';
import 'session_manager.dart';
import 'trip_history_page.dart';

class PassengerHomePage extends StatefulWidget {
  const PassengerHomePage({super.key, required this.session});

  final UserSession? session;

  @override
  State<PassengerHomePage> createState() => _PassengerHomePageState();
}

class _PassengerHomePageState extends State<PassengerHomePage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final LatLng _userLocation = const LatLng(25.0330, 121.5654);

  final List<_Place> _places = const [
    _Place(name: '台北車站', latLng: LatLng(25.0478, 121.5173)),
    _Place(name: '信義區', latLng: LatLng(25.0330, 121.5654)),
    _Place(name: '松山區', latLng: LatLng(25.0500, 121.5800)),
    _Place(name: '大安區', latLng: LatLng(25.0267, 121.5436)),
    _Place(name: '西門町', latLng: LatLng(25.0420, 121.5071)),
  ];

  List<_Place> _suggestions = const [];
  List<Map<String, dynamic>> _vehicles = [];
  Map<String, dynamic>? _selectedVehicle;
  Map<String, dynamic>? _tripEstimate;
  LatLng? _destination;

  bool _isLoadingVehicles = false;
  bool _isLoadingEstimate = false;
  bool _isRequestingRide = false;
  Timer? _pollingTimer;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadNearbyVehicles(initial: true);
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _loadNearbyVehicles();
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  UserSession? get _session => widget.session;

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _suggestions = const []);
      return;
    }

    final lower = query.toLowerCase();
    setState(() {
      _suggestions =
          _places
              .where((place) => place.name.toLowerCase().contains(lower))
              .toList();
    });
  }

  Future<void> _loadNearbyVehicles({bool initial = false}) async {
    if (_session == null) return;
    setState(() {
      if (initial) {
        _statusMessage = '載入附近車輛...';
      }
      _isLoadingVehicles = true;
    });

    final result = await ApiService.getAvailableVehicles(
      lat: _userLocation.latitude,
      lng: _userLocation.longitude,
      radiusKm: 4,
      limit: 12,
    );

    if (!mounted) return;

    setState(() {
      _isLoadingVehicles = false;
      if (result['success'] == true && result['data'] is List) {
        _vehicles = (result['data'] as List)
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
        _statusMessage = '找到 ${_vehicles.length} 輛可用車輛';
      } else {
        _vehicles = [];
        _statusMessage = result['error']?.toString() ?? '無法取得可用車輛';
      }
    });
  }

  Future<void> _selectDestination(_Place place) async {
    _mapController.move(place.latLng, 14);
    setState(() {
      _destination = place.latLng;
      _searchController.text = place.name;
      _suggestions = const [];
      _tripEstimate = null;
    });

    await _loadTripEstimate();
  }

  Future<void> _loadTripEstimate() async {
    if (_destination == null) return;
    setState(() {
      _isLoadingEstimate = true;
      _statusMessage = '計算預估車資...';
    });

    final result = await ApiService.getTripEstimate(
      pickupLat: _userLocation.latitude,
      pickupLng: _userLocation.longitude,
      dropoffLat: _destination!.latitude,
      dropoffLng: _destination!.longitude,
    );

    if (!mounted) return;

    setState(() {
      _isLoadingEstimate = false;
      if (result['success'] == true && result['data'] is Map) {
        _tripEstimate = result['data'] as Map<String, dynamic>;
        _statusMessage = '預估車資已更新';
      } else {
        _tripEstimate = null;
        _statusMessage = result['error']?.toString() ?? '無法取得預估資訊';
      }
    });
  }

  Future<void> _requestRide() async {
    if (_session == null || _destination == null || _selectedVehicle == null) {
      setState(() => _statusMessage = '請先選擇目的地與車輛');
      return;
    }

    setState(() {
      _isRequestingRide = true;
      _statusMessage = '發送叫車請求...';
    });

    final result = await ApiService.createTripRequest(
      pickupLat: _userLocation.latitude,
      pickupLng: _userLocation.longitude,
      pickupAddress: '當前位置',
      dropoffLat: _destination!.latitude,
      dropoffLng: _destination!.longitude,
      dropoffAddress: _searchController.text,
      passengerCount: 1,
      preferredVehicleType: _selectedVehicle?['vehicle_type']?.toString(),
      notes: 'AutoDrive 乘客端叫車',
    );

    if (!mounted) return;

    setState(() {
      _isRequestingRide = false;
    });

    if (result['success'] == true && result['data'] is Map) {
      final trip = result['data'] as Map<String, dynamic>;
      setState(() => _statusMessage = '叫車成功！行程 ID: ${trip['trip_id']}');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => PaymentPage(
                session: _session,
                fare:
                    trip['estimated_cost'] ?? _tripEstimate?['estimated_cost'],
                startAddress: trip['pickup_address'] ?? '當前位置',
                endAddress: trip['dropoff_address'] ?? _searchController.text,
                vehicleId: _selectedVehicle?['vehicle_id']?.toString(),
              ),
        ),
      );
    } else {
      setState(() {
        _statusMessage =
            result['data']?['detail']?.toString() ??
            result['error']?.toString() ??
            '叫車失敗';
      });
    }
  }

  void _openTripHistory() {
    if (_session == null) return;
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
            onPressed:
                () => Navigator.pushReplacementNamed(context, '/role_select'),
            child: const Text('請先登入'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('乘客首頁'),
        actions: [
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
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _userLocation,
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}@2x?access_token=pk.eyJ1IjoiaHkxaWlpIiwiYSI6ImNtZW4wcHdraDB3a3Mya3Nlc29mNGY3ZHAifQ.c1EtA8uDOpR7Q2-uPVJSaA',
                  userAgentPackageName: 'com.autodrive.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userLocation,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.person_pin_circle,
                        color: Colors.amber,
                        size: 32,
                      ),
                    ),
                    if (_destination != null)
                      Marker(
                        point: _destination!,
                        width: 36,
                        height: 36,
                        child: const Icon(
                          Icons.flag,
                          color: Colors.greenAccent,
                          size: 28,
                        ),
                      ),
                    ..._vehicles.map((vehicle) {
                      final lat =
                          (vehicle['location_lat'] ?? vehicle['current_lat'])
                              ?.toDouble();
                      final lng =
                          (vehicle['location_lng'] ?? vehicle['current_lng'])
                              ?.toDouble();
                      if (lat == null || lng == null) {
                        return null;
                      }
                      return Marker(
                        point: LatLng(lat, lng),
                        width: 32,
                        height: 32,
                        child: const Icon(
                          Icons.directions_car,
                          color: Colors.lightBlueAccent,
                        ),
                      );
                    }).whereType<Marker>(),
                  ],
                ),
              ],
            ),
          ),
          _buildBottomSheet(context),
        ],
      ),
    );
  }

  Widget _buildBottomSheet(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '輸入目的地',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white10,
                suffixIcon:
                    _searchController.text.isEmpty
                        ? null
                        : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _destination = null;
                              _tripEstimate = null;
                            });
                          },
                          icon: const Icon(Icons.clear, color: Colors.white54),
                        ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 12),
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _suggestions.length,
                  itemBuilder: (_, index) {
                    final place = _suggestions[index];
                    return ListTile(
                      title: Text(
                        place.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () => _selectDestination(place),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            if (_tripEstimate != null)
              _TripEstimateView(estimate: _tripEstimate!),
            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _statusMessage!,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              height: 60,
              child:
                  _isLoadingVehicles
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1DB954),
                        ),
                      )
                      : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (_, index) {
                          final vehicle = _vehicles[index];
                          final selected = identical(vehicle, _selectedVehicle);
                          return _VehicleChip(
                            vehicle: vehicle,
                            selected: selected,
                            onTap:
                                () =>
                                    setState(() => _selectedVehicle = vehicle),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemCount: _vehicles.length,
                      ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRequestingRide ? null : _requestRide,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child:
                        _isRequestingRide
                            ? const CircularProgressIndicator(
                              color: Colors.black,
                            )
                            : const Text(
                              '叫車',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoadingVehicles ? null : _loadNearbyVehicles,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E2E2E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Icon(Icons.refresh),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TripEstimateView extends StatelessWidget {
  const _TripEstimateView({required this.estimate});

  final Map<String, dynamic> estimate;

  @override
  Widget build(BuildContext context) {
    final fare = estimate['estimated_cost'];
    final eta = estimate['estimated_duration_minutes'];
    final distance = estimate['estimated_distance_km'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long, color: Color(0xFF1DB954)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '預估金額：${fare ?? '--'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (distance != null)
                  Text(
                    '距離：約 ${distance.toString()} 公里',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                if (eta != null)
                  Text(
                    '時間：約 ${eta.toString()} 分鐘',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleChip extends StatelessWidget {
  const _VehicleChip({
    required this.vehicle,
    required this.selected,
    required this.onTap,
  });

  final Map<String, dynamic> vehicle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final model = vehicle['model']?.toString() ?? '未知車輛';
    final distance = vehicle['distance_km'];
    final eta = vehicle['estimated_arrival_minutes'];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1DB954) : const Color(0xFF2E2E2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              model,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            if (distance != null)
              Text(
                '距離 ${distance.toString()} km',
                style: TextStyle(
                  color: selected ? Colors.black87 : Colors.white70,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (eta != null)
              Text(
                '約 ${eta.toString()} 分鐘',
                style: TextStyle(
                  color: selected ? Colors.black87 : Colors.white54,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

class _Place {
  const _Place({required this.name, required this.latLng});

  final String name;
  final LatLng latLng;
}
