// mobile/lib/pages/trip_in_progress_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import '../services/google_directions_service.dart';
import '../session_manager.dart';

class TripInProgressPage extends StatefulWidget {
  const TripInProgressPage({
    super.key,
    required this.session,
    required this.tripId,
  });

  final UserSession? session;
  final int tripId;

  @override
  State<TripInProgressPage> createState() => _TripInProgressPageState();
}

class _TripInProgressPageState extends State<TripInProgressPage> {
  final MapController _mapController = MapController();
  
  Map<String, dynamic>? _tripData;
  DirectionsResult? _directions;
  LatLng? _currentPosition;
  
  bool _isLoading = true;
  String _status = 'accepted'; // accepted, picked_up, in_progress, completed
  Timer? _simulationTimer;
  Timer? _pollTimer;
  int _currentPointIndex = 0;
  
  @override
  void initState() {
    super.initState();
    _loadTripData();
    // 每 10 秒輪詢一次行程狀態（檢測支付狀態變化）
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && _status != 'completed') {
        _loadTripData();
      }
    });
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTripData() async {
    setState(() => _isLoading = true);

    print('🔍 載入行程詳情: Trip ID ${widget.tripId}');

    // 使用 getTripDetails API 獲取完整的行程數據（包含座標）
    final result = await ApiService.getTripDetails(widget.tripId);

    if (!mounted) return;

    if (result['success'] == true && result['data'] is Map) {
      final trip = result['data'] as Map<String, dynamic>;
      print('✅ 找到行程: ${trip['trip_id']}, 狀態: ${trip['status']}');
      
      setState(() {
        _tripData = trip;
        _status = trip['status'] ?? 'accepted';
      });

      // 獲取路線
      await _loadDirections();
    } else {
      print('❌ 獲取行程失敗: ${result['error']}');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('無法載入行程: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadDirections() async {
    if (_tripData == null) {
      print('❌ _tripData 為 null');
      return;
    }

    final pickupLat = _tripData!['pickup_lat'] as double?;
    final pickupLng = _tripData!['pickup_lng'] as double?;
    final dropoffLat = _tripData!['dropoff_lat'] as double?;
    final dropoffLng = _tripData!['dropoff_lng'] as double?;

    print('📍 起點: ($pickupLat, $pickupLng)');
    print('📍 終點: ($dropoffLat, $dropoffLng)');

    if (pickupLat == null || pickupLng == null || dropoffLat == null || dropoffLng == null) {
      print('❌ 座標數據不完整');
      return;
    }

    final origin = LatLng(pickupLat, pickupLng);
    final destination = LatLng(dropoffLat, dropoffLng);

    print('🗺️ 正在獲取路線...');
    final directions = await GoogleDirectionsService.getDirections(
      origin: origin,
      destination: destination,
    );

    if (!mounted) return;

    if (directions != null) {
      print('✅ 路線獲取成功: ${directions.polylinePoints.length} 個點');
      setState(() {
        _directions = directions;
        _currentPosition = directions.polylinePoints.first;
      });

      // 等待下一幀再移動地圖（確保 MapController 已初始化）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try {
            _mapController.move(origin, 14);
          } catch (e) {
            print('⚠️ 移動地圖失敗: $e');
          }
        }
      });
    } else {
      print('❌ 路線獲取失敗');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('無法獲取路線，請檢查網路連接'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _startSimulation() {
    if (_directions == null || _simulationTimer != null) return;

    final points = _directions!.polylinePoints;
    final totalPoints = points.length;
    final durationSeconds = _directions!.durationSeconds;
    final intervalMs = (durationSeconds * 1000 / totalPoints).round();

    _currentPointIndex = 0;

    _simulationTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (timer) {
        if (_currentPointIndex >= totalPoints - 1) {
          timer.cancel();
          _simulationTimer = null;
          // 自動完成行程
          if (_status == 'in_progress') {
            _completeTrip();
          }
          return;
        }

        setState(() {
          _currentPointIndex++;
          _currentPosition = points[_currentPointIndex];
        });

        // 移動地圖跟隨車輛
        try {
          _mapController.move(_currentPosition!, _mapController.camera.zoom);
        } catch (e) {
          // 忽略地圖移動錯誤
        }
      },
    );
  }

  Future<void> _updateTripStatus(String newStatus) async {
    setState(() => _isLoading = true);

    // 根據狀態調用不同的 API
    Map<String, dynamic> result;
    
    if (newStatus == 'picked_up') {
      result = await ApiService.pickupPassenger(widget.tripId);
      // 接到乘客後自動開始模擬移動
      if (result['success'] == true) {
        _startSimulation();
      }
    } else {
      result = {'success': false, 'error': '未知狀態'};
    }

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      setState(() => _status = newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ 狀態已更新為: $newStatus')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ 更新失敗: ${result['error']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _completeTrip() async {
    setState(() => _isLoading = true);

    final result = await ApiService.completeTrip(widget.tripId);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 行程已完成！款項已轉給司機'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      // 返回司機主頁
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      final errorMsg = result['error']?.toString() ?? '未知錯誤';
      
      // 特殊處理支付相關錯誤
      String displayMsg;
      if (errorMsg.contains('尚未支付')) {
        displayMsg = '❌ 乘客尚未支付，無法完成行程';
      } else if (errorMsg.contains('託管記錄')) {
        displayMsg = '❌ 找不到支付記錄，請聯繫客服';
      } else if (errorMsg.contains('支付釋放失敗')) {
        displayMsg = '❌ 支付釋放失敗，請稍後重試';
      } else {
        displayMsg = '❌ 完成失敗: $errorMsg';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(displayMsg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _tripData == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text('行程 #${widget.tripId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTripData,
          ),
        ],
      ),
      body: Column(
        children: [
          // 地圖
          Expanded(
            child: _buildMap(),
          ),
          // 底部信息面板
          _buildBottomPanel(),
        ],
      ),
    );
  }

  Widget _buildMap() {
    if (_directions == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final pickupLat = _tripData!['pickup_lat'] as double;
    final pickupLng = _tripData!['pickup_lng'] as double;
    final dropoffLat = _tripData!['dropoff_lat'] as double;
    final dropoffLng = _tripData!['dropoff_lng'] as double;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(pickupLat, pickupLng),
        initialZoom: 14,
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}@2x?access_token=pk.eyJ1IjoiaHkxaWlpIiwiYSI6ImNtZW4wcHdraDB3a3Mya3Nlc29mNGY3ZHAifQ.c1EtA8uDOpR7Q2-uPVJSaA',
          userAgentPackageName: 'com.autodrive.driver',
        ),
        // 路線
        PolylineLayer(
          polylines: [
            Polyline(
              points: _directions!.polylinePoints,
              color: Colors.blue,
              strokeWidth: 4,
            ),
          ],
        ),
        // 標記
        MarkerLayer(
          markers: [
            // 起點
            Marker(
              point: LatLng(pickupLat, pickupLng),
              width: 40,
              height: 40,
              child: const Icon(
                Icons.location_on,
                color: Colors.green,
                size: 40,
              ),
            ),
            // 終點
            Marker(
              point: LatLng(dropoffLat, dropoffLng),
              width: 40,
              height: 40,
              child: const Icon(
                Icons.flag,
                color: Colors.red,
                size: 40,
              ),
            ),
            // 當前位置（車輛）
            if (_currentPosition != null)
              Marker(
                point: _currentPosition!,
                width: 50,
                height: 50,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.directions_car,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 行程信息
          _buildTripInfo(),
          const SizedBox(height: 16),
          // 狀態按鈕
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildTripInfo() {
    final hasEscrow = _tripData?['escrow_object_id'] != null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 狀態
        Row(
          children: [
            const Text(
              '當前狀態：',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getStatusText(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 支付狀態
        Row(
          children: [
            const Text(
              '支付狀態：',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: hasEscrow ? Colors.green : Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                hasEscrow ? '✅ 已支付' : '⏳ 待支付',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 地址
        Row(
          children: [
            const Icon(Icons.location_on, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _tripData?['pickup_address'] ?? '未知',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.flag, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _tripData?['dropoff_address'] ?? '未知',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
        if (_directions != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.straighten, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                '距離：${_directions!.distanceText}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.access_time, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                '時間：${_directions!.durationText}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton() {
    if (_isLoading) {
      return const CircularProgressIndicator();
    }

    final hasEscrow = _tripData?['escrow_object_id'] != null;
    String buttonText;
    VoidCallback? onPressed;
    Color buttonColor;

    switch (_status) {
      case 'accepted':
        buttonText = '已接到乘客，開始行程';
        onPressed = () => _updateTripStatus('picked_up');
        buttonColor = Colors.blue;
        break;
      case 'picked_up':
        if (hasEscrow) {
          buttonText = '完成行程並收款';
          onPressed = _completeTrip;
          buttonColor = Colors.green;
        } else {
          buttonText = '等待乘客支付';
          onPressed = null;
          buttonColor = Colors.grey;
        }
        break;
      case 'in_progress':
        if (hasEscrow) {
          buttonText = '完成行程並收款';
          onPressed = _completeTrip;
          buttonColor = Colors.green;
        } else {
          buttonText = '等待乘客支付';
          onPressed = null;
          buttonColor = Colors.grey;
        }
        break;
      default:
        buttonText = '未知狀態';
        onPressed = null;
        buttonColor = Colors.grey;
    }

    return Column(
      children: [
        if (!hasEscrow && (_status == 'picked_up' || _status == 'in_progress'))
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '請提醒乘客完成支付後才能完成行程',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade700,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              buttonText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    switch (_status) {
      case 'accepted':
        return Colors.orange;
      case 'picked_up':
        return Colors.blue;
      case 'in_progress':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText() {
    switch (_status) {
      case 'accepted':
        return '等待接送';
      case 'picked_up':
        return '行程進行中';
      case 'in_progress':
        return '行程進行中';
      case 'completed':
        return '已完成';
      default:
        return '未知';
    }
  }
}
