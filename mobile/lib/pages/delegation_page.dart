// mobile/lib/pages/delegation_page.dart
//
// Agent 委託頁：授權平台 Agent 在額度/時效內代為結算（release/refund），
// 設定「自動執行門檻」（分級權限：小額自動、大額需本人確認），並檢視 Agent 代理活動。
// 授權以 zkLogin 簽 issue_operator_cap；查詢/撤銷/設定門檻走 /agent/*。

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/zklogin_action_service.dart';
import '../theme/app_theme.dart';
import '../widgets/agent_activity_card.dart';

class DelegationPage extends StatefulWidget {
  const DelegationPage({super.key});

  @override
  State<DelegationPage> createState() => _DelegationPageState();
}

class _DelegationPageState extends State<DelegationPage> {
  bool _loading = true;
  bool _busy = false;
  String? _activeCapId;
  Map<String, dynamic>? _delegation; // 額度/時效/門檻明細
  double _thresholdSui = 1.0; // 自動執行門檻（SUI）
  List<Map<String, dynamic>> _activities = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.getDelegation();
    Map<String, dynamic>? delegation;
    String? capId;
    if (res['success'] == true) {
      final data = res['data'] as Map<String, dynamic>?;
      capId = data?['active_cap_object_id'] as String?;
      delegation = data?['delegation'] as Map<String, dynamic>?;
    }
    // 載入 Agent 活動 feed（有委託才有意義，但失敗不影響頁面）
    List<Map<String, dynamic>> activities = [];
    final act = await ApiService.getAgentActivities(limit: 20);
    if (act['success'] == true) {
      final list = (act['data']?['activities'] as List?) ?? [];
      activities = list.cast<Map<String, dynamic>>();
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _activeCapId = capId;
      _delegation = delegation;
      _activities = activities;
      final t = delegation?['auto_threshold_mist'];
      if (t != null) {
        final mist = (t is int) ? t : int.tryParse('$t') ?? 1000000000;
        _thresholdSui = (mist / 1000000000).clamp(0.0, 5.0).toDouble();
      }
    });
  }

  // 預設委託額度（授權時寫入 OperatorCap）
  static const int _maxSpendMist = 1000000000; // 1 SUI / 筆
  static const int _dailyLimitMist = 5000000000; // 5 SUI / 日
  static const int _validForMs = 30 * 86400 * 1000; // 30 天
  static const int _actionsReleaseRefund = 3; // RELEASE(1) | REFUND(2)

  static String _sui(dynamic mist) {
    final v = (mist is int) ? mist : int.tryParse('${mist ?? 0}') ?? 0;
    return (v / 1000000000).toStringAsFixed(2);
  }

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

  Future<void> _saveThreshold() async {
    setState(() => _busy = true);
    final mist = (_thresholdSui * 1000000000).round();
    final res = await ApiService.updateDelegationSettings(mist);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['success'] == true
          ? '✅ 自動門檻已設為 ${_thresholdSui.toStringAsFixed(2)} SUI'
          : '設定失敗: ${res['error']}'),
    ));
  }

  Future<void> _confirmDecision(int id) async {
    setState(() => _busy = true);
    final res = await ApiService.confirmAgentDecision(id);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['success'] == true ? '✅ 已確認，代發完成' : '確認失敗: ${res['error']}'),
    ));
    _load();
  }

  Future<void> _declineDecision(int id) async {
    setState(() => _busy = true);
    final res = await ApiService.declineAgentDecision(id);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['success'] == true ? '已拒絕此筆結算' : '操作失敗: ${res['error']}'),
    ));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('平台代結算授權')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: 20),
                  if (_activeCapId == null)
                    ElevatedButton.icon(
                      onPressed: _busy ? null : _authorize,
                      icon: const Icon(Icons.add_moderator),
                      label: const Text('授權平台代為結算'),
                    )
                  else ...[
                    _buildThresholdCard(),
                    const SizedBox(height: 20),
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
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    '說明：授權是非託管的——您用自己的錢包簽發一份有額度與時效上限的委託，'
                    '平台無法超出範圍動用您的資金，且您可隨時撤銷。',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  if (_activities.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('Agent 代理活動',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    ..._activities.map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AgentActivityCard(
                            activity: a,
                            busy: _busy,
                            onConfirm: _confirmDecision,
                            onDecline: _declineDecision,
                          ),
                        )),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    final d = _delegation;
    return Card(
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
            if (_activeCapId != null && d != null) ...[
              _kv('OperatorCap', '${_activeCapId!.substring(0, 14)}…'),
              if (d['max_spend_per_tx'] != null) _kv('每筆上限', '${_sui(d['max_spend_per_tx'])} SUI'),
              if (d['daily_limit'] != null) _kv('每日上限', '${_sui(d['daily_limit'])} SUI'),
              _kv('自動門檻', '${_sui(d['auto_threshold_mist'])} SUI'),
              if (d['valid_until'] != null) _kv('有效至', '${d['valid_until']}'.split('T').first),
            ] else
              const Text(
                '尚未授權平台代為結算。授權後，行程完成/取消時可由平台 Agent 在額度內自動處理放款與退款，省去每次手動簽名。',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThresholdCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('自動執行門檻',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(
              '金額 ≤ ${_thresholdSui.toStringAsFixed(2)} SUI 由 Agent 自動代發；'
              '超過則推播給您本人確認後才執行。',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            Slider(
              value: _thresholdSui,
              min: 0.0,
              max: 5.0,
              divisions: 50,
              label: '${_thresholdSui.toStringAsFixed(2)} SUI',
              onChanged: _busy ? null : (v) => setState(() => _thresholdSui = v),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _busy ? null : _saveThreshold,
                icon: const Icon(Icons.save, size: 18),
                label: const Text('儲存門檻'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text('$k：', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            Expanded(
              child: Text(v,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ),
          ],
        ),
      );
}
