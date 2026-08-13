import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

/// ZKP (零知識證明) 服務
///
/// 此服務通過調用後端 API 來生成和驗證零知識證明。
/// 支持年齡驗證和駕照驗證兩種類型的證明。
class ZkpService {
  static final ZkpService _instance = ZkpService._internal();
  factory ZkpService() => _instance;
  ZkpService._internal();

  /// 生成年齡證明
  ///
  /// 證明用戶年齡大於等於指定的最小年齡，而不暴露實際的出生日期。
  ///
  /// [birthYear] 出生年份
  /// [birthMonth] 出生月份
  /// [birthDay] 出生日期
  /// [minAge] 最小年齡要求（預設 18 歲）
  /// [did] 用戶的 DID
  ///
  /// 返回證明結果，包含 proof 和 publicSignals
  Future<ZkpProofResult> generateAgeProof({
    required int birthYear,
    required int birthMonth,
    required int birthDay,
    int minAge = 18,
    required String did,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/zkp/generate-age-proof'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'birth_year': birthYear,
          'birth_month': birthMonth,
          'birth_day': birthDay,
          'min_age': minAge,
          'did': did,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ZkpProofResult.fromJson(data);
      } else {
        throw Exception('Failed to generate age proof: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error generating age proof: $e');
    }
  }

  /// 生成駕照證明
  ///
  /// 證明用戶持有有效的駕照，而不暴露駕照號碼等詳細信息。
  ///
  /// [licenseNumber] 駕照號碼
  /// [expiryYear] 有效期年份
  /// [expiryMonth] 有效期月份
  /// [expiryDay] 有效期日期
  /// [licenseType] 駕照類型 (1=普通車, 2=機車, 3=商用車)
  /// [requiredType] 要求的駕照類型
  /// [did] 用戶的 DID
  ///
  /// 返回證明結果，包含 proof 和 publicSignals
  Future<ZkpProofResult> generateLicenseProof({
    required String licenseNumber,
    required int expiryYear,
    required int expiryMonth,
    required int expiryDay,
    int licenseType = 1,
    int requiredType = 1,
    required String did,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/zkp/generate-license-proof'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'license_number': licenseNumber,
          'expiry_year': expiryYear,
          'expiry_month': expiryMonth,
          'expiry_day': expiryDay,
          'license_type': licenseType,
          'required_type': requiredType,
          'did': did,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ZkpProofResult.fromJson(data);
      } else {
        throw Exception('Failed to generate license proof: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error generating license proof: $e');
    }
  }

  /// 獲取 ZKP 服務健康狀態
  Future<ZkpHealthStatus> getHealthStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/zkp/health'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ZkpHealthStatus.fromJson(data);
      } else {
        throw Exception('Failed to get ZKP health status');
      }
    } catch (e) {
      return ZkpHealthStatus(
        status: 'error',
        mode: 'unknown',
        snarkjsAvailable: false,
      );
    }
  }

  /// 驗證年齡憑證
  ///
  /// 將生成的證明提交到後端進行驗證
  Future<bool> verifyAgeCredential({
    required String did,
    required Map<String, dynamic> proof,
    required List<int> publicSignals,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/identity/verify-age'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'did': did,
          'proof': jsonEncode(proof),
          'public_signals': publicSignals,
          'commitment': publicSignals.length > 1 ? publicSignals[1].toString() : '0',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['valid'] == true;
      }
      return false;
    } catch (e) {
      print('Error verifying age credential: $e');
      return false;
    }
  }

  /// 驗證駕照憑證
  Future<bool> verifyLicenseCredential({
    required String did,
    required Map<String, dynamic> proof,
    required List<int> publicSignals,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/identity/verify-license'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'did': did,
          'proof': jsonEncode(proof),
          'public_signals': publicSignals,
          'commitment': publicSignals.length > 1 ? publicSignals[1].toString() : '0',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['valid'] == true;
      }
      return false;
    } catch (e) {
      print('Error verifying license credential: $e');
      return false;
    }
  }
}

/// ZKP 證明結果
class ZkpProofResult {
  final bool valid;
  final Map<String, dynamic>? proof;
  final List<int>? publicSignals;
  final String? error;
  final bool? simulated;

  ZkpProofResult({
    required this.valid,
    this.proof,
    this.publicSignals,
    this.error,
    this.simulated,
  });

  factory ZkpProofResult.fromJson(Map<String, dynamic> json) {
    return ZkpProofResult(
      valid: json['valid'] ?? false,
      proof: json['proof'],
      publicSignals: json['public_signals'] != null
          ? List<int>.from(json['public_signals'])
          : null,
      error: json['error'],
      simulated: json['simulated'],
    );
  }

  /// 檢查證明是否表示年齡有效
  bool get isAgeValid {
    if (!valid || publicSignals == null || publicSignals!.isEmpty) {
      return false;
    }
    return publicSignals![0] == 1;
  }

  /// 檢查證明是否表示駕照有效
  bool get isLicenseValid {
    if (!valid || publicSignals == null || publicSignals!.isEmpty) {
      return false;
    }
    return publicSignals![0] == 1;
  }
}

/// ZKP 服務健康狀態
class ZkpHealthStatus {
  final String status;
  final String mode;
  final bool snarkjsAvailable;
  final bool? ageKeyAvailable;
  final bool? licenseKeyAvailable;

  ZkpHealthStatus({
    required this.status,
    required this.mode,
    required this.snarkjsAvailable,
    this.ageKeyAvailable,
    this.licenseKeyAvailable,
  });

  factory ZkpHealthStatus.fromJson(Map<String, dynamic> json) {
    final snarkjs = json['snarkjs'] as Map<String, dynamic>?;
    final keys = json['keys'] as Map<String, dynamic>?;

    return ZkpHealthStatus(
      status: json['status'] ?? 'unknown',
      mode: json['mode'] ?? 'unknown',
      snarkjsAvailable: snarkjs?['available'] ?? false,
      ageKeyAvailable: keys?['age_verification'],
      licenseKeyAvailable: keys?['license_verification'],
    );
  }

  /// 服務是否可用（包含 healthy 和 degraded 狀態）
  bool get isHealthy => status == 'healthy' || status == 'degraded';

  /// 是否完全健康（snarkjs 可用）
  bool get isFullyHealthy => status == 'healthy';

  /// 是否為降級模式（模擬證明）
  bool get isDegraded => status == 'degraded';

  bool get isRealMode => mode == 'real';
  bool get isSimulatedMode => mode == 'simulated';
}
