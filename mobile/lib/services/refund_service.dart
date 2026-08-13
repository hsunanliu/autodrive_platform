// mobile/lib/services/refund_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'http_client_manager.dart';
import '../config/app_config.dart';

class RefundService {
  static final _httpClient = HttpClientManager();
  // 統一改用 AppConfig（原本硬編碼 IP 172.20.10.14 已移除）
  static String get baseUrl => AppConfig.backendUrl;

  /// 創建退款請求
  ///
  /// 參數：
  /// - tripId: 行程 ID
  /// - reason: 退款原因（至少 10 個字）
  /// - refundAmountSui: 退款金額（SUI）
  /// - evidenceFile: 退款證據文件（選填）
  /// - token: 用戶認證令牌
  ///
  /// 返回：成功狀態與退款請求數據
  static Future<Map<String, dynamic>> createRefundRequest({
    required int tripId,
    required String reason,
    required double refundAmountSui,
    File? evidenceFile,
    required String token,
  }) async {
    try {
      // 構建 multipart request
      final uri = Uri.parse('$baseUrl/refunds/create');

      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // 添加表單字段
      request.fields['trip_id'] = tripId.toString();
      request.fields['reason'] = reason;
      request.fields['refund_amount_sui'] = refundAmountSui.toString();

      // 添加證據文件（如果有）
      if (evidenceFile != null) {
        final fileBytes = await evidenceFile.readAsBytes();
        final multipartFile = http.MultipartFile.fromBytes(
          'evidence_file',
          fileBytes,
          filename: evidenceFile.path.split('/').last,
        );
        request.files.add(multipartFile);
      }

      // 發送 multipart 請求。MultipartRequest.send() 回傳 StreamedResponse，
      // 與 _httpClient.executeRequest（只吃 Future<Response>）型別不相容，
      // 故用 BaseRequest.send()（自行管理 client）再轉成 Response。
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        final error = json.decode(response.body);
        return {
          'success': false,
          'error': error['detail'] ?? '創建退款請求失敗',
        };
      }
    } catch (e) {
      print('❌ 創建退款請求失敗: $e');
      return {
        'success': false,
        'error': '創建退款請求失敗: $e',
      };
    }
  }

  /// 獲取用戶的退款請求列表
  ///
  /// 參數：
  /// - token: 用戶認證令牌
  /// - limit: 最大返回數量（選填）
  ///
  /// 返回：退款請求列表
  static Future<Map<String, dynamic>> getUserRefunds({
    required String token,
    int? limit,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (limit != null) queryParams['limit'] = limit.toString();

      final uri = Uri.parse('$baseUrl/refunds/my').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await _httpClient.executeRequest(
        (client) => client.get(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'error': '獲取退款列表失敗',
        };
      }
    } catch (e) {
      print('❌ 獲取退款列表失敗: $e');
      return {
        'success': false,
        'error': '獲取退款列表失敗: $e',
      };
    }
  }
}
