import 'package:flutter/material.dart';

import 'services/api_service.dart';
import 'session_manager.dart';
import 'widgets/payment_dialog.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({
    super.key,
    required this.fare,
    required this.session,
    required this.startAddress,
    required this.endAddress,
    this.vehicleId,
    this.tripId,
  });

  final dynamic fare;
  final UserSession? session;
  final String startAddress;
  final String endAddress;
  final String? vehicleId;
  final int? tripId;

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
        _walletBalance =
            data['balance_sui']?.toString() ?? data['balance']?.toString();
        _statusMessage = '已更新餘額';
      } else {
        _walletBalance = null;
        _statusMessage = result['error']?.toString() ?? '查詢失敗';
      }
    });
  }

  Future<void> _processPayment() async {
    if (widget.tripId == null) {
      setState(() {
        _statusMessage = '❌ 錯誤：缺少行程 ID';
      });
      return;
    }

    // 顯示支付對話框
    final result = await showPaymentDialog(
      context,
      tripId: widget.tripId!,
      amount: widget.fare is int ? (widget.fare / 1000000.0) : 0.0,
      description: '${widget.startAddress} → ${widget.endAddress}',
    );

    if (result != null && result['success'] == true) {
      if (result['tx_hash'] != null) {
        // 有交易 hash，驗證支付
        await _verifyPayment(result['tx_hash']);
      } else {
        setState(() {
          _statusMessage = result['message'] ?? '等待支付確認...';
        });
      }
    }
  }

  Future<void> _verifyPayment(String txHash) async {
    if (widget.tripId == null) return;

    setState(() {
      _isLoading = true;
      _statusMessage = '驗證支付中...';
    });

    // 驗證交易並自動保存 escrow_object_id
    final result = await ApiService.verifyTripPayment(
      tripId: widget.tripId!,
      txHash: txHash,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _statusMessage = '✅ 支付驗證成功！司機現在可以完成行程了';
      } else {
        _statusMessage = '❌ 支付驗證失敗: ${result['error'] ?? '未知錯誤'}';
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
              child: const Text('查詢並驗證'),
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

    // 直接驗證支付，不需要先查詢狀態
    if (widget.tripId != null) {
      await _verifyPayment(hash);
    } else {
      setState(() {
        _isLoading = false;
        _statusMessage = '❌ 缺少行程 ID';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 處理金額顯示
    String fareText = '--';
    if (widget.fare != null) {
      final fareValue =
          widget.fare is int
              ? widget.fare
              : int.tryParse(widget.fare.toString());
      if (fareValue != null) {
        // 轉換為 SUI (1 SUI = 1,000,000 micro SUI)
        final suiAmount = fareValue / 1000000.0;
        fareText = suiAmount.toStringAsFixed(4);
      }
    }

    return WillPopScope(
      onWillPop: () async {
        // 確保可以返回
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          title: const Text('付款資訊'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              const SizedBox(height: 12),
              const Text(
                '應付金額',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                '$fareText SUI',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
                          child: Text(
                            widget.startAddress,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.flag, color: Colors.lightBlueAccent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.endAddress,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.vehicleId != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.directions_car, color: Colors.amber),
                          const SizedBox(width: 10),
                          Text(
                            '車輛：${widget.vehicleId}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _loadWalletBalance,
                icon: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.black,
                ),
                label: const Text(
                  '查詢錢包餘額',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB954),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _processPayment,
                icon: const Icon(Icons.payment, color: Colors.black),
                label: const Text(
                  '確認支付',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '完成支付後，請在此驗證',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _checkTransaction,
                      icon: const Icon(Icons.verified, color: Colors.white),
                      label: const Text('輸入交易 Hash 驗證'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ],
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
                    '錢包餘額：$_walletBalance SUI',
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1DB954), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.lightbulb_outline,
                          color: Color(0xFF1DB954),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '💡 支付說明',
                          style: TextStyle(
                            color: Color(0xFF1DB954),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '1. 點擊「確認支付」複製支付信息\n'
                      '2. 在 Slush Wallet 中完成轉帳\n'
                      '3. 支付完成後可以：\n'
                      '   • 立即驗證（如果能找到交易 Hash）\n'
                      '   • 稍後在「行程記錄」中驗證\n'
                      '   • 或直接等待司機確認',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade900.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '💡 提示：Slush Wallet 的交易 Hash 可能不容易找到，\n如果找不到也沒關係，可以稍後驗證',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                label: const Text('返回首頁'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E2E2E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
