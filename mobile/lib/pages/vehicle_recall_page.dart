import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../session_manager.dart';

/// 車輛召回頁面
class VehicleRecallPage extends StatefulWidget {
  const VehicleRecallPage({super.key, required this.session});

  final UserSession session;

  @override
  State<VehicleRecallPage> createState() => _VehicleRecallPageState();
}

class _VehicleRecallPageState extends State<VehicleRecallPage> {
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _vehicles = [];
  Map<String, dynamic>? _selectedVehicle;
  LatLng? _targetLocation;
  bool _isLoading = false;
  String? _statusMessage;
  Timer? _pollTimer;
  Timer? _animationTimer;

  // 召回中的車輛狀態
  Map<String, Map<String, dynamic>> _recallStatus = {};

  // 車輛動畫位置（用於平滑移動）
  // vehicle_id -> {'current': LatLng, 'target': LatLng, 'steps': int}
  Map<String, Map<String, dynamic>> _vehicleAnimationStates = {};

  @override
  void initState() {
    super.initState();
    _loadRecallableVehicles();
    _initializeWebSocket(); // 保留但暫時無法連接
    _startAnimationTimer();
    _startPolling(); // 🔄 臨時使用輪詢直到 WebSocket 修復
  }

  /// 啟動動畫計時器（每100ms更新一次位置）
  void _startAnimationTimer() {
    _animationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;

      bool needsUpdate = false;

      // 更新所有車輛的動畫位置
      _vehicleAnimationStates.forEach((vehicleId, state) {
        final current = state['current'] as LatLng;
        final target = state['target'] as LatLng;
        int steps = state['steps'] as int;

        if (steps > 0) {
          // 還有剩餘步數，繼續移動
          final newLat = current.latitude + (target.latitude - current.latitude) / steps;
          final newLng = current.longitude + (target.longitude - current.longitude) / steps;

          state['current'] = LatLng(newLat, newLng);
          state['steps'] = steps - 1;
          needsUpdate = true;

          // 更新 _vehicles 列表中的顯示位置
          for (var i = 0; i < _vehicles.length; i++) {
            if (_vehicles[i]['vehicle_id'] == vehicleId) {
              _vehicles[i]['display_lat'] = newLat;
              _vehicles[i]['display_lng'] = newLng;
              break;
            }
          }
        } else if (current.latitude != target.latitude || current.longitude != target.longitude) {
          // 步數用完，直接跳到目標位置
          state['current'] = target;
          needsUpdate = true;

          for (var i = 0; i < _vehicles.length; i++) {
            if (_vehicles[i]['vehicle_id'] == vehicleId) {
              _vehicles[i]['display_lat'] = target.latitude;
              _vehicles[i]['display_lng'] = target.longitude;
              break;
            }
          }
        }
      });

      if (needsUpdate) {
        setState(() {});
      }
    });
  }

  /// 初始化 WebSocket 監聽車輛位置更新
  Future<void> _initializeWebSocket() async {
    final ws = WebSocketService();

    print('🔌 [召回頁面] 開始設置 WebSocket 監聽器');
    print('🔌 [召回頁面] 注意：不需要重新連接或加入房間');
    print('🔌 [召回頁面] 司機頁面已經連接並加入了 drivers_online 房間');

    // 監聽車輛位置更新
    ws.on('vehicle_location_update', (data) {
      print('📍📍📍 [DEBUG] 收到車輛位置更新: $data');
      print('📍 [DEBUG] mounted = $mounted');
      if (!mounted) return;

      // 更新車輛位置（使用平滑動畫）
      final vehicleId = data['vehicle_id'] as String?;
      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();

      print('📍 [DEBUG] vehicleId=$vehicleId, lat=$lat, lng=$lng');
      print('📍 [DEBUG] _vehicles.length=${_vehicles.length}');

      if (vehicleId != null && lat != null && lng != null) {
        setState(() {
          // 更新車輛列表中的實際位置
          for (var i = 0; i < _vehicles.length; i++) {
            if (_vehicles[i]['vehicle_id'] == vehicleId) {
              print('📍 [DEBUG] 找到匹配車輛，索引=$i');

              _vehicles[i]['current_lat'] = lat;
              _vehicles[i]['current_lng'] = lng;
              _vehicles[i]['display_lat'] = lat;
              _vehicles[i]['display_lng'] = lng;

              print('📍 [DEBUG] 車輛位置已更新到 ($lat, $lng)');
              break;
            }
          }
        });
      }
    });

    // 監聽車輛召回完成
    ws.on('vehicle_recall_completed', (data) {
      print('✅ 收到車輛召回完成通知: $data');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('車輛 ${data['vehicle_id']} 已到達目標位置'),
          backgroundColor: Colors.green,
        ),
      );

      // 刷新車輛列表
      _loadRecallableVehicles();
    });

    print('✅ 車輛召回頁面 WebSocket 監聽已設置');
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _animationTimer?.cancel();
    _mapController.dispose();

    // 清理 WebSocket 監聽器
    final ws = WebSocketService();
    ws.off('vehicle_location_update');
    ws.off('vehicle_recall_completed');

    super.dispose();
  }

  /// 🔄 啟動輪詢（臨時方案，直到 WebSocket 修復）
  /// 每 2 秒更新一次車輛位置
  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!mounted) return;

      // 只在有召回中的車輛時才輪詢
      bool hasRecallingVehicle = _vehicles.any((v) => v['is_recalling'] == true);
      if (!hasRecallingVehicle) return;

      try {
        final response = await ApiService.get('/vehicles/recall/available');

        if (response['success'] == true && response['data'] != null) {
          final updatedVehicles = List<Map<String, dynamic>>.from(
            response['data']['vehicles'] ?? [],
          );

          // 更新每一輛車的位置
          for (var updatedVehicle in updatedVehicles) {
            final vehicleId = updatedVehicle['vehicle_id'];

            // 找到對應的車輛
            for (var i = 0; i < _vehicles.length; i++) {
              if (_vehicles[i]['vehicle_id'] == vehicleId) {
                final newLat = updatedVehicle['current_lat']?.toDouble();
                final newLng = updatedVehicle['current_lng']?.toDouble();

                if (newLat != null && newLng != null) {
                  // 更新目標位置，讓動畫計時器自動處理平滑移動
                  if (!_vehicleAnimationStates.containsKey(vehicleId)) {
                    _vehicleAnimationStates[vehicleId] = {
                      'current': LatLng(
                        _vehicles[i]['current_lat']?.toDouble() ?? newLat,
                        _vehicles[i]['current_lng']?.toDouble() ?? newLng,
                      ),
                      'target': LatLng(newLat, newLng),
                      'steps': 20, // 2秒內完成移動 (20 * 100ms)
                    };
                  } else {
                    // 更新目標位置
                    _vehicleAnimationStates[vehicleId]!['target'] = LatLng(newLat, newLng);
                    _vehicleAnimationStates[vehicleId]!['steps'] = 20;
                  }

                  // 更新實際位置（後端數據）
                  _vehicles[i]['current_lat'] = newLat;
                  _vehicles[i]['current_lng'] = newLng;

                  // 更新召回狀態
                  _vehicles[i]['is_recalling'] = updatedVehicle['is_recalling'];
                }
                break;
              }
            }
          }
        }
      } catch (e) {
        print('❌ 輪詢更新失敗: $e');
      }
    });

    print('🔄 [召回頁面] 已啟動輪詢（每 2 秒）');
  }

  /// 加載可召回的車輛
  Future<void> _loadRecallableVehicles() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '正在加載車輛列表...';
    });

    try {
      final response = await ApiService.get('/vehicles/recall/available');

      print('🔍 召回API響應: $response');
      print('📊 success = ${response['success']}');
      print('📋 data = ${response['data']}');
      print('📋 vehicles = ${response['data']?['vehicles']}');

      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _vehicles = List<Map<String, dynamic>>.from(
            response['data']['vehicles'] ?? [],
          );
          print('✅ 解析後車輛數量: ${_vehicles.length}');
          if (_vehicles.isNotEmpty) {
            print('🚗 第一輛車: ${_vehicles.first}');
          }

          // 檢查是否有召回中的車輛，恢復狀態
          for (var vehicle in _vehicles) {
            if (vehicle['is_recalling'] == true) {
              print('🔄 發現召回中的車輛: ${vehicle['vehicle_id']}');
              // 如果有目標位置，恢復目標標記
              if (vehicle['recall_target_lat'] != null &&
                  vehicle['recall_target_lng'] != null) {
                _targetLocation = LatLng(
                  vehicle['recall_target_lat'].toDouble(),
                  vehicle['recall_target_lng'].toDouble(),
                );
                _selectedVehicle = vehicle;
                print('✅ 已恢復召回狀態');
              }
            }
          }

          _statusMessage = _vehicles.isEmpty ? '沒有可召回的車輛' : null;

          // 如果有車輛，移動地圖到第一輛車（或召回中的車）
          if (_vehicles.isNotEmpty) {
            final vehicle = _selectedVehicle ?? _vehicles.first;
            final lat = vehicle['current_lat']?.toDouble();
            final lng = vehicle['current_lng']?.toDouble();
            if (lat != null && lng != null) {
              try {
                _mapController.move(LatLng(lat, lng), 13);
              } catch (e) {
                print('⚠️ 地圖移動錯誤: $e');
              }
            }
          }
        });
      } else {
        setState(() {
          _statusMessage = '加載失敗: ${response['message'] ?? '未知錯誤'}';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '加載失敗: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 刷新召回狀態
  Future<void> _refreshRecallStatus() async {
    // 重新加載車輛列表以獲取最新位置
    try {
      final response = await ApiService.get('/vehicles/recall/available');

      if (response['success'] == true && response['data'] != null && mounted) {
        final updatedVehicles = List<Map<String, dynamic>>.from(
          response['data']['vehicles'] ?? [],
        );

        setState(() {
          // 更新車輛列表（包含最新位置）
          _vehicles = updatedVehicles;

          // 如果有選中的車輛，更新其位置
          if (_selectedVehicle != null) {
            final selectedId = _selectedVehicle!['vehicle_id'];
            _selectedVehicle = updatedVehicles.firstWhere(
              (v) => v['vehicle_id'] == selectedId,
              orElse: () => _selectedVehicle!,
            );
          }
        });

        print('🔄 已更新車輛位置，共 ${_vehicles.length} 輛車');
      }
    } catch (e) {
      print('⚠️ 刷新車輛狀態失敗: $e');
    }
  }

  /// 開始召回車輛
  Future<void> _startRecall() async {
    if (_selectedVehicle == null || _targetLocation == null) {
      setState(() {
        _statusMessage = '請選擇車輛和目標位置';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '正在啟動召回...';
    });

    try {
      final response = await ApiService.post('/vehicles/recall/start', {
        'vehicle_id': _selectedVehicle!['vehicle_id'],
        'target_lat': _targetLocation!.latitude,
        'target_lng': _targetLocation!.longitude,
      });

      if (response['success'] == true) {
        final data = response['data']['data'] ?? response['data'];
        print('📦 召回響應數據: $data');

        setState(() {
          _statusMessage = data['message'] ?? '召回已開始';
        });

        // 重新加載車輛列表
        await _loadRecallableVehicles();

        // 顯示成功對話框
        if (mounted && data['eta_minutes'] != null && data['distance_km'] != null) {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E1E),
                  title: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF1DB954)),
                      SizedBox(width: 8),
                      Text('召回已啟動', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  content: Text(
                    '車輛將在約 ${data['eta_minutes']} 分鐘後到達\n'
                    '距離: ${data['distance_km']} km',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('確定'),
                    ),
                  ],
                ),
          );
        }
      } else {
        setState(() {
          _statusMessage = '召回失敗: ${response['message'] ?? '未知錯誤'}';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '召回失敗: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 取消召回
  Future<void> _cancelRecall(String vehicleId) async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.post('/vehicles/recall/cancel', {
        'vehicle_id': vehicleId,
      });

      if (response['success'] == true) {
        setState(() {
          _statusMessage = '召回已取消';
          _recallStatus.remove(vehicleId);
        });

        await _loadRecallableVehicles();
      } else {
        setState(() {
          _statusMessage = '取消失敗: ${response['message'] ?? '未知錯誤'}';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '取消失敗: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('車輛召回'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecallableVehicles,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 地圖
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(25.0340, 121.5620),
              initialZoom: 13,
              onTap: (_, latlng) {
                setState(() {
                  _targetLocation = latlng;
                  _statusMessage = '目標位置已設定';
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}@2x?access_token=pk.eyJ1IjoiaHkxaWlpIiwiYSI6ImNtZW4wcHdraDB3a3Mya3Nlc29mNGY3ZHAifQ.c1EtA8uDOpR7Q2-uPVJSaA',
                userAgentPackageName: 'com.autodrive.app',
              ),
              // 車輛標記
              MarkerLayer(
                markers:
                    _vehicles
                        .map((vehicle) {
                          // 優先使用動畫位置，否則使用實際位置
                          final lat = (vehicle['display_lat'] ?? vehicle['current_lat'])?.toDouble();
                          final lng = (vehicle['display_lng'] ?? vehicle['current_lng'])?.toDouble();
                          if (lat == null || lng == null) return null;

                          final isSelected =
                              _selectedVehicle?['vehicle_id'] ==
                              vehicle['vehicle_id'];
                          final isRecalling = vehicle['is_recalling'] == true;

                          return Marker(
                            point: LatLng(lat, lng),
                            width: 60,
                            height: 60,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedVehicle = vehicle;
                                  _statusMessage =
                                      '已選擇車輛: ${vehicle['license_plate']}';
                                });
                              },
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.directions_car,
                                    color:
                                        isRecalling
                                            ? Colors.orange
                                            : (isSelected
                                                ? const Color(0xFF1DB954)
                                                : Colors.blue),
                                    size: isSelected ? 36 : 30,
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      vehicle['license_plate'] ?? '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        })
                        .whereType<Marker>()
                        .toList(),
              ),
              // 目標位置標記
              if (_targetLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _targetLocation!,
                      width: 80,
                      height: 80,
                      child: Column(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '目的地',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // 頂部狀態消息
          if (_statusMessage != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusMessage!,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // 底部車輛列表
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 拖動條
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // 標題
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      '可召回車輛',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // 車輛列表
                  Flexible(
                    child:
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _vehicles.isEmpty
                            ? const Center(
                              child: Text(
                                '沒有可召回的車輛',
                                style: TextStyle(color: Colors.white54),
                              ),
                            )
                            : ListView.builder(
                              shrinkWrap: true,
                              itemCount: _vehicles.length,
                              itemBuilder: (context, index) {
                                final vehicle = _vehicles[index];
                                final isSelected =
                                    _selectedVehicle?['vehicle_id'] ==
                                    vehicle['vehicle_id'];
                                final isRecalling =
                                    vehicle['is_recalling'] == true;

                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected
                                            ? const Color(
                                              0xFF1DB954,
                                            ).withValues(alpha: 0.2)
                                            : Colors.white10,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          isSelected
                                              ? const Color(0xFF1DB954)
                                              : Colors.transparent,
                                    ),
                                  ),
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.directions_car,
                                      color:
                                          isRecalling
                                              ? Colors.orange
                                              : Colors.blue,
                                    ),
                                    title: Text(
                                      vehicle['license_plate'] ?? '未知車牌',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${vehicle['vehicle_type']} • ${vehicle['status']}',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                      ),
                                    ),
                                    trailing:
                                        isRecalling
                                            ? IconButton(
                                              icon: const Icon(
                                                Icons.cancel,
                                                color: Colors.orange,
                                              ),
                                              onPressed:
                                                  () => _cancelRecall(
                                                    vehicle['vehicle_id'],
                                                  ),
                                            )
                                            : null,
                                    onTap: () {
                                      setState(() {
                                        _selectedVehicle = vehicle;
                                        _statusMessage =
                                            '已選擇車輛: ${vehicle['license_plate']}';

                                        // 移動地圖到車輛位置
                                        final lat =
                                            vehicle['current_lat']?.toDouble();
                                        final lng =
                                            vehicle['current_lng']?.toDouble();
                                        if (lat != null && lng != null) {
                                          try {
                                            _mapController.move(
                                              LatLng(lat, lng),
                                              15,
                                            );
                                          } catch (e) {
                                            print('⚠️ 地圖移動錯誤: $e');
                                          }
                                        }
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                  ),

                  // 召回按鈕
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            (_selectedVehicle != null &&
                                    _targetLocation != null &&
                                    !_isLoading)
                                ? _startRecall
                                : null,
                        icon: const Icon(Icons.location_searching),
                        label: const Text('開始召回'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1DB954),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
