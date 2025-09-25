import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'page_vehicle_list.dart';
import 'vehicle_map_page.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';

void main() {
  runApp(const ProjectDappApp());
}

class ProjectDappApp extends StatelessWidget {
  const ProjectDappApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Decentralized Ride App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const LoginPage(),
      routes: {
        '/home': (context) => const HomePage(),
        '/ride': (context) => const RequestRidePage(),
        '/vehicles': (context) => const VehicleListPage(),
        '/map': (context) => const VehicleMapPage(),
      },
    );
  }
}

// 登入頁面
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          width: 350,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              const Text(
                "Login",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: "Enter your phone number",
                  hintStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final input = _controller.text.trim();
                  if (input.length == 10 && RegExp(r'^\d+$').hasMatch(input)) {
                    Navigator.pushReplacementNamed(context, '/home');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid 10-digit number'),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB954), // Spotify 綠
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Sign in", style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 主頁（含底部導覽）
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  final List<Widget> _pages = const [
    RequestRidePage(),
    RideHistoryPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // 深底
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: const Color(0xFF1DB954), // Spotify 綠
        unselectedItemColor: Colors.white70,
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: 'Request a ride',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Trips'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Setting'),
        ],
      ),
    );
  }
}

// 叫車頁
class RequestRidePage extends StatefulWidget {
  const RequestRidePage({super.key});

  @override
  State<RequestRidePage> createState() => _RequestRidePageState();
}

class _RequestRidePageState extends State<RequestRidePage> {
  LatLng? _movingVehicle;
  Timer? _movementTimer;
  final TextEditingController _controller = TextEditingController();
  final MapController _mapController = MapController();
  LatLng? _destination;
  LatLng _userLocation = const LatLng(25.0340, 121.5645); // 預設使用者位置
  double? lat, lon;
  bool _confirmed = false;
  String _status = '';
  List<Map<String, dynamic>> _vehicles = [];
  String? _selectedVehicleId;

  Future<void> _geocodeAddress(String address) async {
    setState(() {
      _status = 'Searching...';
      _destination = null;
    });

    final uri = Uri.parse(
      'http://localhost:5000/geocode?q=${Uri.encodeComponent(address)}',
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        if (results.isNotEmpty) {
          final result = results[0];
          lat = double.tryParse(result['lat'].toString());
          lon = double.tryParse(result['lon'].toString());

          if (lat != null && lon != null) {
            setState(() {
              _destination = LatLng(lat!, lon!);
              _status = '✅ Destination Set';
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) {
                  setState(() => _status = '');
                }
              });
              _mapController.move(_destination!, 15);
            });
          } else {
            setState(() => _status = '❌ Invalid location - unable to process');
          }
        } else {
          setState(() => _status = '❌ No results found');
        }
      } else {
        setState(() => _status = '❌ Search error${response.statusCode}');
      }
    } catch (e) {
      setState(() => _status = '⚠️ Error: $e');
    }
  }

  void _startVehicleMovement() {
    if (_selectedVehicleId == null ||
        _destination == null)
      return;

    final index = _vehicles.indexWhere((v) => v['id'] == _selectedVehicleId);
    if (index == -1) return;

    final vehicle = _vehicles[index];

    final lat0 = vehicle['lat'];
    final lon0 = vehicle['lon'];
    final lat1 = _userLocation.latitude;
    final lon1 = _userLocation.longitude;
    final lat2 = _destination!.latitude;
    final lon2 = _destination!.longitude;

    const stepsToUser = 40;
    const stepsToDest = 60;
    int currentStep = 0;

    _movementTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        double newLat, newLon;

        if (currentStep < stepsToUser) {
          newLat = lat0 + (lat1 - lat0) * currentStep / stepsToUser;
          newLon = lon0 + (lon1 - lon0) * currentStep / stepsToUser;
        } else if (currentStep < stepsToUser + stepsToDest) {
          final s = currentStep - stepsToUser;
          newLat = lat1 + (lat2 - lat1) * s / stepsToDest;
          newLon = lon1 + (lon2 - lon1) * s / stepsToDest;
        } else {
          timer.cancel();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("You've arrived at your destination!'"),
            ),
          );
          return;
        }

        _vehicles[index]['lat'] = newLat;
        _vehicles[index]['lon'] = newLon;
        _mapController.move(LatLng(newLat, newLon), _mapController.camera.zoom);
        currentStep++;
      });
    });
  }

  void _moveVehicleStepByStep(
    Map<String, dynamic> vehicle,
    LatLng target,
    VoidCallback onDone,
  ) {
    final lat1 = vehicle['lat'];
    final lon1 = vehicle['lon'];
    final lat2 = target.latitude;
    final lon2 = target.longitude;

    const steps = 50;
    int currentStep = 0;

    _movementTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (currentStep >= steps) {
        timer.cancel();
        vehicle['lat'] = lat2;
        vehicle['lon'] = lon2;
        setState(() {});
        onDone();
        return;
      }

      final newLat = lat1 + (lat2 - lat1) * currentStep / steps;
      final newLon = lon1 + (lon2 - lon1) * currentStep / steps;

      setState(() {
        vehicle['lat'] = newLat;
        vehicle['lon'] = newLon;
      });

      currentStep++;
    });
  }

  Future<void> _loadVehicles() async {
    final jsonStr = await DefaultAssetBundle.of(
      context,
    ).loadString('assets/vehicles.json');
    final List<dynamic> data = json.decode(jsonStr);
    setState(() {
      _vehicles = data.cast<Map<String, dynamic>>();
    });
  }

  void _confirmDestination() async {
    if (_destination != null) {
      setState(() {
        _confirmed = true;
        _mapController.move(_userLocation, 15); // 跳回用戶位置
      });
      await _loadVehicles();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Destination confirmed!Nearby vehicles are now visible.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(center: _userLocation, zoom: 14),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.mapbox.com/styles/v1/mapbox/light-v11/tiles/512/{z}/{x}/{y}@2x?access_token=pk.eyJ1IjoiaHkxaWlpIiwiYSI6ImNtYmM4a204djFiaHEyaXByZTkwYmNmZW0ifQ.Gbt4zAxe38-eS7b7pCC6HA',
                additionalOptions: {
                  'access_token':
                      'pk.eyJ1IjoiaHkxaWlpIiwiYSI6ImNtYmM4a204djFiaHEyaXByZTkwYmNmZW0ifQ.Gbt4zAxe38-eS7b7pCC6HA',
                },
                tileSize: 512,
                zoomOffset: -1,
              ),

              MarkerLayer(
                markers: [
                  // 使用者位置
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

                  // 車輛標記
                  if (_confirmed)
                    ..._vehicles.map((v) {
                      final lat = double.tryParse(v['lat'].toString());
                      final lon = double.tryParse(v['lon'].toString());
                      final id = v['id'];

                      if (lat == null || lon == null) {
                        return const Marker(
                          width: 0,
                          height: 0,
                          point: LatLng(0, 0),
                          child: SizedBox(),
                        );
                      }

                      return Marker(
                        point: LatLng(lat, lon),
                        width: 60,
                        height: 60,
                        child: Column(
                          children: [
                            Text(
                              id,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 2),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() => _selectedVehicleId = id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Vehicle Selected!：$id'),
                                  ),
                                );
                                _startVehicleMovement();
                              },
                              child: Image.asset(
                                'assets/car_icon.png',
                                width: 28,
                                height: 28,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ],
          ),
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
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: "Where to？",
                ),
                onSubmitted: (text) {
                  if (text.isNotEmpty) _geocodeAddress(text);
                },
              ),
            ),
          ),
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
                ),
              ),
            ),
          if (_destination != null && !_confirmed)
            Positioned(
              bottom: 90,
              left: 20,
              right: 20,
              child: ElevatedButton(
                onPressed: _confirmDestination,
                child: const Text("Confirm"),
              ),
            ),
        ],
      ),
    );
  }
}

// 設定頁
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Setting"),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingItem(
            icon: Icons.person,
            title: "Profile",
            onTap: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("Profile selected")));
            },
          ),
          const SizedBox(height: 12),
          _buildSettingItem(
            icon: Icons.lock,
            title: "Change Password",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Change Password selected")),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildSettingItem(
            icon: Icons.logout,
            title: "Logout",
            onTap: () {
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      tileColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        color: Colors.white70,
        size: 16,
      ),
      onTap: onTap,
    );
  }
}

// 歷史行程頁
class RideHistoryPage extends StatelessWidget {
  const RideHistoryPage({super.key});

  final List<Map<String, String>> dummyHistory = const [
    {"destination": "台北車站", "time": "2025-05-30 14:00"},
    {"destination": "政治大學", "time": "2025-05-29 18:20"},
    {"destination": "捷運市政府站", "time": "2025-05-28 09:45"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Trip History"),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: dummyHistory.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final trip = dummyHistory[index];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip["destination"] ?? "Unknown Location",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  trip["time"] ?? "",
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class VehicleListPage extends StatefulWidget {
  const VehicleListPage({super.key});

  @override
  State<VehicleListPage> createState() => _VehicleListPageState();
}

class _VehicleListPageState extends State<VehicleListPage> {
  List<dynamic> vehicles = [];

  Future<void> loadVehicles() async {
    final jsonString = await rootBundle.loadString('assets/vehicles.json');
    final List<dynamic> data = json.decode(jsonString);
    setState(() {
      vehicles = data;
    });
  }

  @override
  void initState() {
    super.initState();
    loadVehicles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Simulated Vehicle List")),
      body: vehicles.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: vehicles.length,
              itemBuilder: (context, index) {
                final v = vehicles[index];
                return ListTile(
                  leading: const Icon(Icons.car_rental),
                  title: Text("ID: ${v['id']}"),
                  subtitle: Text("Location: ${v['location']}"),
                );
              },
            ),
    );
  }
}