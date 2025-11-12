// mobile/lib/services/price_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'http_client_manager.dart';

class PriceService {
  static const String _coingeckoApi = 'https://api.coingecko.com/api/v3/simple/price';

  // HTTP Client 管理器（單例）
  static final _httpClient = HttpClientManager();

  // 緩存價格（避免過度請求 API）
  static double? _cachedSuiPrice;
  static DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// 獲取 SUI 對 USD 的匯率
  static Future<double?> getSuiUsdPrice() async {
    // 檢查緩存
    if (_cachedSuiPrice != null && _lastFetchTime != null) {
      final timeSinceLastFetch = DateTime.now().difference(_lastFetchTime!);
      if (timeSinceLastFetch < _cacheDuration) {
        print('💰 使用緩存的 SUI 價格: \$$_cachedSuiPrice');
        return _cachedSuiPrice;
      }
    }

    try {
      final response = await _httpClient.executeRequest((client) async {
        return await client.get(
          Uri.parse('$_coingeckoApi?ids=sui&vs_currencies=usd'),
        ).timeout(const Duration(seconds: 5));
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final price = data['sui']?['usd'] as num?;

        if (price != null) {
          _cachedSuiPrice = price.toDouble();
          _lastFetchTime = DateTime.now();
          print('💰 成功獲取 SUI 價格: \$$_cachedSuiPrice');
          return _cachedSuiPrice;
        }
      }

      print('⚠️ 無法獲取 SUI 價格，狀態碼: ${response.statusCode}');
      return null;
    } catch (e) {
      print('❌ 獲取 SUI 價格失敗: $e');
      return null;
    }
  }

  /// 將 SUI 金額轉換為 USD
  static Future<double?> convertSuiToUsd(double suiAmount) async {
    final price = await getSuiUsdPrice();
    if (price != null) {
      return suiAmount * price;
    }
    return null;
  }

  /// 格式化價格顯示（雙幣種）
  static Future<String> formatDualCurrency(double suiAmount) async {
    final usdAmount = await convertSuiToUsd(suiAmount);

    if (usdAmount != null) {
      return '${suiAmount.toStringAsFixed(4)} SUI ≈ \$${usdAmount.toStringAsFixed(2)}';
    } else {
      return '${suiAmount.toStringAsFixed(4)} SUI';
    }
  }

  /// 清除緩存（用於手動刷新）
  static void clearCache() {
    _cachedSuiPrice = null;
    _lastFetchTime = null;
  }
}
