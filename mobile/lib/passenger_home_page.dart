import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'payment_page.dart';
import 'services/api_service.dart';
import 'services/google_places_service.dart';
import 'session_manager.dart';
import 'trip_history_page.dart';
import 'widgets/google_place_search_field.dart';

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

  List<Map<String, dynamic>> _vehicles = [];
  Map<String, dynamic>? _selectedVehicle;
  Map<String, dynamic>? _tripEstimate;
  LatLng? _destination;
  String? _destinationAddress;
  Map<String, dynamic>? _activeTrip;

  bool _isLoadingVehicles = false;
  bool _isRequestingRide = false;
  Timer? _pollingTimer;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _checkActiveTrip();
    _loadNearbyVehicles(initial: true);
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _loadNearbyVehicles();
      }
    });
  }

  Future<void> _checkActiveTrip() async {
    if (_session == null) return;

    print('🔍 檢查進行中的行程...');

    final result = await ApiService.getUserTrips(limit: 10);

    if (!mounted) return;

    setState(() {
      if (result['success'] == true && result['data'] is List) {
        final trips = result['data'] as List;
        print('📋 找到 ${trips.length} 個行程');

        // 查找進行中的行程
        for (var trip in trips) {
          final status = trip['status']?.toString().toLowerCase();
          print('  - 行程 ${trip['trip_id']}: 狀態 = $status');

          if (status == 'requested' ||
              status == 'matched' ||
              status == 'accepted' ||
              status == 'picked_up' ||
              status == 'in_progress') {
            _activeTrip = trip as Map<String, dynamic>;
            _statusMessage = '您有進行中的行程（狀態：$status）';
            print('✅ 找到進行中的行程: ${trip['trip_id']}');
            break;
          }
        }

        if (_activeTrip == null) {
          print('❌ 沒有進行中的行程');
        }
      } else {
        print('❌ 獲取行程失敗: ${result['error']}');
      }
    });
  }

  Future<void> _cancelActiveTrip() async {
    if (_activeTrip == null) return;

    final tripId = _activeTrip!['trip_id'];

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF2E2E2E),
            title: const Text('取消行程', style: TextStyle(color: Colors.white)),
            content: const Text(
              '確定要取消當前行程嗎？',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('返回'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('取消行程'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    setState(() => _statusMessage = '正在取消行程...');

    final result = await ApiService.cancelTrip(
      tripId: tripId,
      reason: '乘客取消',
      cancelledBy: 'passenger',
    );

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _activeTrip = null;
        _statusMessage = '行程已取消';
      });
    } else {
      setState(() {
        _statusMessage = '取消失敗：${result['error']}';
      });
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  UserSession? get _session => widget.session;

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

  Future<void> _loadTripEstimate() async {
    if (_destination == null) return;
    setState(() {
      _statusMessage = '計算預估車資...';
    });

    final result = await ApiService.getTripEstimate(
      pickupLat: _userLocation.latitude,
      pickupLng: _userLocation.longitude,
      dropoffLat: _destination!.latitude,
      dropoffLng: _destination!.longitude,
    );

    if (!mounted) return;

    // 調試信息
    print('=== 費用預估 API 響應 ===');
    print('Success: ${result['success']}');
    print('Data: ${result['data']}');
    print('Error: ${result['error']}');

    setState(() {
      if (result['success'] == true && result['data'] is Map) {
        _tripEstimate = result['data'] as Map<String, dynamic>;
        print('費用預估數據: $_tripEstimate');
        _statusMessage = '預估車資已更新';
      } else {
        _tripEstimate = null;
        _statusMessage = result['error']?.toString() ?? '無法取得預估資訊';
      }
    });
  }

  Future<void> _requestRide() async {
    // 檢查是否有進行中的行程
    if (_activeTrip != null) {
      setState(() => _statusMessage = '您已有進行中的行程，請先完成或取消');
      return;
    }

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
      dropoffAddress: _destinationAddress ?? _searchController.text,
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
      setState(() {
        _activeTrip = trip;
        _statusMessage = '叫車成功！行程 ID: ${trip['trip_id']}';
      });

      // 獲取費用（從 trip 或 _tripEstimate）
      int? fareAmount;
      if (_tripEstimate != null && _tripEstimate!['estimated_fare'] is Map) {
        fareAmount = _tripEstimate!['estimated_fare']['total_amount'] as int?;
      }
      fareAmount ??= trip['fare'] as int?;
      
      print('💰 傳遞給支付頁面的費用: $fareAmount micro SUI');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => PaymentPage(
                session: _session,
                tripId: trip['trip_id'],
                fare: fareAmount,
                startAddress: trip['pickup_address'] ?? '當前位置',
                endAddress:
                    trip['dropoff_address'] ??
                    _destinationAddress ??
                    _searchController.text,
                vehicleId: _selectedVehicle?['vehicle_id']?.toString(),
              ),
        ),
      ).then((_) {
        // 從支付頁面返回後重新檢查行程狀態
        _checkActiveTrip();
      });
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
          if (_activeTrip != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1DB954),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_taxi, size: 16, color: Colors.black),
                  const SizedBox(width: 4),
                  Text(
                    '進行中',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
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
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _userLocation,
                initialZoom: 13,
                onTap: (tapPosition, point) async {
                  // 使用反向地理編碼獲取地址
                  final address = await GooglePlacesService.reverseGeocode(
                    point,
                  );

                  setState(() {
                    _destination = point;
                    _destinationAddress = address ?? '未知地址';
                    _tripEstimate = null;
                    // 更新搜尋框顯示地址
                    if (address != null) {
                      _searchController.text = address;
                    }
                  });
                  _loadTripEstimate();
                },
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
          _buildBottomSheet(),
        ],
      ),
    );
  }

  Widget _buildBottomSheet() {
    // 如果有進行中的行程，顯示行程狀態
    if (_activeTrip != null) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.3,
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
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_taxi,
                  color: Color(0xFF1DB954),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '進行中的行程',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '狀態：${_activeTrip!['status'] ?? '未知'}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _openTripHistory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '查看詳情',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _cancelActiveTrip,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '取消行程',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // 正常的叫車界面
    return SafeArea(
      top: false,
      child: Container(
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GooglePlaceSearchField(
              controller: _searchController,
              hintText: '搜尋目的地',
              userLocation: _userLocation,
              onPlaceSelected: (coordinates, address) {
                setState(() {
                  _destination = coordinates;
                  _destinationAddress = address;
                  _tripEstimate = null;
                });
                _mapController.move(coordinates, 15);
                _loadTripEstimate();
              },
            ),
            const SizedBox(height: 6),
            if (_tripEstimate != null)
              _TripEstimateView(estimate: _tripEstimate!),
            if (_statusMessage != null && _tripEstimate == null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _statusMessage!,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 6),
            if (_vehicles.isNotEmpty)
              SizedBox(
                height: 65,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (_, index) {
                    final vehicle = _vehicles[index];
                    final selected = identical(vehicle, _selectedVehicle);
                    return _VehicleChip(
                      vehicle: vehicle,
                      selected: selected,
                      onTap: () => setState(() => _selectedVehicle = vehicle),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemCount: _vehicles.length,
                ),
              ),
            if (_isLoadingVehicles)
              const SizedBox(
                height: 65,
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF1DB954)),
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        (_isRequestingRide ||
                                _destination == null ||
                                _selectedVehicle == null)
                            ? null
                            : _requestRide,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.grey.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        _isRequestingRide
                            ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            )
                            : const Text(
                              '叫車',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isLoadingVehicles ? null : _loadNearbyVehicles,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E2E2E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Icon(Icons.refresh, size: 18),
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

  String _formatFare(dynamic fareData) {
    if (fareData == null) return '--';

    // 如果是 TripFareBreakdown 對象
    if (fareData is Map<String, dynamic>) {
      final totalAmount = fareData['total_amount'];
      if (totalAmount != null) {
        // 從 micro SUI 轉換為 SUI (除以 1,000,000)
        final suiAmount = (totalAmount / 1000000).toStringAsFixed(4);
        return '$suiAmount SUI';
      }
    }

    // 如果是數字
    if (fareData is num) {
      final suiAmount = (fareData / 1000000).toStringAsFixed(4);
      return '$suiAmount SUI';
    }

    return fareData.toString();
  }

  @override
  Widget build(BuildContext context) {
    // 處理 estimated_fare 對象
    final fareData = estimate['estimated_fare'];
    final eta = estimate['estimated_duration_minutes'];
    final distance = estimate['estimated_distance_km'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long, color: Color(0xFF1DB954), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '預估金額：${_formatFare(fareData)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (distance != null) ...[
                      Text(
                        '${distance.toStringAsFixed(1)} km',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      const Text(
                        ' • ',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                    if (eta != null)
                      Text(
                        '約 $eta 分鐘',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                  ],
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
        width: 135,
        height: 65,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1DB954) : const Color(0xFF2E2E2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              model,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            if (distance != null) ...[
              const SizedBox(height: 2),
              Text(
                '${distance.toStringAsFixed(1)} km',
                style: TextStyle(
                  color: selected ? Colors.black87 : Colors.white70,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (eta != null) ...[
              const SizedBox(height: 1),
              Text(
                '約 $eta 分',
                style: TextStyle(
                  color: selected ? Colors.black87 : Colors.white54,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
