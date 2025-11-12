// mobile/lib/services/trip_simulation_service.dart

import 'dart:async';
import 'package:latlong2/latlong.dart';

/// 行程模擬服務（單例模式）
///
/// 功能：
/// 1. 管理行程位置模擬的全局狀態
/// 2. 支持暫停/恢復模擬
/// 3. 在頁面切換時保持模擬狀態
class TripSimulationService {
  static final TripSimulationService _instance = TripSimulationService._internal();
  factory TripSimulationService() => _instance;
  TripSimulationService._internal();

  // 當前模擬的行程 ID
  int? _currentTripId;

  // 模擬狀態
  bool _isSimulating = false;
  int _currentPointIndex = 0;
  List<LatLng>? _routePoints;
  int _intervalMs = 1000;
  Timer? _simulationTimer;

  // 回調函數
  Function(LatLng position, int index)? _onPositionUpdate;
  Function()? _onDestinationReached;

  /// 開始新的行程模擬
  void startSimulation({
    required int tripId,
    required List<LatLng> routePoints,
    required int intervalMs,
    required Function(LatLng position, int index) onPositionUpdate,
    required Function() onDestinationReached,
  }) {
    // 如果已有模擬在運行，先停止
    if (_isSimulating) {
      stopSimulation();
    }

    _currentTripId = tripId;
    _routePoints = routePoints;
    _intervalMs = intervalMs;
    _onPositionUpdate = onPositionUpdate;
    _onDestinationReached = onDestinationReached;
    _currentPointIndex = 0;
    _isSimulating = true;

    print('🚗 TripSimulationService: 開始模擬行程 #$tripId (${routePoints.length} 個點)');

    _simulationTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      _onTimerTick,
    );
  }

  /// 恢復現有行程的模擬（從上次位置繼續）
  void resumeSimulation({
    required int tripId,
    required Function(LatLng position, int index) onPositionUpdate,
    required Function() onDestinationReached,
  }) {
    // 如果不是同一個行程，不恢復
    if (_currentTripId != tripId) {
      print('⚠️ TripSimulationService: 行程 ID 不匹配，無法恢復模擬');
      return;
    }

    // 如果已經在運行，不需要恢復
    if (_isSimulating && _simulationTimer != null) {
      print('♻️ TripSimulationService: 模擬已在運行中');
      // 只更新回調函數
      _onPositionUpdate = onPositionUpdate;
      _onDestinationReached = onDestinationReached;

      // 立即通知當前位置
      if (_routePoints != null && _currentPointIndex < _routePoints!.length) {
        _onPositionUpdate?.call(_routePoints![_currentPointIndex], _currentPointIndex);
      }
      return;
    }

    // 如果沒有路線數據，無法恢復
    if (_routePoints == null || _routePoints!.isEmpty) {
      print('❌ TripSimulationService: 沒有路線數據，無法恢復模擬');
      return;
    }

    // 如果已經到達終點，不恢復
    if (_currentPointIndex >= _routePoints!.length - 1) {
      print('🏁 TripSimulationService: 已到達終點，不恢復模擬');
      _onDestinationReached?.call();
      return;
    }

    _onPositionUpdate = onPositionUpdate;
    _onDestinationReached = onDestinationReached;
    _isSimulating = true;

    print('▶️ TripSimulationService: 恢復模擬行程 #$tripId (從第 $_currentPointIndex 個點繼續)');

    // 立即通知當前位置
    if (_currentPointIndex < _routePoints!.length) {
      _onPositionUpdate?.call(_routePoints![_currentPointIndex], _currentPointIndex);
    }

    _simulationTimer = Timer.periodic(
      Duration(milliseconds: _intervalMs),
      _onTimerTick,
    );
  }

  /// 暫停模擬（保留狀態，可稍後恢復）
  void pauseSimulation() {
    if (_simulationTimer != null) {
      _simulationTimer!.cancel();
      _simulationTimer = null;
      _isSimulating = false;
      print('⏸️ TripSimulationService: 暫停模擬（當前位置: $_currentPointIndex）');
    }
  }

  /// 停止模擬並清除狀態
  void stopSimulation() {
    if (_simulationTimer != null) {
      _simulationTimer!.cancel();
      _simulationTimer = null;
    }

    _isSimulating = false;
    _currentTripId = null;
    _currentPointIndex = 0;
    _routePoints = null;
    _onPositionUpdate = null;
    _onDestinationReached = null;

    print('⏹️ TripSimulationService: 停止模擬並清除狀態');
  }

  /// Timer 回調
  void _onTimerTick(Timer timer) {
    if (_routePoints == null || _routePoints!.isEmpty) {
      timer.cancel();
      return;
    }

    if (_currentPointIndex >= _routePoints!.length - 1) {
      // 到達終點
      timer.cancel();
      _simulationTimer = null;
      _isSimulating = false;
      print('🏁 TripSimulationService: 到達目的地');
      _onDestinationReached?.call();
      return;
    }

    // 更新位置
    _currentPointIndex++;
    final currentPosition = _routePoints![_currentPointIndex];
    _onPositionUpdate?.call(currentPosition, _currentPointIndex);
  }

  /// 檢查是否有行程正在模擬
  bool isSimulatingTrip(int tripId) {
    return _currentTripId == tripId;
  }

  /// 檢查是否有任何行程正在模擬
  bool get hasActiveSimulation => _currentTripId != null;

  /// 獲取當前模擬的行程 ID
  int? get currentTripId => _currentTripId;

  /// 獲取當前位置索引
  int get currentPointIndex => _currentPointIndex;

  /// 檢查是否正在運行
  bool get isRunning => _isSimulating && _simulationTimer != null;
}
