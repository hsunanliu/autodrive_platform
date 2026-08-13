// mobile/lib/services/zklogin_action_service.dart
//
// 非託管動作編排（Phase 5 委託 / Phase 6 爭議）：與付款同一套
// prepare → 臨時金鑰簽 sponsored bytes → execute 流程，只是動作與回傳物件不同。
//
// 前提：使用者已用 zkLogin 登入（同一 session 臨時金鑰仍在）、Enoki 贊助就緒。

import 'dart:convert';
import 'dart:typed_data';

import 'api_service.dart';
import 'zklogin_service.dart';

class ZkActionResult {
  final bool success;
  final String? digest;
  final String? objectId; // cap_object_id 或 dispute_object_id
  final String? error;

  ZkActionResult({required this.success, this.digest, this.objectId, this.error});
}

class ZkLoginActionService {
  ZkLoginActionService._();
  static final ZkLoginActionService instance = ZkLoginActionService._();

  /// 共用：prepare → 簽 → execute。
  /// [prepare] 回傳 {success, data:{bytes, digest}}；[execute] 收 {digest, signature}
  /// 回傳 {success, data:{digest, <objectIdKey>}}。
  Future<ZkActionResult> _run({
    required Future<Map<String, dynamic>> Function() prepare,
    required Future<Map<String, dynamic>> Function(String digest, String signature) execute,
    required String objectIdKey,
  }) async {
    final prep = await prepare();
    if (prep['success'] != true) {
      return ZkActionResult(success: false, error: '贊助交易準備失敗：${prep['error']}');
    }
    final data = prep['data'] as Map<String, dynamic>;
    final bytesB64 = data['bytes'] as String?;
    final digest = data['digest'] as String?;
    if (bytesB64 == null || digest == null) {
      return ZkActionResult(success: false, error: 'Enoki 未回傳 bytes/digest');
    }

    final String signature;
    try {
      final txBytes = Uint8List.fromList(base64.decode(bytesB64));
      signature = await ZkLoginService.instance.signSuiTransactionBytes(txBytes);
    } on ZkLoginException catch (e) {
      return ZkActionResult(success: false, error: '簽名失敗：${e.message}（可能需重新以 zkLogin 登入）');
    }

    final exec = await execute(digest, signature);
    if (exec['success'] != true) {
      return ZkActionResult(success: false, error: '送出交易失敗：${exec['error']}');
    }
    final execData = exec['data'] as Map<String, dynamic>;
    return ZkActionResult(
      success: true,
      digest: execData['digest'] as String?,
      objectId: execData[objectIdKey] as String?,
    );
  }

  /// Phase 5：發行委託（issue_operator_cap）→ 回傳 cap_object_id。
  Future<ZkActionResult> delegate({
    required int maxSpendMist,
    required int dailyLimitMist,
    required int validForMs,
    int? allowedActions,
  }) => _run(
        prepare: () => ApiService.delegatePrepare(
          maxSpendMist: maxSpendMist,
          dailyLimitMist: dailyLimitMist,
          validForMs: validForMs,
          allowedActions: allowedActions,
        ),
        execute: (d, s) => ApiService.delegateExecute(digest: d, signature: s),
        objectIdKey: 'cap_object_id',
      );

  /// Phase 6：發起爭議（raise_dispute）→ 回傳 dispute_object_id。
  Future<ZkActionResult> raiseDispute({
    required String escrowObjectId,
    required String reason,
  }) => _run(
        prepare: () => ApiService.disputePrepare(
          escrowObjectId: escrowObjectId,
          reason: reason,
        ),
        execute: (d, s) => ApiService.disputeExecute(digest: d, signature: s),
        objectIdKey: 'dispute_object_id',
      );
}
