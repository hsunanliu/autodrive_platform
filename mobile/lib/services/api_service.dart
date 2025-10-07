// mobile/lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // 後端 API 基礎 URL
  static const String baseUrl = 'http://localhost:8000/api/v1';
  
  // 存儲用戶 token
  static String? _token;
  
  // 設置 token
  static void setToken(String token) {
    _token = token;
  }
  
  static void clearToken() {
    _token = null;
  }
  
  // 獲取 headers
  static Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
    };
    
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    
    return headers;
  }
  
  static Map<String, dynamic> _wrapResponse(http.Response response) {
    dynamic data;
    try {
      data = response.body.isNotEmpty ? jsonDecode(response.body) : null;
    } catch (e) {
      data = {'raw': response.body, 'parseError': e.toString()};
    }

    return {
      'success': response.statusCode >= 200 && response.statusCode < 300,
      'data': data,
      'statusCode': response.statusCode,
    };
  }

  static Future<Map<String, dynamic>> _handleRequest(Future<http.Response> Function() request) async {
    try {
      final response = await request();
      return _wrapResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // 用戶註冊
  static Future<Map<String, dynamic>> registerUser({
    required String username,
    required String password,
    required String walletAddress,
    required String email,
    required String userType,
    String? phoneNumber,
    String? displayName,
  }) async {
    return _handleRequest(() {
      return http.post(
        Uri.parse('$baseUrl/users/register'),
        headers: _headers,
        body: jsonEncode({
          'username': username,
          'password': password,
          'wallet_address': walletAddress,
          'email': email,
          'user_type': userType,
          if (phoneNumber != null) 'phone_number': phoneNumber,
          if (displayName != null) 'display_name': displayName,
        }),
      );
    });
  }
  
  // 用戶登入
  static Future<Map<String, dynamic>> loginUser({
    required String identifier,
    required String password,
  }) async {
    final result = await _handleRequest(() {
      return http.post(
        Uri.parse('$baseUrl/users/login'),
        headers: _headers,
        body: jsonEncode({
          'identifier': identifier,
          'password': password,
        }),
      );
    });

    if (result['success'] == true) {
      final data = result['data'];
      if (data is Map && data['access_token'] is String) {
        setToken(data['access_token']);
      }
    }

    return result;
  }

  static Future<Map<String, dynamic>> getUserProfile(int userId) async {
    return _handleRequest(() {
      return http.get(
        Uri.parse('$baseUrl/users/$userId'),
        headers: _headers,
      );
    });
  }
  
  // 獲取附近可用車輛
  static Future<Map<String, dynamic>> getAvailableVehicles({
    required double lat,
    required double lng,
    double radiusKm = 5.0,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/vehicles/available').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lng': lng.toString(),
        'radius_km': radiusKm.toString(),
        'limit': limit.toString(),
      },
    );

    return _handleRequest(() => http.get(uri, headers: _headers));
  }
  
  // 創建行程請求
  static Future<Map<String, dynamic>> createTripRequest({
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String dropoffAddress,
    required int passengerCount,
    String? preferredVehicleType,
    String? notes,
  }) async {
    return _handleRequest(() {
      return http.post(
        Uri.parse('$baseUrl/trips/'),
        headers: _headers,
        body: jsonEncode({
          'pickup_lat': pickupLat,
          'pickup_lng': pickupLng,
          'pickup_address': pickupAddress,
          'dropoff_lat': dropoffLat,
          'dropoff_lng': dropoffLng,
          'dropoff_address': dropoffAddress,
          'passenger_count': passengerCount,
          'preferred_vehicle_type': preferredVehicleType,
          'notes': notes,
        }),
      );
    });
  }
  
  // 獲取行程預估
  static Future<Map<String, dynamic>> getTripEstimate({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) async {
    final uri = Uri.parse('$baseUrl/trips/estimate').replace(
      queryParameters: {
        'pickup_lat': pickupLat.toString(),
        'pickup_lng': pickupLng.toString(),
        'dropoff_lat': dropoffLat.toString(),
        'dropoff_lng': dropoffLng.toString(),
      },
    );

    return _handleRequest(() => http.post(uri, headers: _headers));
  }
  
  // 獲取用戶行程列表
  static Future<Map<String, dynamic>> getUserTrips({
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    if (status != null) {
      queryParams['status'] = status;
    }

    final uri = Uri.parse('$baseUrl/trips/').replace(
      queryParameters: queryParams,
    );

    return _handleRequest(() => http.get(uri, headers: _headers));
  }
  
  // 獲取錢包餘額
  static Future<Map<String, dynamic>> getWalletBalance() async {
    return _handleRequest(() {
      return http.get(
        Uri.parse('$baseUrl/trips/payment/wallet/balance'),
        headers: _headers,
      );
    });
  }
  
  // 獲取交易狀態
  static Future<Map<String, dynamic>> getTransactionStatus(String txHash) async {
    return _handleRequest(() {
      return http.get(
        Uri.parse('$baseUrl/trips/payment/transaction/$txHash'),
        headers: _headers,
      );
    });
  }

  static Future<Map<String, dynamic>> registerVehicle({
    required String vehicleId,
    required String plateNumber,
    required String model,
    required String vehicleType,
    required double currentChargePercent,
    required int hourlyRate,
    double? batteryCapacity,
    double? currentLat,
    double? currentLng,
  }) async {
    return _handleRequest(() {
      return http.post(
        Uri.parse('$baseUrl/vehicles/'),
        headers: _headers,
        body: jsonEncode({
          'vehicle_id': vehicleId,
          'plate_number': plateNumber,
          'model': model,
          'vehicle_type': vehicleType,
          'current_charge_percent': currentChargePercent,
          'hourly_rate': hourlyRate,
          if (batteryCapacity != null) 'battery_capacity_kwh': batteryCapacity,
          if (currentLat != null) 'current_lat': currentLat,
          if (currentLng != null) 'current_lng': currentLng,
        }),
      );
    });
  }

  static Future<Map<String, dynamic>> getMyVehicles() async {
    return _handleRequest(() {
      return http.get(
        Uri.parse('$baseUrl/vehicles/my'),
        headers: _headers,
      );
    });
  }

  static Future<Map<String, dynamic>> updateVehicleStatus({
    required String vehicleId,
    required String status,
  }) async {
    return _handleRequest(() {
      return http.put(
        Uri.parse('$baseUrl/vehicles/$vehicleId/status').replace(
          queryParameters: {'status': status},
        ),
        headers: _headers,
      );
    });
  }

  static Future<Map<String, dynamic>> updateVehicleLocation({
    required String vehicleId,
    required double lat,
    required double lng,
    String? status,
  }) async {
    return _handleRequest(() {
      return http.put(
        Uri.parse('$baseUrl/vehicles/$vehicleId/location'),
        headers: _headers,
        body: jsonEncode({
          'lat': lat,
          'lng': lng,
          if (status != null) 'status': status,
        }),
      );
    });
  }

  static Future<Map<String, dynamic>> acceptTrip({
    required int tripId,
    required int etaMinutes,
  }) async {
    return _handleRequest(() {
      return http.post(
        Uri.parse('$baseUrl/trips/$tripId/accept'),
        headers: _headers,
        body: jsonEncode({'estimated_arrival_minutes': etaMinutes}),
      );
    });
  }

  static Future<Map<String, dynamic>> completeTrip(int tripId) async {
    return _handleRequest(() {
      return http.put(
        Uri.parse('$baseUrl/trips/$tripId/complete'),
        headers: _headers,
      );
    });
  }

  static Future<Map<String, dynamic>> cancelTrip({
    required int tripId,
    required String reason,
    required String cancelledBy,
  }) async {
    return _handleRequest(() {
      return http.put(
        Uri.parse('$baseUrl/trips/$tripId/cancel'),
        headers: _headers,
        body: jsonEncode({
          'reason': reason,
          'cancelled_by': cancelledBy,
        }),
      );
    });
  }
}
