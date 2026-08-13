// mobile/lib/pages/delegation_page.dart
//
// Agent 委託頁（Phase 5）：讓使用者授權平台 Agent 在額度/時效內代為結算（release/refund）。
// 「授權」需用戶用 zkLogin 簽 issue_operator_cap → 這一步在 zkLogin 服務（Phase 0c）接上前，
// 以明確的整合點標示；「查詢/撤銷」已可運作（後端 /agent/delegation）。

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/zklogin_action_service.dart';
import '../theme/app_theme.dart';

class DelegationPage extends StatefulWidget {
  const DelegationPage({super.key});

  @override
  State<DelegationPage> createState() => _DelegationPageState();
}

class _DelegationPageState extends State<DelegationPage> {
  bool _loading = true;
  bool _busy = false;
  String? _activeCapId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.getDelegation();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _activeCapId = res['success'] == true
          ? (res['data']?['active_cap_object_id'] as String?)
          : null;
    });
  }

  // 預設委託額度（可日後做成表單讓用戶自訂）
  static const int _maxSpendMist = 1000000000; // 1 SUI / 筆
  static const int _dailyLimitMist = 5000000000; // 5 SUI / 日
  static const int _validForMs = 30 * 86400 * 1000; // 30 天
  static const int _actionsReleaseRefund = 3; // RELEASE(1) | REFUND(2)

  Future<void> _authorize() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('授權平台代為結算'),
        content: const Text(
          '您將用 zkLogin 簽署一份非託管委託（OperatorCap），授權平台 Agent 在以下上限內'
          '代您完成放款/退款：\n\n'
          '• 每筆上限：1 SUI\n'
          '• 每日上限：5 SUI\n'
          '• 有效期：30 天\n'
          '• 動作：放款 / 退款\n\n'
          '平台無法超出此範圍動用資金，您可隨時撤銷。',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('簽署授權')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    final res = await ZkLoginActionService.instance.delegate(
      maxSpendMist: _maxSpendMist,
      dailyLimitMist: _dailyLimitMist,
      validForMs: _validForMs,
      allowedActions: _actionsReleaseRefund,
    );
    if (!mounted) return;

    if (res.success && res.objectId != null) {
      // 回報鏈上 OperatorCap 物件 id 給後端記錄
      await ApiService.recordDelegation(res.objectId!);
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 已授權平台代為結算')),
      );
      _load();
    } else {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('授權失敗：${res.error}')),
      );
    }
  }

  Future<void> _revoke() async {
    setState(() => _busy = true);
    final res = await ApiService.revokeDelegation();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['success'] == true ? '✅ 已撤銷委託' : '撤銷失敗: ${res['error']}'),
    ));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('平台代結算授權')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.verified_user, color: AppColors.primary),
                              const SizedBox(width: 10),
                              const Text('委託狀態',
                                  style: TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              const Spacer(),
                              StatusPill(
                                label: _activeCapId != null ? '已授權' : '未授權',
                                color: _activeCapId != null ? AppColors.success : AppColors.textMuted,
                                icon: _activeCapId != null ? Icons.check_circle : Icons.remove_circle_outline,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _activeCapId != null
                                ? 'OperatorCap：${_activeCapId!.substring(0, 14)}…'
                                : '尚未授權平台代為結算。授權後，行程完成/取消時可由平台 Agent 在額度內自動處理放款與退款。',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_activeCapId == null)
                    ElevatedButton.icon(
                      onPressed: _busy ? null : _authorize,
                      icon: const Icon(Icons.add_moderator),
                      label: const Text('授權平台代為結算'),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _revoke,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.gpp_bad),
                      label: Text(_busy ? '處理中...' : '撤銷授權'),
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    '說明：授權是非託管的——您用自己的錢包簽發一份有額度與時效上限的委託，'
                    '平台無法超出範圍動用您的資金，且您可隨時撤銷。',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
    );
  }
}
