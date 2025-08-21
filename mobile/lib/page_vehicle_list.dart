import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'vehicle_map_page.dart';

class VehicleListPage extends StatefulWidget {
  @override
  _VehicleListPageState createState() => _VehicleListPageState();
}

class _VehicleListPageState extends State<VehicleListPage> {
  List<dynamic> vehicles = [];

  @override
  void initState() {
    super.initState();
    _loadVehicleData();
  }

  Future<void> _loadVehicleData() async {
    final String response = await rootBundle.loadString('assets/vehicles.json');
    final data = await json.decode(response);
    setState(() {
      vehicles = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('車輛清單'),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VehicleMapPage(),
                  ),
                );
              },
              child: Text('查看所有車輛地圖'),
            ),
          ),
          ...vehicles.map((vehicle) {
            return ListTile(
              leading: Icon(Icons.directions_car),
              title: Text(vehicle['id'] ?? '未知車輛'),
              subtitle: Text(
                  '位置: (${vehicle['location'][0]}, ${vehicle['location'][1]})'),
            );
          }).toList(),
        ],
      ),
    );
  }
}
