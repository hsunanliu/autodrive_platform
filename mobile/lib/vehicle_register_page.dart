import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'constants.dart';
import 'services/api_service.dart';
import 'session_manager.dart';

class RegisterVehiclePage extends StatefulWidget {
  const RegisterVehiclePage({super.key, required this.session});

  final UserSession? session;

  @override
  State<RegisterVehiclePage> createState() => _RegisterVehiclePageState();
}

class _RegisterVehiclePageState extends State<RegisterVehiclePage> {
  final _vehicleIdController = TextEditingController(text: 'V');
  final _modelController = TextEditingController();
  final _plateController = TextEditingController();
  final _batteryCapacityController = TextEditingController();
  final _chargeController = TextEditingController(text: '80');
  final _hourlyRateController = TextEditingController(text: '1000000');
  final MapController _mapController = MapController();

  final List<String> _vehicleTypes = const ['sedan', 'suv', 'minivan', 'luxury'];
  String _selectedType = 'sedan';
  LatLng _selectedLocation = const LatLng(25.0330, 121.5654);
  bool _isSubmitting = false;
  String? _message;

  UserSession? get _session => widget.session;

  @override
  void dispose() {
    _vehicleIdController.dispose();
    _modelController.dispose();
    _plateController.dispose();
    _batteryCapacityController.dispose();
    _chargeController.dispose();
    _hourlyRateController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_session == null || _isSubmitting) return;

    final vehicleId = _vehicleIdController.text.trim();
    final model = _modelController.text.trim();
    final plate = _plateController.text.trim();
    final charge = double.tryParse(_chargeController.text.trim());
    final hourlyRate = int.tryParse(_hourlyRateController.text.trim());
    final batteryCapacity = double.tryParse(_batteryCapacityController.text.trim());

    if (vehicleId.isEmpty || model.isEmpty || plate.isEmpty || charge == null || hourlyRate == null) {
      setState(() => _message = '請填寫必填欄位並確認格式');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _message = '提交註冊中...';
    });

    final result = await ApiService.registerVehicle(
      vehicleId: vehicleId,
      plateNumber: plate,
      model: model,
      vehicleType: _selectedType,
      currentChargePercent: charge,
      hourlyRate: hourlyRate,
      batteryCapacity: batteryCapacity,
      currentLat: _selectedLocation.latitude,
      currentLng: _selectedLocation.longitude,
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      setState(() => _message = '車輛註冊成功');
      Navigator.pop(context, true);
    } else {
      final error = result['data']?['detail'] ?? result['error'] ?? '註冊失敗';
      setState(() => _message = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/role_select'),
            child: const Text('請先登入'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('註冊新車輛'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(
              controller: _vehicleIdController,
              label: '車輛 ID (需以 V 開頭)*',
              helper: '例如：V001、VDRIVER01',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedType,
              dropdownColor: const Color(0xFF1E1E1E),
              decoration: _dropdownDecoration('車輛類型'),
              items: _vehicleTypes
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type, style: const TextStyle(color: Colors.white)),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedType = value);
                }
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _modelController,
              label: '車型名稱*',
              helper: '例如：Toyota Yaris',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _plateController,
              label: '車牌號碼*',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _batteryCapacityController,
              label: '電池容量 (kWh)',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _chargeController,
                    label: '目前電量 % *',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _hourlyRateController,
                    label: '每小時費率 (micro SUI)*',
                    keyboardType: TextInputType.number,
                    helper: '1 SUI = 1,000,000 micro',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('在地圖上選擇車輛初始位置：', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Expanded(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _selectedLocation,
                  initialZoom: 14,
                  onTap: (_, latLng) => setState(() => _selectedLocation = latLng),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://api.mapbox.com/styles/v1/mapbox/light-v11/tiles/{z}/{x}/{y}@2x?access_token=$mapboxAccessToken',
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
            const SizedBox(height: 12),
            Text(
              '位置：${_selectedLocation.latitude.toStringAsFixed(5)}, ${_selectedLocation.longitude.toStringAsFixed(5)}',
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 16),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _message!,
                  style: TextStyle(
                    color: _message!.contains('成功') ? Colors.greenAccent : Colors.redAccent,
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.car_rental, color: Colors.black),
                label: const Text('註冊車輛'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB954),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white24),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? helper,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperStyle: const TextStyle(color: Colors.white38),
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1DB954)),
        ),
      ),
    );
  }
}
