// mobile/lib/widgets/agent_activity_card.dart
//
// Agent 代理活動卡片：呈現一筆 LLM 結算決策。
// - auto_executed / confirmed：顯示「Agent 已代您放款/退款 X SUI」＋交易 digest。
// - pending / needs_review：顯示決策理由 + 「確認 / 拒絕」按鈕（大額待確認）。
// 資料來源：GET /agent/activities（AgentDecisionRecord）。

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AgentActivityCard extends StatelessWidget {
  final Map<String, dynamic> activity;
  final bool busy;
  final Future<void> Function(int decisionId)? onConfirm;
  final Future<void> Function(int decisionId)? onDecline;

  const AgentActivityCard({
    super.key,
    required this.activity,
    this.busy = false,
    this.onConfirm,
    this.onDecline,
  });

  static String _sui(dynamic mist) {
    final v = (mist is int) ? mist : int.tryParse('${mist ?? 0}') ?? 0;
    return (v / 1000000000).toStringAsFixed(4);
  }

  @override
  Widget build(BuildContext context) {
    final status = activity['status'] as String? ?? '';
    final action = activity['action'] as String? ?? '';
    final reason = activity['reason'] as String? ?? '';
    final amount = _sui(activity['amount_mist']);
    final txDigest = activity['tx_digest'] as String?;
    final decisionId = activity['id'] as int?;
    final isPending = status == 'pending' || status == 'needs_review';

    final actionLabel = switch (action) {
      'release' => '放款給司機',
      'refund' => '退款給您',
      'hold_for_confirm' => '待您確認',
      'flag_review' => '需人工審查',
      _ => action,
    };

    final (statusLabel, statusColor, statusIcon) = switch (status) {
      'auto_executed' => ('已自動執行', AppColors.success, Icons.smart_toy),
      'confirmed' => ('已確認執行', AppColors.success, Icons.check_circle),
      'pending' => ('待確認', AppColors.warning, Icons.hourglass_top),
      'needs_review' => ('需審查', AppColors.warning, Icons.gpp_maybe),
      'declined' => ('已拒絕', AppColors.textMuted, Icons.cancel),
      'failed' => ('執行失敗', AppColors.danger, Icons.error_outline),
      _ => (status, AppColors.textMuted, Icons.info_outline),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🤖 ', style: TextStyle(fontSize: 16)),
                Expanded(
                  child: Text(
                    '$actionLabel　$amount SUI',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                ),
                StatusPill(label: statusLabel, color: statusColor, icon: statusIcon),
              ],
            ),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(reason,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
            if (txDigest != null && txDigest.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('交易：${txDigest.length > 18 ? '${txDigest.substring(0, 18)}…' : txDigest}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
            if (isPending && decisionId != null && onConfirm != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: busy ? null : () => onConfirm!(decisionId),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('確認'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy || onDecline == null
                          ? null
                          : () => onDecline!(decisionId),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                      ),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('拒絕'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
