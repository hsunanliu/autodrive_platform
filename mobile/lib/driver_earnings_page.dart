import 'package:flutter/material.dart';

import 'services/api_service.dart';
import 'services/price_service.dart';
import 'session_manager.dart';

class DriverEarningsPage extends StatefulWidget {
  const DriverEarningsPage({super.key, required this.session});

  final UserSession? session;

  @override
  State<DriverEarningsPage> createState() => _DriverEarningsPageState();
}

class _DriverEarningsPageState extends State<DriverEarningsPage> {
  bool _isLoading = true;
  double _totalEarnings = 0;
  List<Map<String, dynamic>> _vehicles = const [];
  String? _error;

  UserSession? get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_session == null) {
      setState(() {
        _isLoading = false;
        _error = '帳戶尚未登入';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await ApiService.getMyVehicles();
    if (!mounted) return;

    if (result['success'] == true && result['data'] is List) {
      final vehicles = (result['data'] as List)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);

      // 計算總收益（micro SUI → SUI）
      double totalMicroIota = 0;
      for (final v in vehicles) {
        final value = v['total_earnings_micro_sui'];
        if (value is num) {
          totalMicroIota += value.toDouble();
        } else if (value is String) {
          totalMicroIota += double.tryParse(value) ?? 0;
        }
      }

      setState(() {
        _vehicles = vehicles;
        _totalEarnings = totalMicroIota / 1000000; // micro SUI -> SUI (1 SUI = 1,000,000 micro SUI)
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
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('收益明細'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954)));
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF1DB954),
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('總收益',
                    style: TextStyle(color: Colors.white70, fontSize: 16)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${_totalEarnings.toStringAsFixed(2)} SUI',
                        style: const TextStyle(
                          color: Color(0xFF1DB954),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        )),
                    FutureBuilder<double?>(
                      future: PriceService.convertSuiToUsd(_totalEarnings),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          return Text(
                            '≈ \$${snapshot.data!.toStringAsFixed(2)} USD',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('車輛收益',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_vehicles.isEmpty)
            const Text('目前沒有車輛收益紀錄',
                style: TextStyle(color: Colors.white54))
          else
            ..._vehicles.map((vehicle) => _VehicleEarningTile(vehicle: vehicle)),
        ],
      ),
    );
  }
}

class _VehicleEarningTile extends StatelessWidget {
  const _VehicleEarningTile({required this.vehicle});

  final Map<String, dynamic> vehicle;

  @override
  Widget build(BuildContext context) {
    final model = vehicle['model']?.toString() ?? '未命名車輛';
    final plate = vehicle['plate_number']?.toString() ?? '未設定';
    final earnings = vehicle['total_earnings_micro_sui'];

    // 統一處理：先轉換為數字（micro SUI），再除以 1000000 轉換為 SUI
    double earningsMicroIota = 0;
    if (earnings is num) {
      earningsMicroIota = earnings.toDouble();
    } else if (earnings is String) {
      earningsMicroIota = double.tryParse(earnings) ?? 0;
    }
    final earningsSui = earningsMicroIota / 1000000; // micro SUI -> SUI (1 SUI = 1,000,000 micro SUI)

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(model,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(plate, style: const TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${earningsSui.toStringAsFixed(2)} SUI',
                  style: const TextStyle(color: Color(0xFF1DB954), fontWeight: FontWeight.bold)),
              FutureBuilder<double?>(
                future: PriceService.convertSuiToUsd(earningsSui),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return Text(
                      '≈ \$${snapshot.data!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
