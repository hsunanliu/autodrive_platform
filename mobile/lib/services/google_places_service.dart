// mobile/lib/services/google_places_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../config/google_maps_config.dart';
import 'http_client_manager.dart';

class GooglePlacesService {
  // HTTP Client 管理器（單例）
  static final _httpClient = HttpClientManager();
  // Google Places API Key
  static String get _apiKey => GoogleMapsConfig.apiKey;
  
  // 使用新的 Places API (New) 端點
  static const String _autocompleteUrl =
      'https://places.googleapis.com/v1/places:autocomplete';
  static const String _placeDetailsUrl =
      'https://places.googleapis.com/v1/places';

  /// 自動完成搜尋（使用新的 Places API）
  /// 
  /// 參數：
  /// - query: 搜尋關鍵字
  /// - location: 當前位置（可選，用於優先顯示附近結果）
  /// 
  /// 返回：地點建議列表
  static Future<List<PlaceSuggestion>> autocomplete(
    String query, {
    LatLng? location,
  }) async {
    if (query.isEmpty || query.length < 2) return [];

    try {
      final body = {
        'input': query,
        'languageCode': 'zh-TW',
        'includedRegionCodes': ['TW'], // 限制台灣
      };

      // 如果有當前位置，優先顯示附近結果
      if (location != null) {
        body['locationBias'] = {
          'circle': {
            'center': {
              'latitude': location.latitude,
              'longitude': location.longitude,
            },
            'radius': 50000.0, // 50km
          }
        };
      }

      final response = await _httpClient.executeRequest((client) => client.post(
        Uri.parse(_autocompleteUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          ...GoogleMapsConfig.restrictionHeaders,
        },
        body: json.encode(body),
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final suggestions = data['suggestions'] as List? ?? [];

        return suggestions.map((suggestion) {
          final placePrediction = suggestion['placePrediction'];
          return PlaceSuggestion(
            placeId: placePrediction['placeId'] ?? '',
            name: placePrediction['structuredFormat']?['mainText']?['text'] ?? 
                  placePrediction['text']?['text'] ?? '',
            fullAddress: placePrediction['text']?['text'] ?? '',
            types: List<String>.from(placePrediction['types'] ?? []),
          );
        }).toList();
      }
    } catch (e) {
      print('Google Places 搜尋失敗: $e');
    }

    return [];
  }

  /// 獲取地點詳細信息（包含座標）- 使用新的 Places API
  /// 
  /// 參數：
  /// - placeId: Google Place ID
  /// 
  /// 返回：地點詳細信息
  static Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    try {
      final response = await _httpClient.executeRequest((client) => client.get(
        Uri.parse('$_placeDetailsUrl/$placeId'),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask': 'id,displayName,formattedAddress,location,types',
          ...GoogleMapsConfig.restrictionHeaders,
        },
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final location = data['location'];

        return PlaceDetails(
          placeId: placeId,
          name: data['displayName']?['text'] ?? '',
          fullAddress: data['formattedAddress'] ?? '',
          coordinates: LatLng(
            location['latitude'],
            location['longitude'],
          ),
          types: List<String>.from(data['types'] ?? []),
        );
      }
    } catch (e) {
      print('獲取地點詳情失敗: $e');
    }

    return null;
  }

  /// 反向地理編碼（座標轉地址）
  /// 
  /// 參數：
  /// - coordinates: 經緯度座標
  /// 
  /// 返回：地址字串
  static Future<String?> reverseGeocode(LatLng coordinates) async {
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json',
      ).replace(queryParameters: {
        'latlng': '${coordinates.latitude},${coordinates.longitude}',
        'key': _apiKey,
        'language': 'zh-TW',
      });

      final response = await _httpClient.executeRequest(
        (client) => client.get(uri, headers: GoogleMapsConfig.restrictionHeaders),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          if (results.isNotEmpty) {
            return results[0]['formatted_address'];
          }
        }
      }
    } catch (e) {
      print('反向地理編碼失敗: $e');
    }

    return null;
  }

  // 附近搜尋功能在新的 Places API 中需要使用不同的端點
  // 如果需要，可以稍後實現
}

/// 地點建議數據模型（用於自動完成）
class PlaceSuggestion {
  final String placeId;
  final String name;
  final String fullAddress;
  final List<String> types;

  PlaceSuggestion({
    required this.placeId,
    required this.name,
    required this.fullAddress,
    required this.types,
  });

  /// 獲取顯示用的圖標
  String get icon {
    if (types.contains('train_station') || types.contains('transit_station')) {
      return '🚉'; // 車站
    } else if (types.contains('airport')) {
      return '✈️'; // 機場
    } else if (types.contains('shopping_mall')) {
      return '🏬'; // 購物中心
    } else if (types.contains('restaurant')) {
      return '🍽️'; // 餐廳
    } else if (types.contains('cafe')) {
      return '☕'; // 咖啡廳
    } else if (types.contains('hospital')) {
      return '🏥'; // 醫院
    } else if (types.contains('school') || types.contains('university')) {
      return '🏫'; // 學校
    } else if (types.contains('park')) {
      return '🌳'; // 公園
    } else if (types.contains('point_of_interest')) {
      return '📍'; // 興趣點
    } else {
      return '📌'; // 預設
    }
  }
}

/// 地點詳細信息數據模型
class PlaceDetails {
  final String placeId;
  final String name;
  final String fullAddress;
  final LatLng coordinates;
  final List<String> types;

  PlaceDetails({
    required this.placeId,
    required this.name,
    required this.fullAddress,
    required this.coordinates,
    required this.types,
  });
}
