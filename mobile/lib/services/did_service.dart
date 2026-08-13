/// DID (Decentralized Identity) Service
/// 去中心化身份服務
///
/// 提供 DID 註冊、驗證、查詢功能
/// 整合後端 Identity API
library;

import 'api_service.dart';

/// DID 信息模型
class DIDInfo {
  final String? did;
  final bool ageVerified;
  final bool licenseVerified;
  final DateTime createdAt;

  DIDInfo({
    this.did,
    required this.ageVerified,
    required this.licenseVerified,
    required this.createdAt,
  });

  factory DIDInfo.fromJson(Map<String, dynamic> json) {
    return DIDInfo(
      did: json['did'],
      ageVerified: json['age_verified'] ?? false,
      licenseVerified: json['license_verified'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  bool get hasDID => did != null && did!.isNotEmpty;
}

/// DID 文檔模型（W3C DID Core 1.0）
class DIDDocument {
  final String id;
  final List<String> context;
  final List<VerificationMethod> verificationMethod;
  final List<String> authentication;
  final List<String> assertionMethod;

  DIDDocument({
    required this.id,
    this.context = const ['https://www.w3.org/ns/did/v1'],
    required this.verificationMethod,
    required this.authentication,
    this.assertionMethod = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      '@context': context,
      'id': id,
      'verificationMethod': verificationMethod.map((v) => v.toJson()).toList(),
      'authentication': authentication,
      'assertionMethod': assertionMethod,
    };
  }
}

/// 驗證方法模型
class VerificationMethod {
  final String id;
  final String type;
  final String controller;
  final String publicKeyMultibase;

  VerificationMethod({
    required this.id,
    required this.type,
    required this.controller,
    required this.publicKeyMultibase,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'controller': controller,
      'publicKeyMultibase': publicKeyMultibase,
    };
  }
}

/// DID Service
class DIDService {
  /// 生成 DID 字符串
  /// 格式：did:sui:<wallet_address>
  static String generateDID(String walletAddress) {
    // 確保地址格式正確（0x 開頭，64 位十六進制）
    String normalizedAddress = walletAddress.toLowerCase();
    if (!normalizedAddress.startsWith('0x')) {
      normalizedAddress = '0x$normalizedAddress';
    }

    return 'did:sui:$normalizedAddress';
  }

  /// 從 DID 解析錢包地址
  static String? parseWalletAddress(String did) {
    if (!did.startsWith('did:sui:')) {
      return null;
    }
    return did.substring(8); // 移除 'did:sui:' 前綴
  }

  /// 創建 DID 文檔
  static DIDDocument createDIDDocument({
    required String walletAddress,
    required String publicKeyHex,
    String keyType = 'Ed25519VerificationKey2020',
  }) {
    final did = generateDID(walletAddress);
    final keyId = '$did#key-1';

    // 將公鑰轉換為 multibase 格式（z 前綴表示 base58btc）
    final publicKeyMultibase = 'z${_hexToBase58(publicKeyHex)}';

    return DIDDocument(
      id: did,
      verificationMethod: [
        VerificationMethod(
          id: keyId,
          type: keyType,
          controller: did,
          publicKeyMultibase: publicKeyMultibase,
        ),
      ],
      authentication: [keyId],
      assertionMethod: [keyId],
    );
  }

  /// 獲取當前用戶的 DID 信息
  static Future<DIDInfo?> getDIDInfo() async {
    try {
      final result = await ApiService.get('/identity/did-info');

      if (result['success'] == true && result['data'] != null) {
        return DIDInfo.fromJson(result['data']);
      }

      print('獲取 DID 信息失敗: ${result['error']}');
      return null;
    } catch (e) {
      print('獲取 DID 信息異常: $e');
      return null;
    }
  }

  /// 註冊 DID
  /// 使用用戶的錢包地址和公鑰創建並註冊 DID
  static Future<Map<String, dynamic>> registerDID({
    required String walletAddress,
    required String publicKeyHex,
  }) async {
    try {
      // 1. 生成 DID 和 DID 文檔
      final did = generateDID(walletAddress);
      final didDocument = createDIDDocument(
        walletAddress: walletAddress,
        publicKeyHex: publicKeyHex,
      );

      print('註冊 DID: $did');

      // 2. 調用後端 API 註冊
      final result = await ApiService.post('/identity/register-did', {
        'did': did,
        'did_document': didDocument.toJson(),
      });

      if (result['success'] == true) {
        print('DID 註冊成功');
        return {
          'success': true,
          'did': did,
          'message': '身份標識已創建',
        };
      } else {
        return {
          'success': false,
          'error': result['error'] ?? '註冊失敗',
        };
      }
    } catch (e) {
      print('註冊 DID 異常: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }


  /// 驗證年齡（ZKP）
  /// 證明用戶年齡 >= 18 歲而不揭露實際出生日期
  static Future<Map<String, dynamic>> verifyAge({
    required String proof,
    required List<int> publicSignals,
    required String commitment,
  }) async {
    try {
      final result = await ApiService.post('/identity/verify-age', {
        'proof': proof,
        'public_signals': publicSignals,
        'commitment': commitment,
      });

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        return {
          'success': data['success'] ?? false,
          'verified': data['verified'] ?? false,
          'message': data['message'] ?? '',
        };
      }

      return {
        'success': false,
        'verified': false,
        'error': result['error'] ?? '驗證請求失敗',
      };
    } catch (e) {
      print('年齡驗證異常: $e');
      return {
        'success': false,
        'verified': false,
        'error': e.toString(),
      };
    }
  }

  /// 驗證駕照（ZKP）
  /// 證明用戶持有有效駕照而不揭露駕照號碼
  static Future<Map<String, dynamic>> verifyLicense({
    required String proof,
    required List<int> publicSignals,
    required String commitment,
  }) async {
    try {
      final result = await ApiService.post('/identity/verify-license', {
        'proof': proof,
        'public_signals': publicSignals,
        'commitment': commitment,
      });

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        return {
          'success': data['success'] ?? false,
          'verified': data['verified'] ?? false,
          'message': data['message'] ?? '',
        };
      }

      return {
        'success': false,
        'verified': false,
        'error': result['error'] ?? '驗證請求失敗',
      };
    } catch (e) {
      print('駕照驗證異常: $e');
      return {
        'success': false,
        'verified': false,
        'error': e.toString(),
      };
    }
  }

  /// 生成並驗證年齡證明（一站式服務）
  /// 直接調用後端 API，後端會生成 ZKP 證明並存儲憑證
  static Future<Map<String, dynamic>> generateAndVerifyAge({
    required int birthYear,
    required int birthMonth,
    required int birthDay,
    int minAge = 18,
  }) async {
    try {
      final result = await ApiService.post('/identity/generate-age-proof', {
        'birth_year': birthYear,
        'birth_month': birthMonth,
        'birth_day': birthDay,
        'min_age': minAge,
      });

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        return {
          'success': data['success'] ?? false,
          'credential_type': 'age',
          'is_valid': data['is_valid'] ?? false,
          'is_simulated': data['is_simulated'] ?? false,
          'min_age_verified': data['min_age_verified'],
          'did': data['did'],
        };
      }

      return {
        'success': false,
        'error': result['error'] ?? '年齡驗證失敗',
      };
    } catch (e) {
      print('生成年齡證明異常: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 生成並驗證駕照證明（一站式服務）
  /// 直接調用後端 API，後端會生成 ZKP 證明並存儲憑證
  static Future<Map<String, dynamic>> generateAndVerifyLicense({
    required String licenseNumber,
    required int expiryYear,
    required int expiryMonth,
    required int expiryDay,
    int licenseType = 1,
  }) async {
    try {
      final result = await ApiService.post('/identity/generate-license-proof', {
        'license_number': licenseNumber,
        'expiry_year': expiryYear,
        'expiry_month': expiryMonth,
        'expiry_day': expiryDay,
        'license_type': licenseType,
      });

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        return {
          'success': data['success'] ?? false,
          'credential_type': 'license',
          'is_valid': data['is_valid'] ?? false,
          'is_simulated': data['is_simulated'] ?? false,
          'license_type_verified': data['license_type_verified'],
          'did': data['did'],
        };
      }

      return {
        'success': false,
        'error': result['error'] ?? '駕照驗證失敗',
      };
    } catch (e) {
      print('生成駕照證明異常: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 獲取用戶憑證列表
  static Future<Map<String, dynamic>> getCredentials() async {
    try {
      final result = await ApiService.get('/identity/credentials');

      if (result['success'] == true && result['data'] != null) {
        return {
          'success': true,
          'user_id': result['data']['user_id'],
          'did': result['data']['did'],
          'credentials': result['data']['credentials'] ?? [],
        };
      }

      return {
        'success': false,
        'error': result['error'] ?? '獲取憑證失敗',
        'credentials': [],
      };
    } catch (e) {
      print('獲取憑證異常: $e');
      return {
        'success': false,
        'error': e.toString(),
        'credentials': [],
      };
    }
  }

  /// 撤銷 DID
  static Future<Map<String, dynamic>> revokeDID() async {
    try {
      final result = await ApiService.delete('/identity/did');

      if (result['success'] == true) {
        return {
          'success': true,
          'message': '身份標識已撤銷',
        };
      }

      return {
        'success': false,
        'error': result['error'] ?? '撤銷失敗',
      };
    } catch (e) {
      print('撤銷 DID 異常: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // 已移除客戶端「假 ZKP 證明」：原 generateAgeProof / generateLicenseProof / generateCommitment
  // 以 sha256(did:isValid:timestamp) 產出可任意偽造的假 proof（無零知識、無密碼學保證），且無任何呼叫端。
  // 真實年齡/駕照證明一律走後端：DIDService.generateAndVerifyAge / generateAndVerifyLicense
  // （→ /identity/generate-*-proof），或 ZkpService（→ /zkp/generate-*-proof）。

  /// 輔助函數：將十六進制轉換為 Base58
  static String _hexToBase58(String hex) {
    // 簡化實現：直接返回 hex（實際應轉換為 base58btc）
    // TODO: 實現完整的 Base58 編碼
    return hex.replaceAll('0x', '');
  }
}
