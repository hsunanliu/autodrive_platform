# Slush Wallet 整合分析報告

**文檔版本**: v1.0
**建立日期**: 2025-10-27
**專案**: AutoDrive - 去中心化叫車平台
**區塊鏈**: Sui Blockchain (Testnet)

---

## 📋 執行摘要

本文檔分析 AutoDrive 專案中 Slush Wallet (Suiet Wallet) 的整合現狀、技術架構、存在問題與改進建議。

### 關鍵發現
- ✅ **已實作**: Deep Link 連接方案、手動錢包地址輸入
- ⚠️ **限制**: WebView 方案不可行、缺少真實 WalletConnect 整合
- 🔧 **建議**: 採用 Slush Mobile SDK 或改用模擬支付流程

---

## 🏗️ 現有架構分析

### 1. 錢包整合服務總覽

專案中包含三個錢包服務層：

```
mobile/lib/services/
├── sui_wallet_connector.dart      # Deep Link 方案 (主要)
├── wallet_connect_service.dart    # WalletConnect v2 (未完成)
└── sui_wallet_service.dart        # WebView 方案 (不可行)
```

---

## 📁 詳細檔案分析

### 1.1 `sui_wallet_connector.dart` - Deep Link 方案

**狀態**: ✅ 已實作，可用於註冊流程

#### 核心功能
```dart
class SuiWalletConnector extends ChangeNotifier {
  // 功能列表:
  // 1. 連接錢包 (connectWallet)
  // 2. 手動設置地址 (setWalletAddress)
  // 3. 查詢餘額 (getBalance)
  // 4. 簽署交易 (signTransaction)
  // 5. 處理回調 (handleWalletCallback)
  // 6. 獲取交易歷史 (getTransactionHistory)
}
```

#### Deep Link 格式
```
連接錢包:
  suiet://connect?callback=autodrive%3A%2F%2Fwallet-callback

簽署交易:
  suiet://sign?data=<base64>&callback=autodrive%3A%2F%2Fsign-callback

回調格式:
  autodrive://wallet-callback?address=0x...
  autodrive://sign-callback?signature=...&digest=...
```

#### 優點
- ✅ 符合 Sui 錢包標準 Deep Link 協議
- ✅ 支援跨應用跳轉
- ✅ 安全性高（用戶在原生錢包 App 中簽署）

#### 缺點
- ❌ 需要用戶安裝 Suiet 移動應用
- ❌ 跳轉流程較長（AutoDrive → Suiet → AutoDrive）
- ❌ 回調處理需要配置 URL Scheme

#### 使用位置
- `register_with_wallet_connect_page.dart:392-418` - 註冊流程中的錢包連接

---

### 1.2 `wallet_connect_service.dart` - WalletConnect v2

**狀態**: ⚠️ 未完成，缺少 Project ID

#### 依賴
```yaml
# pubspec.yaml:22
walletconnect_flutter_v2: ^2.1.0
qr_flutter: ^4.1.0
```

#### 核心配置
```dart
_web3App = await Web3App.createInstance(
  projectId: 'YOUR_PROJECT_ID', // ❌ 需要從 WalletConnect Cloud 獲取
  metadata: const PairingMetadata(
    name: 'AutoDrive',
    description: 'Decentralized Ride Hailing on Sui',
    url: 'https://autodrive.app',
    icons: ['https://autodrive.app/icon.png'],
  ),
);
```

#### 支援的操作
```dart
requiredNamespaces: {
  'sui': const RequiredNamespace(
    chains: ['sui:testnet'],
    methods: [
      'sui_signAndExecuteTransactionBlock',
      'sui_signTransactionBlock',
    ],
    events: ['accountsChanged', 'chainChanged'],
  ),
}
```

#### 優點
- ✅ 行業標準協議
- ✅ 支援 QR Code 掃描
- ✅ 支援多種錢包

#### 缺點
- ❌ **未配置 Project ID**（需註冊 WalletConnect Cloud）
- ❌ Slush Wallet 對 WalletConnect 的支援尚未確認
- ❌ 需要額外的 Session 管理

---

### 1.3 `sui_wallet_service.dart` - WebView 方案

**狀態**: ❌ 不可行

#### 依賴
```yaml
# pubspec.yaml:27
webview_flutter: ^4.4.2
```

#### 問題分析

**代碼中的明確提示**:
```dart
// Line 248-249
<div id="status" class="status status-info">
  ⚠️ 目前 Slush Wallet 不支持直接從 WebView 調用
</div>

// Line 312
showStatus('⚠️ Slush Wallet 不支持 WebView 調用', 'error');
```

**技術原因**:
1. **安全性限制**: 錢包不會將私鑰暴露給 WebView
2. **瀏覽器 API 缺失**: 移動 WebView 無法訪問 `window.suiWallet`
3. **跨應用隔離**: 錢包擴展無法注入到移動 WebView

#### 結論
WebView 方案僅適用於桌面瀏覽器環境，移動應用應棄用此方案。

---

## 🔧 註冊流程整合分析

### 使用文件
`register_with_wallet_connect_page.dart`

### 三步驟流程

#### Step 1: 基本信息 (lines 87-130)
```dart
- 用戶名 (username)
- 郵箱 (email)
- 用戶類型 (user_type): passenger / driver / both
```

#### Step 2: 連接錢包 (lines 133-269)
**兩種方式**:

1️⃣ **Deep Link 連接 Suiet**
```dart
ElevatedButton.icon(
  onPressed: _connectWallet,
  icon: const Icon(Icons.account_balance_wallet),
  label: const Text('連接 Suiet Wallet'),
)

// 實作 (line 392)
final result = await _walletConnector.connectWallet();
```

2️⃣ **手動輸入錢包地址**
```dart
TextField(
  controller: _walletAddressController,
  decoration: const InputDecoration(
    labelText: '錢包地址',
    hintText: '0x...',
  ),
  onChanged: (value) {
    if (value.startsWith('0x') && value.length == 66) {
      setState(() => _connectedWalletAddress = value);
    }
  },
)
```

#### Step 3: 設置密碼 (lines 272-326)
```dart
- 密碼 (至少 8 字符)
- 確認密碼
- 提示: "此密碼用於登入平台，與您的錢包密碼無關"
```

### 驗證流程

#### 用戶名檢查 (lines 344-360)
```dart
final checkResult = await ApiService.checkUsername(
  _usernameController.text.trim(),
);

if (data['available'] != true) {
  _showError('用戶名已被使用，請換一個');
  return;
}
```

#### 密碼驗證 (lines 373-380)
```dart
if (_passwordController.text.length < 8) {
  _showError('密碼至少需要 8 個字符');
  return;
}

if (_passwordController.text != _confirmPasswordController.text) {
  _showError('兩次輸入的密碼不一致');
  return;
}
```

### 註冊與登入 (lines 420-495)

```dart
// 1. 註冊
final registerResult = await ApiService.registerUser(
  username: _usernameController.text.trim(),
  password: _passwordController.text,
  walletAddress: _connectedWalletAddress!,
  email: _emailController.text.trim(),
  userType: _userType,
);

// 2. 自動登入
final loginResult = await ApiService.loginUser(
  identifier: _usernameController.text.trim(),
  password: _passwordController.text,
);

// 3. 保存 Session
final session = UserSession(
  userId: userData['id'],
  username: userData['username'],
  role: _userType,
  accessToken: loginResult['data']['access_token'],
  walletAddress: _connectedWalletAddress,
  phoneNumber: userData['phone_number'],
  email: _emailController.text.trim(),
);

await SessionManager.saveSession(session);

// 4. 導航到主頁
if (_userType == 'driver') {
  Navigator.pushReplacementNamed(context, '/driver', arguments: {'session': session});
} else {
  Navigator.pushReplacementNamed(context, '/passenger', arguments: {'session': session});
}
```

---

## 💳 支付流程分析

### 現狀
目前專案**未使用真實區塊鏈支付**，採用**模擬支付流程**。

### 相關檔案

#### `one_click_payment_dialog.dart`
```dart
// 模擬交易 hash
final mockTxHash = 'mock_tx_${DateTime.now().millisecondsSinceEpoch}';

// 調用後端 API
final result = await ApiService.completeTrip(
  tripId: widget.tripId,
  txHash: mockTxHash,
);
```

### 真實支付所需步驟

如果要整合真實 Sui 支付，需要:

1. **構建交易**
```dart
final transactionData = {
  'package': '0xda64...542f',
  'module': 'payment_escrow',
  'function': 'lock_payment',
  'arguments': [
    coinObjectId,      // 用戶的 SUI coin object
    tripId.toString(),
    driverAddress,
    platformAddress,
    platformFeeMist.toString(),
  ],
  'gasBudget': '10000000',
};
```

2. **請求簽署**
```dart
// 使用 sui_wallet_connector.dart
final signResult = await walletConnector.signTransaction(
  transactionData: transactionData,
);

// Deep Link 跳轉到 Suiet Wallet
// 用戶簽署後返回 signature + digest
```

3. **提交交易**
```dart
// 調用 Sui RPC
final response = await http.post(
  Uri.parse('https://fullnode.testnet.sui.io:443'),
  body: jsonEncode({
    'jsonrpc': '2.0',
    'method': 'sui_executeTransactionBlock',
    'params': [txBytes, signature, options],
  }),
);
```

---

## 🚨 問題與限制

### 1. Deep Link 回調未實作
**問題**: `sui_wallet_connector.dart` 定義了回調處理邏輯，但專案缺少 URL Scheme 配置。

**影響**: 用戶在 Suiet 中授權後，無法自動返回 AutoDrive。

**解決方案**:
```xml
<!-- iOS: ios/Runner/Info.plist -->
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>autodrive</string>
    </array>
  </dict>
</array>

<!-- Android: android/app/src/main/AndroidManifest.xml -->
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="autodrive" android:host="wallet-callback" />
  <data android:scheme="autodrive" android:host="sign-callback" />
</intent-filter>
```

### 2. WalletConnect Project ID 缺失
**問題**: `wallet_connect_service.dart:21` 硬編碼 `'YOUR_PROJECT_ID'`

**影響**: WalletConnect 功能完全無法使用

**解決方案**:
1. 前往 https://cloud.walletconnect.com 註冊
2. 創建專案獲取 Project ID
3. 替換代碼中的佔位符

### 3. 依賴未使用
**問題**: `qr_flutter: ^4.1.0` 已安裝但未在任何文件中使用

**影響**: 增加 App 體積

**建議**: 如果不打算實作 QR Code 掃描連接，可移除此依賴

### 4. 錢包地址驗證不足
**問題**: 僅檢查 `startsWith('0x') && length == 66`

**風險**: 用戶可能輸入格式正確但無效的地址

**建議**: 添加 checksum 驗證或調用 Sui RPC 檢查地址有效性

---

## 🎯 改進建議

### 優先級 1: 完成 Deep Link 整合

#### 任務清單
- [ ] 配置 iOS URL Scheme
- [ ] 配置 Android Intent Filter
- [ ] 實作 Deep Link 監聽器 (`main.dart`)
- [ ] 測試跳轉流程
- [ ] 處理回調錯誤情況

#### 參考代碼
```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 監聽 Deep Link
  getInitialUri().then((uri) {
    if (uri != null) {
      handleDeepLink(uri);
    }
  });

  uriLinkStream.listen((Uri? uri) {
    if (uri != null) {
      handleDeepLink(uri);
    }
  });

  runApp(MyApp());
}

void handleDeepLink(Uri uri) {
  if (uri.host == 'wallet-callback') {
    // 處理錢包連接回調
    final address = uri.queryParameters['address'];
    walletConnector.handleWalletCallback(uri);
  } else if (uri.host == 'sign-callback') {
    // 處理簽署回調
    final signature = uri.queryParameters['signature'];
    final digest = uri.queryParameters['digest'];
    walletConnector.handleWalletCallback(uri);
  }
}
```

### 優先級 2: 錢包地址驗證強化

```dart
Future<bool> validateSuiAddress(String address) async {
  // 1. 格式檢查
  if (!address.startsWith('0x') || address.length != 66) {
    return false;
  }

  // 2. Hex 字符檢查
  final hexPattern = RegExp(r'^0x[0-9a-fA-F]{64}$');
  if (!hexPattern.hasMatch(address)) {
    return false;
  }

  // 3. 調用 RPC 驗證地址存在
  try {
    final response = await http.post(
      Uri.parse('https://fullnode.testnet.sui.io:443'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'suix_getBalance',
        'params': [address],
      }),
    );

    final data = jsonDecode(response.body);
    return data['result'] != null;
  } catch (e) {
    return false;
  }
}
```

### 優先級 3: 實作真實支付流程

如果要替換模擬支付:

#### 步驟 1: 修改 `one_click_payment_dialog.dart`
```dart
Future<void> _completePayment() async {
  setState(() => _isProcessing = true);

  try {
    // 1. 構建交易
    final txData = {
      'package': SuiWalletService.packageId,
      'module': 'payment_escrow',
      'function': 'lock_payment',
      'arguments': [
        // 需要獲取用戶的 coin object
        await _getUserCoinObject(widget.amountSui),
        widget.tripId.toString(),
        widget.driverAddress,
        SuiWalletService.platformAddress,
        widget.platformFeeSui.toString(),
      ],
      'gasBudget': '10000000',
    };

    // 2. 請求簽署
    final walletConnector = SuiWalletConnector();
    final signResult = await walletConnector.signTransaction(
      transactionData: txData,
    );

    if (signResult['success'] == true && signResult['pending'] == true) {
      // 等待用戶在 Suiet 中簽署
      _showInfo('請在 Suiet Wallet 中確認交易');
      // 需要監聽 Deep Link 回調獲取簽署結果
    }

  } catch (e) {
    _showError('支付失敗: $e');
  } finally {
    setState(() => _isProcessing = false);
  }
}
```

#### 步驟 2: 獲取 Coin Object
```dart
Future<String> _getUserCoinObject(double amountSui) async {
  final amountMist = (amountSui * 1000000000).toInt();

  final response = await http.post(
    Uri.parse('https://fullnode.testnet.sui.io:443'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'suix_getCoins',
      'params': [
        walletAddress,
        '0x2::sui::SUI',
        null,
        100,
      ],
    }),
  );

  final data = jsonDecode(response.body);
  final coins = data['result']['data'] as List;

  // 找到餘額足夠的 coin
  for (var coin in coins) {
    if (int.parse(coin['balance']) >= amountMist) {
      return coin['coinObjectId'];
    }
  }

  throw Exception('餘額不足');
}
```

### 優先級 4: 改善用戶體驗

#### 1. 添加錢包狀態指示器
```dart
// 在註冊頁面顯示錢包連接狀態
Container(
  child: Row(
    children: [
      Icon(
        _walletConnector.isConnected
          ? Icons.check_circle
          : Icons.cancel,
        color: _walletConnector.isConnected
          ? Colors.green
          : Colors.red,
      ),
      Text(_walletConnector.isConnected
        ? '錢包已連接'
        : '錢包未連接'
      ),
    ],
  ),
)
```

#### 2. 添加餘額檢查
```dart
// 在支付前檢查餘額
Future<bool> _checkBalance() async {
  final balanceResult = await walletConnector.getBalance();

  if (balanceResult['success'] == true) {
    final balanceSui = balanceResult['balance_sui'];
    if (balanceSui < widget.amountSui) {
      _showError('餘額不足，需要 ${widget.amountSui} SUI，當前餘額 $balanceSui SUI');
      return false;
    }
    return true;
  }

  return false;
}
```

#### 3. 添加交易狀態追蹤
```dart
// 顯示交易進度
enum PaymentStatus {
  idle,
  building,
  signing,
  submitting,
  confirming,
  completed,
  failed,
}

PaymentStatus _paymentStatus = PaymentStatus.idle;

Widget _buildStatusIndicator() {
  return Column(
    children: [
      CircularProgressIndicator(),
      Text(_getStatusText()),
    ],
  );
}

String _getStatusText() {
  switch (_paymentStatus) {
    case PaymentStatus.building:
      return '正在構建交易...';
    case PaymentStatus.signing:
      return '等待簽署...';
    case PaymentStatus.submitting:
      return '提交交易中...';
    case PaymentStatus.confirming:
      return '等待確認...';
    case PaymentStatus.completed:
      return '支付完成！';
    case PaymentStatus.failed:
      return '支付失敗';
    default:
      return '準備中';
  }
}
```

---

## 🔐 安全性建議

### 1. 永不儲存私鑰
✅ 目前專案**未儲存私鑰**，僅儲存錢包地址，符合安全最佳實踐。

### 2. 驗證交易結果
```dart
// 不要僅依賴前端返回的交易 hash
// 需要調用 Sui RPC 驗證交易確實成功

Future<bool> verifyTransaction(String txDigest) async {
  final response = await http.post(
    Uri.parse('https://fullnode.testnet.sui.io:443'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'sui_getTransactionBlock',
      'params': [
        txDigest,
        {'showEffects': true},
      ],
    }),
  );

  final data = jsonDecode(response.body);
  final status = data['result']?['effects']?['status']?['status'];

  return status == 'success';
}
```

### 3. 後端二次驗證
```python
# backend/app/api/endpoints/payment.py

@router.post("/verify-payment")
async def verify_payment(tx_hash: str, trip_id: int):
    # 1. 調用 Sui RPC 獲取交易詳情
    tx_data = await sui_client.get_transaction(tx_hash)

    # 2. 驗證交易狀態
    if tx_data['effects']['status']['status'] != 'success':
        raise HTTPException(400, "Transaction failed")

    # 3. 驗證交易參數 (trip_id, amount, 等)
    events = tx_data['effects']['events']
    # ... 解析事件驗證參數

    # 4. 更新數據庫
    trip = await db.query(Trip).filter(Trip.trip_id == trip_id).first()
    trip.tx_hash = tx_hash
    trip.status = 'paid'
    await db.commit()

    return {'success': True}
```

---

## 📊 替代方案比較

| 方案 | 優點 | 缺點 | 適用場景 |
|------|------|------|----------|
| **Deep Link** | 安全性高、符合標準 | 跳轉流程長、需要配置 | 生產環境 |
| **WalletConnect** | 支援多種錢包、QR Code 方便 | 需要 Project ID、Session 管理複雜 | Web3 標準整合 |
| **WebView** | 整合簡單 | **Slush 不支援**、安全性差 | ❌ 不推薦 |
| **模擬支付** | 開發快速、無需錢包 | 非真實區塊鏈交易 | 測試環境 |
| **Slush SDK** | 原生整合、體驗最佳 | 需要 SDK 文檔、可能付費 | 最佳選擇（如果有 SDK） |

---

## 🎯 推薦實施路線

### 短期 (1-2 週)
1. ✅ 保持現有模擬支付（已完成）
2. ✅ 完善手動輸入錢包地址功能（已完成）
3. 🔧 添加錢包地址驗證
4. 🔧 完成 Deep Link 配置

### 中期 (1 個月)
1. 🔍 調研 Slush Wallet 是否提供 Mobile SDK
2. 📝 如有 SDK，參考文檔完整整合
3. 🧪 實作真實支付流程（小額測試）
4. 🔐 添加後端交易驗證

### 長期 (2-3 個月)
1. 🌐 整合 WalletConnect v2 支援更多錢包
2. 📱 優化支付 UI/UX
3. 🔔 添加交易通知
4. 🚀 主網上線準備

---

## 📚 相關資源

### 官方文檔
- **Sui 文檔**: https://docs.sui.io
- **Sui JSON-RPC**: https://docs.sui.io/sui-api-ref
- **WalletConnect**: https://docs.walletconnect.com
- **Suiet Wallet**: https://suiet.app

### 技術規範
- **Sui Address 格式**: 0x + 64 hex 字符
- **MIST 單位**: 1 SUI = 10^9 MIST
- **Testnet RPC**: https://fullnode.testnet.sui.io:443
- **Explorer**: https://suiexplorer.com

### 專案內部文檔
- `PROJECT_OVERVIEW.md` - 專案總覽
- `contracts/docs/api/contract_apis.md` - 智能合約 API
- `backend/app/services/sui_service.py` - 後端 Sui 整合

---

## 🔍 結論

AutoDrive 專案的 Slush Wallet 整合**基礎架構已完成**，但存在以下核心問題需要解決：

### ✅ 已完成
- Deep Link 連接邏輯
- 手動輸入錢包地址
- 模擬支付流程
- Session 管理

### ⚠️ 待完成
1. **URL Scheme 配置** - 實現 Deep Link 回調
2. **WalletConnect Project ID** - 啟用 WalletConnect 功能
3. **真實支付流程** - 替換模擬交易
4. **錢包地址驗證** - 強化安全性

### 🎯 建議優先級
1. **優先**: 完成 Deep Link 配置 → 實現完整連接流程
2. **次要**: 添加錢包驗證 → 提升用戶體驗
3. **可選**: 整合真實支付 → 依專案時程決定

### 📌 最終建議
目前**模擬支付方案已足夠支援開發與測試**，建議先專注於應用核心功能完善，待用戶體驗優化後再逐步過渡到真實區塊鏈支付。

---

**文檔結束**
**撰寫者**: Claude Code
**最後更新**: 2025-10-27
