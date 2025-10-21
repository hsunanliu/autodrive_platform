// mobile/lib/services/sui_wallet_service.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SuiWalletService {
  static const String packageId =
      '0xda64dff8b8963d5359d64b200ce43d2347d8ce5330c501e597246d46706d542f';
  static const String platformAddress =
      '0x6dfff9f4efba3579ce7db6e2f40cfb23461f2aa4e632eb477454bf8c10e0e7b7';

  /// 調用智能合約 lock_payment
  static Future<Map<String, dynamic>?> callLockPayment({
    required BuildContext context,
    required int tripId,
    required String driverAddress,
    required int amountMist,
    required int platformFeeMist,
  }) async {
    // 構建交易數據
    final transactionData = {
      'package': packageId,
      'module': 'payment_escrow',
      'function': 'lock_payment',
      'arguments': [
        'COIN_OBJECT', // 會由錢包自動選擇
        tripId.toString(),
        driverAddress,
        platformAddress,
        platformFeeMist.toString(),
      ],
      'gasBudget': '10000000',
    };

    // 打開 WebView 錢包頁面
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder:
            (context) => SuiWalletWebView(
              transactionData: transactionData,
              amountMist: amountMist,
            ),
      ),
    );

    return result;
  }
}

/// Sui 錢包 WebView 頁面
class SuiWalletWebView extends StatefulWidget {
  final Map<String, dynamic> transactionData;
  final int amountMist;

  const SuiWalletWebView({
    Key? key,
    required this.transactionData,
    required this.amountMist,
  }) : super(key: key);

  @override
  State<SuiWalletWebView> createState() => _SuiWalletWebViewState();
}

class _SuiWalletWebViewState extends State<SuiWalletWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: (url) {
                setState(() => _isLoading = false);
              },
              onWebResourceError: (error) {
                setState(() {
                  _errorMessage = error.description;
                  _isLoading = false;
                });
              },
            ),
          )
          ..addJavaScriptChannel(
            'SuiWallet',
            onMessageReceived: (JavaScriptMessage message) {
              // 接收來自 WebView 的消息
              _handleWalletMessage(message.message);
            },
          )
          ..loadHtmlString(_buildHtmlContent());
  }

  String _buildHtmlContent() {
    final txData = jsonEncode(widget.transactionData);

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Sui Wallet</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    .container {
      background: white;
      border-radius: 20px;
      padding: 30px;
      max-width: 400px;
      width: 100%;
      box-shadow: 0 20px 60px rgba(0,0,0,0.3);
    }
    h1 {
      color: #333;
      margin-bottom: 10px;
      font-size: 24px;
    }
    .subtitle {
      color: #666;
      margin-bottom: 30px;
      font-size: 14px;
    }
    .info-box {
      background: #f5f5f5;
      border-radius: 10px;
      padding: 15px;
      margin-bottom: 20px;
    }
    .info-row {
      display: flex;
      justify-content: space-between;
      margin-bottom: 10px;
      font-size: 14px;
    }
    .info-label {
      color: #666;
    }
    .info-value {
      color: #333;
      font-weight: 600;
    }
    .button {
      width: 100%;
      padding: 15px;
      border: none;
      border-radius: 10px;
      font-size: 16px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.3s;
      margin-bottom: 10px;
    }
    .button-primary {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
    }
    .button-primary:hover {
      transform: translateY(-2px);
      box-shadow: 0 10px 20px rgba(102, 126, 234, 0.4);
    }
    .button-secondary {
      background: #f5f5f5;
      color: #666;
    }
    .status {
      text-align: center;
      padding: 15px;
      border-radius: 10px;
      margin-top: 20px;
      font-size: 14px;
    }
    .status-info {
      background: #e3f2fd;
      color: #1976d2;
    }
    .status-success {
      background: #e8f5e9;
      color: #388e3c;
    }
    .status-error {
      background: #ffebee;
      color: #d32f2f;
    }
    .loading {
      text-align: center;
      color: #666;
    }
    .spinner {
      border: 3px solid #f3f3f3;
      border-top: 3px solid #667eea;
      border-radius: 50%;
      width: 40px;
      height: 40px;
      animation: spin 1s linear infinite;
      margin: 20px auto;
    }
    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>🔐 Sui 智能合約支付</h1>
    <p class="subtitle">調用 payment_escrow::lock_payment</p>
    
    <div class="info-box">
      <div class="info-row">
        <span class="info-label">行程 ID</span>
        <span class="info-value">#${widget.transactionData['arguments'][1]}</span>
      </div>
      <div class="info-row">
        <span class="info-label">支付金額</span>
        <span class="info-value">${(widget.amountMist / 1000000000).toStringAsFixed(4)} SUI</span>
      </div>
      <div class="info-row">
        <span class="info-label">合約</span>
        <span class="info-value">payment_escrow</span>
      </div>
    </div>
    
    <div id="status" class="status status-info">
      ⚠️ 目前 Slush Wallet 不支持直接從 WebView 調用
    </div>
    
    <button class="button button-primary" onclick="connectWallet()">
      連接 Sui 錢包
    </button>
    
    <button class="button button-secondary" onclick="cancel()">
      取消
    </button>
    
    <div id="loading" style="display: none;">
      <div class="spinner"></div>
      <p class="loading">處理中...</p>
    </div>
  </div>
  
  <script>
    const txData = $txData;
    
    function showStatus(message, type) {
      const status = document.getElementById('status');
      status.textContent = message;
      status.className = 'status status-' + type;
    }
    
    function showLoading(show) {
      document.getElementById('loading').style.display = show ? 'block' : 'none';
    }
    
    async function connectWallet() {
      showLoading(true);
      showStatus('🔍 檢測錢包...', 'info');
      
      try {
        // 檢查是否有 Sui 錢包
        if (typeof window.suiWallet !== 'undefined') {
          await callContract();
        } else {
          // 沒有錢包，提示用戶
          showStatus('❌ 未檢測到 Sui 錢包', 'error');
          showLoading(false);
          
          // 發送消息給 Flutter
          if (window.SuiWallet) {
            window.SuiWallet.postMessage(JSON.stringify({
              type: 'error',
              message: '未檢測到 Sui 錢包，請使用 Sui CLI 或其他方式'
            }));
          }
        }
      } catch (error) {
        showStatus('❌ 錯誤: ' + error.message, 'error');
        showLoading(false);
      }
    }
    
    async function callContract() {
      try {
        showStatus('📝 構建交易...', 'info');
        
        // 這裡應該調用 Sui Wallet API
        // 但目前 Slush Wallet 不支持 WebView 集成
        
        showStatus('⚠️ Slush Wallet 不支持 WebView 調用', 'error');
        showLoading(false);
        
        // 通知 Flutter
        if (window.SuiWallet) {
          window.SuiWallet.postMessage(JSON.stringify({
            type: 'not_supported',
            message: 'Slush Wallet 不支持 WebView 集成'
          }));
        }
      } catch (error) {
        showStatus('❌ 調用失敗: ' + error.message, 'error');
        showLoading(false);
      }
    }
    
    function cancel() {
      if (window.SuiWallet) {
        window.SuiWallet.postMessage(JSON.stringify({
          type: 'cancelled'
        }));
      }
    }
  </script>
</body>
</html>
    ''';
  }

  void _handleWalletMessage(String message) {
    try {
      final data = jsonDecode(message);

      switch (data['type']) {
        case 'success':
          Navigator.pop(context, {
            'success': true,
            'tx_hash': data['txHash'],
            'escrow_id': data['escrowId'],
          });
          break;

        case 'error':
        case 'not_supported':
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? '操作失敗'),
              backgroundColor: Colors.red,
            ),
          );
          break;

        case 'cancelled':
          Navigator.pop(context);
          break;
      }
    } catch (e) {
      print('Error handling wallet message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sui 錢包'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 60,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '載入失敗',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('返回'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
