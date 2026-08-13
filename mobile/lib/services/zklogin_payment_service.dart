// mobile/lib/services/zklogin_payment_service.dart
//
// 非託管付款編排（Phase 4）：把 lock_payment 從假 hash 換成真實 zkLogin 簽名。
//
// 流程：
//   1. ApiService.preparePayment  → 後端組交易 + Enoki 贊助 → {bytes, digest}
//   2. ZkLoginService.signSuiTransactionBytes(bytes) → 乘客臨時金鑰簽（Sui intent）
//   3. ApiService.executePayment  → Enoki 送鏈 → {digest, escrow_object_id}
//
// 前提：使用者已用 zkLogin 登入（同一 session 的臨時金鑰仍在），且 Enoki app 已設好
//       sponsor 資金 + allowedMoveCallTargets。詳見 docs/ZKLOGIN_SETUP.md。

import 'dart:convert';
import 'dart:typed_data';

import 'api_service.dart';
import 'zklogin_service.dart';

class ZkPaymentResult {
  final bool success;
  final String? digest;
  final String? escrowObjectId;
  final String? error;

  ZkPaymentResult({required this.success, this.digest, this.escrowObjectId, this.error});
}

class ZkLoginPaymentService {
  ZkLoginPaymentService._();
  static final ZkLoginPaymentService instance = ZkLoginPaymentService._();

  /// 用 zkLogin 非託管簽名完成 lock_payment。
  /// [amountMist] 為 MIST（1 SUI = 1e9 MIST）。
  Future<ZkPaymentResult> payLockPayment({
    required int tripId,
    required int amountMist,
    required String driver,
    String? platform,
  }) async {
    // 1. 後端組交易 + Enoki 贊助
    final prep = await ApiService.preparePayment(
      tripId: tripId,
      amountMist: amountMist,
      driver: driver,
      platform: platform,
    );
    if (prep['success'] != true) {
      return ZkPaymentResult(success: false, error: '贊助交易準備失敗：${prep['error']}');
    }
    final data = prep['data'] as Map<String, dynamic>;
    final bytesB64 = data['bytes'] as String?;
    final digest = data['digest'] as String?;
    if (bytesB64 == null || digest == null) {
      return ZkPaymentResult(success: false, error: 'Enoki 未回傳 bytes/digest');
    }

    // 2. 乘客臨時金鑰簽 sponsored bytes
    final String signature;
    try {
      final txBytes = Uint8List.fromList(base64.decode(bytesB64));
      signature = await ZkLoginService.instance.signSuiTransactionBytes(txBytes);
    } on ZkLoginException catch (e) {
      return ZkPaymentResult(success: false, error: '簽名失敗：${e.message}（可能需重新以 zkLogin 登入）');
    }

    // 3. 送出 → 取回 escrow_object_id
    final exec = await ApiService.executePayment(digest: digest, signature: signature);
    if (exec['success'] != true) {
      return ZkPaymentResult(success: false, error: '送出交易失敗：${exec['error']}');
    }
    final execData = exec['data'] as Map<String, dynamic>;
    return ZkPaymentResult(
      success: true,
      digest: execData['digest'] as String?,
      escrowObjectId: execData['escrow_object_id'] as String?,
    );
  }
}
