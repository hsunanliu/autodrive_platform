// mobile/lib/widgets/payment_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/sui_contract_service.dart';
import '../services/api_service.dart';

class PaymentDialog extends StatefulWidget {
  final int tripId;
  final double amount;
  final String description;

  const PaymentDialog({
    Key? key,
    required this.tripId,
    required this.amount,
    required this.description,
  }) : super(key: key);

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('確認支付'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 支付詳情
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF404040)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('行程 ID', style: TextStyle(color: Colors.white70)),
                      Text(
                        '#${widget.tripId}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF404040)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('描述', style: TextStyle(color: Colors.white70)),
                      Flexible(
                        child: Text(
                          widget.description,
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF404040)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '金額',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${widget.amount.toStringAsFixed(4)} SUI',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1DB954),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 提示信息
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3A2A1A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade700),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade400),
                      const SizedBox(width: 8),
                      Text(
                        '支付流程',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.orange.shade200,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. 點擊「確認支付」\n'
                    '2. 將打開 Slush Wallet\n'
                    '3. 在錢包中確認交易\n'
                    '4. 資金將鎖定在智能合約中',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 安全提示
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2A1A),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.green.shade700),
              ),
              child: Row(
                children: [
                  Icon(Icons.security, size: 16, color: Colors.green.shade400),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '您的私鑰永遠不會離開您的錢包',
                      style: TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isProcessing ? null : _processPayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
          ),
          child: _isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('確認支付'),
        ),
      ],
    );
  }

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);

    try {
      if (mounted) {
        setState(() => _isProcessing = false);
        
        // 顯示支付選項
        final method = await _showPaymentMethodDialog();
        
        if (method == 'wallet') {
          // 使用錢包支付（主要流程）
          await _payWithWallet();
        } else if (method == 'copy_info') {
          // 查看交易信息
          await _showCopyPaymentInfo();
        } else if (method == 'manual') {
          // 查看 CLI 指南
          await _showPaymentGuide();
          if (mounted) {
            Navigator.pop(context, {
              'success': false,
              'pending': true,
              'message': '請使用 Sui CLI 完成支付',
            });
          }
        }
      }
      
    } catch (e) {
      setState(() => _isProcessing = false);
      _showError('支付失敗: $e');
    }
  }
  
  Future<void> _payWithWallet() async {
    try {
      // TODO: 從後端獲取司機地址和平台費用
      // 這裡先使用模擬數據
      const driverAddress = '0x0000000000000000000000000000000000000000000000000000000000000000';
      final amountMist = (widget.amount * 1000000000).toInt();
      final platformFeeMist = (amountMist * 0.1).toInt(); // 10% 平台費用
      
      final result = await SuiContractService.callLockPayment(
        context: context,
        tripId: widget.tripId,
        driverAddress: driverAddress,
        amountMist: amountMist,
        platformFeeMist: platformFeeMist,
      );
      
      if (result != null && result['success'] == true) {
        if (mounted) {
          Navigator.pop(context, result);
        }
      }
    } catch (e) {
      _showError('錢包調用失敗: $e');
    }
  }
  
  Future<String?> _showPaymentMethodDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('選擇支付方式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A3A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade700),
              ),
              child: const Text(
                '💡 完成支付後，可以稍後在「行程記錄」中驗證',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet, color: Colors.blue),
              title: const Text('使用 Sui 錢包支付'),
              subtitle: const Text('調用智能合約 lock_payment（推薦）'),
              onTap: () => Navigator.pop(context, 'wallet'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.orange),
              title: const Text('查看交易信息'),
              subtitle: const Text('查看合約調用詳情'),
              onTap: () => Navigator.pop(context, 'copy_info'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.terminal, color: Colors.grey),
              title: const Text('使用 Sui CLI'),
              subtitle: const Text('適合開發測試'),
              onTap: () => Navigator.pop(context, 'manual'),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _showCopyPaymentInfo() async {
    // 獲取臨時託管地址
    setState(() => _isProcessing = true);
    final tempAddressResult = await ApiService.getTempEscrowAddress();
    setState(() => _isProcessing = false);
    
    if (!mounted) return;
    
    final tempAddress = tempAddressResult['data']?['address'] ?? '0x6dfff9f4efba3579ce7db6e2f40cfb23461f2aa4e632eb477454bf8c10e0e7b7';
    const packageId = '0xda64dff8b8963d5359d64b200ce43d2347d8ce5330c501e597246d46706d542f';
    
    // 構建交易數據（用於調用 lock_payment）
    final transactionData = {
      'package': packageId,
      'module': 'payment_escrow',
      'function': 'lock_payment',
      'arguments': {
        'payment': 'COIN_OBJECT', // 需要用戶選擇 coin
        'trip_id': widget.tripId.toString(),
        'driver': 'DRIVER_ADDRESS', // 需要從後端獲取
        'platform': '0x6dfff9f4efba3579ce7db6e2f40cfb23461f2aa4e632eb477454bf8c10e0e7b7',
        'platform_fee': '0', // 需要從後端獲取
      },
      'gas_budget': '10000000',
    };
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.payment, color: Colors.blue),
            SizedBox(width: 8),
            Text('調用智能合約支付'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A3A4A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade700),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '⚠️ 重要提示',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '支付需要調用智能合約的 lock_payment 函數，'
                      '不是簡單的轉帳！',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              const Text(
                '交易信息：',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              
              // 合約包
              _buildCopyField(
                '合約包',
                '${packageId.substring(0, 10)}...${packageId.substring(packageId.length - 8)}',
                packageId,
              ),
              const SizedBox(height: 8),
              
              // 函數
              _buildInfoField('函數', 'payment_escrow::lock_payment'),
              const SizedBox(height: 8),
              
              // 金額
              _buildInfoField('金額', '${widget.amount.toStringAsFixed(4)} SUI'),
              const SizedBox(height: 8),
              
              // 行程 ID
              _buildInfoField('行程 ID', '#${widget.tripId}'),
              
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A2A1A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade700),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📝 使用 Sui CLI 測試：',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade200,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '由於 Slush Wallet 目前不支持直接調用合約，\n'
                      '建議使用 Sui CLI 進行測試：',
                      style: TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SelectableText(
                        'sui client call --package \$packageId \\\n'
                        '  --module payment_escrow \\\n'
                        '  --function lock_payment \\\n'
                        '  --args <coin_id> ${widget.tripId} \\\n'
                        '    <driver_address> \\\n'
                        '    <platform_address> \\\n'
                        '    <platform_fee> \\\n'
                        '  --gas-budget 10000000',
                        style: const TextStyle(
                          fontSize: 9,
                          fontFamily: 'monospace',
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2A3A),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue.shade700),
                ),
                child: const Text(
                  '💡 提示：完整的錢包集成正在開發中。\n'
                  '目前建議使用 Sui CLI 或等待錢包集成完成。',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, {
                'success': false,
                'pending': true,
                'message': '請使用 Sui CLI 調用智能合約\n或等待錢包集成完成',
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoField(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF404040)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCopyField(String label, String displayValue, String copyValue) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF404040)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: copyValue));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已複製 $label'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        '複製',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            displayValue,
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _showPaymentGuide() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet, color: Colors.blue),
            SizedBox(width: 8),
            Text('在 Slush Wallet 中支付'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '支付信息',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    Text('金額: ${widget.amount.toStringAsFixed(4)} SUI'),
                    Text('行程 ID: #${widget.tripId}'),
                    Text('描述: ${widget.description}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '請按照以下步驟操作：',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildStep('1', '打開 Slush Wallet 應用'),
              _buildStep('2', '確保連接到 Testnet'),
              _buildStep('3', '點擊「發送」或「Send」'),
              _buildStep('4', '輸入上方的金額'),
              _buildStep('5', '輸入智能合約地址（見下方）'),
              _buildStep('6', '確認並簽署交易'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '智能合約地址:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            const address = '0xda64dff8b8963d5359d64b200ce43d2347d8ce5330c501e597246d46706d542f';
                            Clipboard.setData(const ClipboardData(text: address));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('已複製地址'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: const Icon(Icons.copy, size: 16, color: Colors.blue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const SelectableText(
                      '0xda64dff8b8963d5359d64b200ce43d2347d8ce5330c501e597246d46706d542f',
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
  


  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

/// 顯示支付對話框的輔助函數
Future<Map<String, dynamic>?> showPaymentDialog(
  BuildContext context, {
  required int tripId,
  required double amount,
  required String description,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PaymentDialog(
      tripId: tripId,
      amount: amount,
      description: description,
    ),
  );
}
