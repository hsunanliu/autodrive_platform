// mobile/lib/pages/trip_in_progress_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import '../services/google_directions_service.dart';
import '../services/websocket_service.dart';
import '../services/trip_simulation_service.dart';
import '../services/map_http_client.dart';
import '../services/zklogin_action_service.dart';
import '../session_manager.dart';
import '../theme/app_theme.dart';

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
  final WebSocketService _ws = WebSocketService();
  final TripSimulationService _simulationService = TripSimulationService();

  Map<String, dynamic>? _tripData;
  DirectionsResult? _directions;
  LatLng? _currentPosition;

  bool _isLoading = true;
  String _status = 'accepted'; // accepted, picked_up, in_progress, completed
  Timer? _pollTimer;
  int _currentPointIndex = 0;

  // 分離的狀態管理
  bool _hasReachedDestination = false;  // 是否到達目的地
  bool _paymentCompleted = false;  // 支付是否完成
  bool _isCancelling = false;      // 是否正在取消行程（防止雙重 pop）

  @override
  void initState() {
    super.initState();
    _loadTripData();
    _setupWebSocket(); // WebSocket 設置中會處理加入房間

    // 如果有正在進行的模擬，在載入完成後嘗試恢復
    if (_simulationService.isSimulatingTrip(widget.tripId)) {
      print('♻️ 檢測到現有模擬，將在載入路線後恢復');
    }
  }

  @override
  void dispose() {
    // 暫停模擬（不清除狀態，以便恢復）
    _simulationService.pauseSimulation();

    // 停止輪詢計時器
    _pollTimer?.cancel();
    _pollTimer = null;

    // 清理 WebSocket 監聽器
    _ws.off('joined_trip');
    _ws.off('connection_status');
    _ws.off('trip_started');
    _ws.off('payment_completed');
    _ws.off('trip_completed');
    _ws.off('trip_cancelled');

    // 釋放 MapController
    _mapController.dispose();

    super.dispose();
    print('🗑️ TripInProgressPage disposed (模擬已暫停)');
  }

  /// 設置 WebSocket 監聽支付完成事件
  void _setupWebSocket() async {
    bool _hasJoinedRoom = false; // 標記是否已成功加入房間

    // 先連接 WebSocket
    print('🔌 車主端：正在連接 WebSocket...');
    await _ws.connect();
    print('🔌 車主端：WebSocket 連接已初始化，isConnected=${_ws.isConnected}');

    // 監聽加入房間確認
    _ws.on('joined_trip', (data) {
      print('✅ 成功加入行程房間: $data');
      _hasJoinedRoom = true;
    });

    // 定義加入房間的方法（帶重試機制）
    void attemptJoinRoom({int attempt = 0}) {
      if (_hasJoinedRoom || attempt > 10) {
        if (attempt > 10) {
          print('❌ 嘗試加入房間失敗，已重試10次');
        }
        return;
      }

      Future.delayed(Duration(milliseconds: 500 * (attempt + 1)), () {
        if (!mounted || _hasJoinedRoom) return;

        print('🔄 嘗試加入行程房間 (第${attempt + 1}次): trip_id=${widget.tripId}, isConnected=${_ws.isConnected}');
        if (_ws.isConnected) {
          _ws.joinTrip(widget.tripId);
          print('📤 已發送 join_trip 請求');

          // 1秒後檢查是否成功，沒成功就重試
          Future.delayed(const Duration(seconds: 1), () {
            if (!_hasJoinedRoom && mounted) {
              attemptJoinRoom(attempt: attempt + 1);
            }
          });
        } else {
          // WebSocket 未連接，繼續重試
          attemptJoinRoom(attempt: attempt + 1);
        }
      });
    }

    // 監聽連接狀態 - 連接成功後嘗試加入房間
    _ws.on('connection_status', (data) {
      print('📡 收到連接狀態變化: $data');
      if (data['connected'] == true && !_hasJoinedRoom) {
        print('📡 WebSocket 已連接，嘗試加入行程 ${widget.tripId} 的房間');
        attemptJoinRoom();
      }
    });

    // 立即開始嘗試加入房間
    print('🚀 開始嘗試加入 WebSocket 房間: trip_id=${widget.tripId}');
    attemptJoinRoom();

    // 監聽行程開始（乘客上車）
    _ws.on('trip_started', (data) {
      print('📨 收到行程開始通知: $data');
      if (mounted) {
        // 啟動模擬行程
        _startSimulation();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚗 乘客已上車，行程開始！'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });

    // 監聽支付完成 - 只更新支付狀態，不影響模擬
    _ws.on('payment_completed', (data) {
      print('📨 收到支付完成通知: $data');
      if (mounted) {
        setState(() {
          _paymentCompleted = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 乘客已完成支付'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });

    // 監聽行程完成
    _ws.on('trip_completed', (data) {
      print('📨 收到行程完成通知: $data');
      if (mounted) {
        setState(() {
          _status = 'completed';
        });
        // 停止模擬
        _simulationService.stopSimulation();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 行程已完成！'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });

    // 監聽行程取消
    _ws.on('trip_cancelled', (data) {
      print('📨 收到行程取消通知: $data');
      if (mounted && !_isCancelling) {
        // 只有在不是自己主動取消時才處理（避免雙重 pop）
        _simulationService.stopSimulation(); // 停止並清除模擬

        final cancelledBy = data['cancelled_by'] ?? 'unknown';
        final reason = data['reason'] ?? '未提供原因';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              cancelledBy == 'passenger'
                  ? '❌ 乘客取消了行程\n原因：$reason'
                  : '✓ 行程已取消',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );

        Navigator.pop(context); // 返回上一頁
      }
    });
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

      final newStatus = trip['status'] ?? 'accepted';
      final shouldReloadDirections = _tripData == null; // 只在第一次載入時獲取路線

      setState(() {
        _tripData = trip;
        _status = newStatus;
      });

      // 只在第一次載入時獲取路線，避免重複呼叫 Google API
      if (shouldReloadDirections) {
        print('📍 首次載入，獲取導航路線...');
        await _loadDirections();
      } else {
        print('♻️ 更新行程狀態，跳過路線重載');
      }

      // 如果行程已經是 picked_up 或 in_progress 狀態，但模擬還沒開始，自動啟動模擬
      if ((newStatus == 'picked_up' || newStatus == 'in_progress') &&
          !_simulationService.isRunning) {
        print('🚗 檢測到行程已開始（狀態: $newStatus），自動啟動模擬...');
        _startSimulation();
      }
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

    print('🗺️ 正在從後端獲取路線...');

    try {
      // 使用後端 API 獲取路線（支持多停靠點）
      final result = await ApiService.getTripRoute(widget.tripId);

      if (!mounted) return;

      // 提取實際數據（被 _wrapResponse 包裝過）
      final data = result['data'] as Map<String, dynamic>?;

      if (result['success'] == true && data != null && data['route_points'] != null) {
        final routePointsData = data['route_points'] as List;
        final routePoints = routePointsData
            .map((p) => LatLng(p['lat'] as double, p['lng'] as double))
            .toList();

        print('✅ 路線獲取成功: ${routePoints.length} 個路線點');

        // 獲取停靠點資訊（如果有）
        final waypointsData = data['waypoints'] as List?;
        if (waypointsData != null && waypointsData.isNotEmpty) {
          print('📍 包含 ${waypointsData.length} 個停靠點');
        }

        // 創建 DirectionsResult 對象（保持與現有模擬服務的兼容性）
        final distanceMeters = (data['distance_meters'] ?? 0).toDouble();
        final durationSeconds = (data['duration_seconds'] ?? 0).toInt();

        // 格式化距離和時間文字
        final distanceKm = distanceMeters / 1000;
        final distanceText = '${distanceKm.toStringAsFixed(1)} 公里';
        final durationMinutes = (durationSeconds / 60).round();
        final durationText = '$durationMinutes 分鐘';

        final mockDirections = DirectionsResult(
          polylinePoints: routePoints,
          distanceMeters: distanceMeters,
          durationSeconds: durationSeconds,
          distanceText: distanceText,
          durationText: durationText,
        );

        setState(() {
          _directions = mockDirections;
          _currentPosition = routePoints.first;
        });

        // 等待下一幀再移動地圖（確保 MapController 已初始化）
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            try {
              _mapController.move(origin, 14);
            } catch (e) {
              print('⚠️ 移動地圖失敗: $e');
            }

            // 如果已有此行程的模擬正在進行，自動恢復
            if (_simulationService.isSimulatingTrip(widget.tripId)) {
              print('♻️ 自動恢復行程模擬');
              _resumeSimulation();
            }
          }
        });
      } else {
        throw Exception(result['error'] ?? '未知錯誤');
      }
    } catch (e) {
      print('❌ 路線獲取失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('無法獲取路線: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  /// 開始位置模擬（視覺層 - 使用全局服務）
  void _startSimulation() {
    if (_directions == null) return;

    final points = _directions!.polylinePoints;
    final totalPoints = points.length;
    final durationSeconds = _directions!.durationSeconds;

    // 🚀 加速模擬：設定速度倍數
    const speedMultiplier = 1.5; // 1.5倍速
    int intervalMs = (durationSeconds * 1000 / totalPoints / speedMultiplier).round();
    intervalMs = intervalMs.clamp(200, 1000); // 限制在 200-1000ms 之間，更自然的速度

    // 檢查是否已有此行程的模擬在運行
    if (_simulationService.isSimulatingTrip(widget.tripId)) {
      print('♻️ 行程模擬已在運行，嘗試恢復...');
      _resumeSimulation();
      return;
    }

    setState(() {
      _hasReachedDestination = false;
    });

    print('🚗 開始位置模擬 (${totalPoints} 個點, 間隔 ${intervalMs}ms, ${speedMultiplier}x 速度)');

    _simulationService.startSimulation(
      tripId: widget.tripId,
      routePoints: points,
      intervalMs: intervalMs,
      onPositionUpdate: (position, index) {
        if (!mounted) return;

        setState(() {
          _currentPointIndex = index;
          _currentPosition = position;
        });

        // 移動地圖跟隨車輛
        try {
          _mapController.move(position, _mapController.camera.zoom);
        } catch (e) {
          // 忽略地圖移動錯誤
          print('⚠️ 地圖移動錯誤: $e');
        }

        // 🔄 發送位置更新給乘客端（通過 WebSocket）
        _ws.emit('update_location', {
          'trip_id': widget.tripId,
          'lat': position.latitude,
          'lng': position.longitude,
        });
      },
      onDestinationReached: () {
        if (!mounted) return;

        setState(() {
          _hasReachedDestination = true;
        });

        print('🏁 已到達目的地，等待支付完成...');

        // 顯示通知
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _paymentCompleted
                ? '✅ 已到達目的地，支付已完成，可結束行程'
                : '⏳ 已到達目的地，等待乘客支付...'
            ),
            backgroundColor: _paymentCompleted ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      },
    );
  }

  /// 恢復位置模擬（從上次位置繼續）
  void _resumeSimulation() {
    _simulationService.resumeSimulation(
      tripId: widget.tripId,
      onPositionUpdate: (position, index) {
        if (!mounted) return;

        setState(() {
          _currentPointIndex = index;
          _currentPosition = position;
        });

        // 移動地圖跟隨車輛
        try {
          _mapController.move(position, _mapController.camera.zoom);
        } catch (e) {
          print('⚠️ 地圖移動錯誤: $e');
        }

        // 🔄 發送位置更新給乘客端（通過 WebSocket）
        _ws.emit('update_location', {
          'trip_id': widget.tripId,
          'lat': position.latitude,
          'lng': position.longitude,
        });
      },
      onDestinationReached: () {
        if (!mounted) return;

        setState(() {
          _hasReachedDestination = true;
        });

        print('🏁 已到達目的地');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _paymentCompleted
                ? '✅ 已到達目的地，支付已完成，可結束行程'
                : '⏳ 已到達目的地，等待乘客支付...'
            ),
            backgroundColor: _paymentCompleted ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
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
    } else if (newStatus == 'in_progress') {
      // 司機開始行程（picked_up → in_progress）
      result = await ApiService.startTrip(widget.tripId);
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

  /// 顯示取消行程對話框
  Future<void> _showCancelDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        String selectedReason = '臨時有事';
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text(
                '確定要取消行程嗎？',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '請選擇取消原因：',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  ...['臨時有事', '乘客要求取消', '路況問題', '車輛故障', '其他原因'].map((reason) {
                    return RadioListTile<String>(
                      value: reason,
                      groupValue: selectedReason,
                      title: Text(
                        reason,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      activeColor: const Color(0xFF1DB954),
                      onChanged: (value) {
                        setState(() {
                          selectedReason = value!;
                        });
                      },
                    );
                  }).toList(),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('返回'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, selectedReason),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('確定取消'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      await _cancelTrip(result);
    }
  }

  /// 取消行程
  Future<void> _cancelTrip(String reason) async {
    // 設置標記，防止 WebSocket 通知導致雙重 pop
    setState(() {
      _isLoading = true;
      _isCancelling = true;
    });

    final result = await ApiService.cancelTrip(
      tripId: widget.tripId,
      reason: reason,
      cancelledBy: 'driver',
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      _simulationService.stopSimulation(); // 停止並清除模擬
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ 行程已取消'),
          backgroundColor: Colors.orange,
        ),
      );
      // 返回上一頁
      if (mounted) {
        Navigator.of(context).pop();
      }
    } else {
      // 取消失敗，重置標記
      setState(() => _isCancelling = false);
      final errorMsg = result['error']?.toString() ?? '未知錯誤';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ 取消失敗: $errorMsg'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 完成行程（業務層 - 需要支付完成）
  Future<void> _completeTrip() async {
    // 檢查必要條件
    if (!_hasReachedDestination) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ 尚未到達目的地'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 檢查支付狀態：優先使用 escrow_object_id（與 UI 一致）
    final hasEscrow = _tripData?['escrow_object_id'] != null;
    if (!hasEscrow) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏳ 請等待乘客完成支付'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await ApiService.completeTrip(widget.tripId);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      _simulationService.stopSimulation(); // 確保停止並清除模擬
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 行程已完成！款項已轉給司機'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      // 返回司機主頁（只 pop 一次，回到 DriverHomePageNew）
      Navigator.of(context).pop();
    } else {
      final errorMsg = result['error']?.toString() ?? '未知錯誤';

      // 特殊處理支付相關錯誤
      String displayMsg;
      if (errorMsg.contains('尚未支付')) {
        displayMsg = '❌ 乘客尚未支付，無法完成行程';
        setState(() => _paymentCompleted = false); // 重置支付狀態
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

    return WillPopScope(
      onWillPop: () async {
        // 暫停模擬（不清除狀態）
        _simulationService.pauseSimulation();
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          title: Text('行程 #${widget.tripId}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              _simulationService.pauseSimulation(); // 暫停而非停止
              Navigator.pop(context);
            },
          ),
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
              'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}@2x?access_token=MAPBOX_TOKEN_REMOVED',
          userAgentPackageName: 'com.autodrive.driver',
          // 使用默認的 NetworkTileProvider，不傳遞 httpClient
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
            // 停靠點標記
            if (_tripData?['waypoints'] != null)
              ...((_tripData!['waypoints'] as List).map((waypoint) {
                final wpLat = waypoint['lat'] as double;
                final wpLng = waypoint['lng'] as double;
                final sequence = waypoint['sequence'] as int;

                return Marker(
                  point: LatLng(wpLat, wpLng),
                  width: 40,
                  height: 40,
                  child: Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$sequence',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.location_on,
                        color: Colors.orange,
                        size: 16,
                      ),
                    ],
                  ),
                );
              }).toList()),
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
                        color: Colors.blue.withValues(alpha: 0.5),
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
        // 狀態（含 disputed 凍結顯示，用設計系統 StatusPill）
        Row(
          children: [
            const Text(
              '當前狀態：',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(width: 8),
            StatusPill.trip(_status),
          ],
        ),
        const SizedBox(height: 8),
        // 支付狀態：優先用後端 payment_status enum，缺則以 escrow 是否存在回推
        Row(
          children: [
            const Text(
              '支付狀態：',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(width: 8),
            StatusPill.payment(
              (_tripData?['payment_status'] as String?) ??
                  (hasEscrow ? 'locked' : 'pending'),
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

  // Phase 6：回報爭議（zkLogin 簽 raise_dispute → 凍結 escrow → 回報 dispute 物件）
  Future<void> _raiseDispute() async {
    final escrowId = _tripData?['escrow_object_id'] as String?;
    if (escrowId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('此行程尚無託管付款，無法發起爭議')),
      );
      return;
    }
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('回報爭議'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('發起爭議會凍結此筆託管款項，待平台仲裁後才會放款/退款。'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(hintText: '請描述爭議原因（至少 5 字）'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('簽署並凍結')),
        ],
      ),
    );
    if (confirmed != true) return;
    final reason = reasonCtrl.text.trim();
    if (reason.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('爭議原因太短')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final res = await ZkLoginActionService.instance.raiseDispute(
      escrowObjectId: escrowId,
      reason: reason,
    );
    if (!mounted) return;

    if (res.success && res.objectId != null) {
      await ApiService.reportDisputeObject(tripId: widget.tripId, disputeObjectId: res.objectId!);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _status = 'disputed';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ 已發起爭議，款項已凍結，等待平台仲裁')),
      );
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('發起爭議失敗：${res.error}')),
      );
    }
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
        // 司機接單後自動開始行程，不需要手動確認
        // 乘客會自己操作上車
        buttonText = '等待乘客上車...';
        onPressed = null;
        buttonColor = Colors.grey;
        break;
      case 'picked_up':
        if (hasEscrow) {
          // 已上車且已付款 → 開始行程（進入 in_progress，讓該狀態真正被使用）
          buttonText = '開始行程';
          onPressed = () => _updateTripStatus('in_progress');
          buttonColor = const Color(0xFF1DB954);
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
      case 'disputed':
        // 爭議中：escrow 已凍結，任何結算動作停用，等 admin 仲裁
        buttonText = '爭議處理中（已凍結）';
        onPressed = null;
        buttonColor = AppColors.warning;
        break;
      case 'completed':
        buttonText = '行程已完成';
        onPressed = null;
        buttonColor = AppColors.success;
        break;
      case 'cancelled':
        buttonText = '行程已取消';
        onPressed = null;
        buttonColor = Colors.grey;
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
        // 取消行程按鈕（未完成/未取消/未爭議時才顯示；爭議中 escrow 已凍結不可取消）
        if (_status != 'completed' &&
            _status != 'cancelled' &&
            _status != 'disputed') ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showCancelDialog,
              icon: const Icon(Icons.cancel, size: 20),
              label: const Text('取消行程'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
        // Phase 6：回報爭議（已付款、尚未爭議/取消時可發起，凍結託管待仲裁）
        if (hasEscrow &&
            _status != 'disputed' &&
            _status != 'cancelled' &&
            (_status == 'picked_up' ||
                _status == 'in_progress' ||
                _status == 'completed')) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _raiseDispute,
              icon: const Icon(Icons.gavel, size: 20),
              label: const Text('回報爭議'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warning,
                side: const BorderSide(color: AppColors.warning),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

}
