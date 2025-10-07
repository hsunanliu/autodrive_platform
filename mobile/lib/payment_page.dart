import 'package:flutter/material.dart';

import 'services/api_service.dart';
import 'session_manager.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({
    super.key,
    required this.fare,
    required this.session,
    required this.startAddress,
    required this.endAddress,
    this.vehicleId,
  });

  final dynamic fare;
  final UserSession? session;
  final String startAddress;
  final String endAddress;
  final String? vehicleId;

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  bool _isLoading = false;
  String? _walletBalance;
  String? _statusMessage;

  Future<void> _loadWalletBalance() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '查詢錢包餘額...';
    });

    final result = await ApiService.getWalletBalance();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result['success'] == true && result['data'] is Map) {
        final data = result['data'] as Map<String, dynamic>;
        _walletBalance = data['balance_iota']?.toString() ?? data['balance']?.toString();
        _statusMessage = '已更新餘額';
      } else {
        _walletBalance = null;
        _statusMessage = result['error']?.toString() ?? '查詢失敗';
      }
    });
  }

  Future<void> _checkTransaction() async {
    final controller = TextEditingController();
    final hash = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('輸入交易 Hash', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: '0x...',
              hintStyle: TextStyle(color: Colors.white38),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('查詢'),
            ),
          ],
        );
      },
    );

    if (hash == null || hash.isEmpty) return;

    setState(() {
      _isLoading = true;
      _statusMessage = '查詢交易狀態...';
    });

    final result = await ApiService.getTransactionStatus(hash);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        final status = result['data'];
        _statusMessage = '交易狀態：$status';
      } else {
        _statusMessage = result['error']?.toString() ?? '查詢交易失敗';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fareText = widget.fare?.toString() ?? '--';

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('付款資訊'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            const SizedBox(height: 12),
            const Text('應付金額',
                style: TextStyle(color: Colors.white70, fontSize: 18)),
            const SizedBox(height: 8),
            Text('IOTA $fareText',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                )),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.redAccent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(widget.startAddress,
                            style: const TextStyle(color: Colors.white, fontSize: 14)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.flag, color: Colors.lightBlueAccent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(widget.endAddress,
                            style: const TextStyle(color: Colors.white, fontSize: 14)),
                      ),
                    ],
                  ),
                  if (widget.vehicleId != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.directions_car, color: Colors.amber),
                        const SizedBox(width: 10),
                        Text('車輛：${widget.vehicleId}',
                            style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ]
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _loadWalletBalance,
              icon: const Icon(Icons.account_balance_wallet, color: Colors.black),
              label: const Text('查詢錢包餘額',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _checkTransaction,
              icon: const Icon(Icons.verified, color: Colors.white),
              label: const Text('驗證交易狀態'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E2E2E),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 20),
            if (_walletBalance != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '錢包餘額：$_walletBalance IOTA',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _statusMessage!,
                  style: const TextStyle(color: Colors.white60),
                ),
              ),
            const SizedBox(height: 28),
            Text(
              '完成付款後，司機端將透過區塊鏈交易驗證收入。您可以在錢包應用內完成付款並於此確認交易狀態。',
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
