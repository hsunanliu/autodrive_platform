# 🔐 無私鑰錢包解決方案

## 問題說明

您使用的是 **zkLogin 或無私鑰錢包**（如 Sui Wallet），無法直接匯出私鑰來配置後端服務。

## 📍 退款按鈕位置

### Flutter 應用中的退款按鈕

**文件位置**: `mobile/lib/trip_history_page.dart`

**行號**: 420-436

```dart
// 退款按鈕（只有 completed 狀態的行程才顯示）
if (status == 'completed' && onRefund != null) ...[
  const SizedBox(height: 16),
  SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: onRefund,
      icon: const Icon(Icons.money_off, size: 18),
      label: const Text('申請退款'),  // ← 這就是退款按鈕！
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.orange,
        side: const BorderSide(color: Colors.orange),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    ),
  ),
],
```

### 退款按鈕顯示條件

退款按鈕會顯示在：
1. **行程歷史頁面** (`TripHistoryPage`)
2. **行程狀態為 `completed`** (已完成)
3. **每個行程卡片的底部**

### 使用流程

1. 用戶打開應用
2. 進入「行程歷史」頁面
3. 找到已完成的行程
4. 看到橙色的「申請退款」按鈕
5. 點擊按鈕打開退款對話框
6. 填寫退款金額和原因（至少 10 個字）
7. 提交退款申請

---

## 💡 解決方案

### 方案 1: 創建測試錢包（推薦用於開發測試）

使用 Sui CLI 創建一個有私鑰的測試錢包，專門用於後端操作。

#### 步驟 1: 運行腳本

```bash
cd /Users/hsuanliu/autodrive_platform/contracts
chmod +x create_test_wallet.sh
./create_test_wallet.sh
```

#### 步驟 2: 更新 .env

腳本會自動生成測試錢包信息，並保存到 `test_wallet_info.txt`。

將信息複製到 `.env` 文件：

```bash
PLATFORM_WALLET_ADDRESS=0x... (新生成的地址)
OPERATOR_PRIVATE_KEY=suiprivkey1... (新生成的私鑰)
```

#### 步驟 3: 從 Faucet 獲取測試 SUI

```bash
sui client faucet
# 或訪問: https://faucet.testnet.sui.io/
```

#### ⚠️ 注意事項

- 這個錢包**僅用於開發測試**
- 不要在生產環境使用
- 不要向這個地址轉入真實資金

---

### 方案 2: 使用改進的 Move 合約（推薦用於生產環境）

我已經創建了 `refund_module_v2.move`，支持**用戶直接發起退款**，不需要平台私鑰。

#### 新合約的優勢

1. **用戶自主**: 用戶用自己的錢包發起退款請求
2. **無需私鑰**: 平台不需要在後端存儲私鑰
3. **更安全**: 符合 Web3 的去中心化理念

#### 工作流程

```
用戶（用自己的錢包）
    ↓
調用: create_refund_request(trip_id, amount, reason)
    ↓
鏈上創建 RefundRequest 對象
    ↓
用戶提交到退款池: submit_for_auto_refund(request, pool)
    ↓
資金自動從退款池轉到用戶錢包
    ↓
完成！
```

#### 部署新合約

```bash
cd /Users/hsuanliu/autodrive_platform/contracts

# 1. 編譯合約
sui move build

# 2. 部署合約
sui client publish --gas-budget 100000000

# 3. 記錄新的 Package ID
# 從輸出中找到: Published Objects -> packageId

# 4. 更新 .env
echo "CONTRACT_PACKAGE_ID_V2=<新的 Package ID>" >> ../.env
```

#### 整合到 Flutter 應用

需要在 Flutter 應用中整合 Sui Wallet 連接：

```dart
// 未來整合（需要添加 Sui Dart SDK）
import 'package:sui/sui.dart';

// 用戶點擊退款按鈕後
Future<void> createRefundOnChain() async {
  // 1. 連接用戶錢包
  final wallet = await SuiWallet.connect();

  // 2. 構建交易
  final tx = TransactionBlock();
  tx.moveCall(
    target: '$packageId::refund_module_v2::create_refund_request',
    arguments: [tripId, originalAmount, refundAmount, reason],
  );

  // 3. 用戶簽署並執行
  final result = await wallet.signAndExecuteTransactionBlock(tx);

  // 4. 記錄到後端
  await ApiService.recordRefundRequest(tripId, result.digest);
}
```

---

### 方案 3: 繼續使用資料庫模式（最簡單）

如果暫時不需要真正的鏈上退款，可以繼續使用當前的系統：

#### 優點
- ✅ 無需任何額外配置
- ✅ 退款按鈕已經存在且可用
- ✅ 所有數據都會被記錄
- ✅ 可以在後台管理界面查看和處理

#### 工作流程
1. 用戶點擊「申請退款」按鈕
2. 提交退款原因和金額
3. 後端記錄到資料庫（狀態: `pending_blockchain`）
4. 管理員在後台審核
5. 手動處理退款或等待鏈上集成完成

#### 查看退款記錄

在後台管理界面（Dashboard）中：
- 導航到「退款管理」
- 查看所有退款請求
- 查看狀態、金額、原因等信息

---

## 🎯 推薦方案對比

| 方案 | 適用場景 | 優點 | 缺點 | 難度 |
|------|---------|------|------|------|
| **方案 1: 測試錢包** | 開發測試 | 快速上手，立即可用 | 僅用於測試 | ⭐ 簡單 |
| **方案 2: V2 合約** | 生產環境 | 更安全，去中心化 | 需要前端整合 | ⭐⭐⭐ 中等 |
| **方案 3: 資料庫模式** | MVP 快速驗證 | 零配置，立即可用 | 非真正鏈上 | ⭐ 最簡單 |

---

## 📱 如何找到退款按鈕

### 在應用中的位置

1. **主頁** → 點擊個人資料/設置
2. **行程歷史** 或 **訂單中心**
3. 找到 **已完成** 的行程
4. 在行程卡片底部看到 **橙色「申請退款」按鈕**

### UI 示意

```
┌─────────────────────────────────┐
│ 行程 #123                    ✅ │  ← 行程卡片
│                                 │
│ 📍 起點: 台北車站              │
│ 🎯 終點: 松山機場              │
│ 💰 總金額: 1.2345 SUI          │
│    ≈ $3.25 USD                 │
│                                 │
│ ┌───────────────────────────┐  │
│ │  💸 申請退款               │  │  ← 這就是退款按鈕！
│ └───────────────────────────┘  │
└─────────────────────────────────┘
```

### 按鈕樣式

- 🎨 **顏色**: 橙色邊框和文字
- 📐 **類型**: OutlinedButton (輪廓按鈕)
- 🔤 **文字**: "申請退款"
- 🎭 **圖標**: money_off (禁止貨幣圖標)

---

## 🔧 快速開始（方案 1）

如果您想立即測試退款功能：

```bash
# 1. 創建測試錢包
cd /Users/hsuanliu/autodrive_platform/contracts
chmod +x create_test_wallet.sh
./create_test_wallet.sh

# 2. 初始化退款池
chmod +x init_refund_pool.sh
./init_refund_pool.sh

# 3. 向退款池注資 10 SUI (可選)
# 按照腳本提示操作

# 4. 重啟後端
cd ../backend
docker-compose restart backend

# 5. 測試退款功能
# 在 Flutter 應用中找到已完成的行程
# 點擊「申請退款」按鈕
# 填寫信息並提交
```

---

## ❓ 常見問題

**Q: 為什麼需要平台私鑰？**

A: 目前的 Move 合約設計中，退款需要平台簽署。但使用 V2 合約可以避免這個問題。

**Q: 無私鑰錢包能用來做什麼？**

A:
- ✅ 部署合約
- ✅ 初始化退款池
- ✅ 向退款池注資
- ❌ 無法在後端自動簽署交易（需要用戶互動）

**Q: 如果不配置私鑰會怎樣？**

A: 系統會自動降級到「資料庫記錄模式」：
- 退款按鈕仍然可用
- 數據會被記錄
- 但不會真正執行鏈上轉帳
- 可以後續手動處理

**Q: 測試錢包安全嗎？**

A:
- ✅ 用於 testnet 開發測試：安全
- ❌ 用於 mainnet 生產環境：**不安全**
- 建議生產環境使用方案 2（V2 合約）

**Q: V2 合約什麼時候整合？**

A:
1. 合約已經寫好（`refund_module_v2.move`）
2. 需要部署到鏈上
3. 需要在 Flutter 應用中整合 Sui Wallet 連接
4. 預計需要 1-2 天開發時間

---

## 📚 相關文件

- **退款按鈕**: `mobile/lib/trip_history_page.dart` (行 420-436)
- **退款對話框**: `mobile/lib/trip_history_page.dart` (行 125-318)
- **API 調用**: `mobile/lib/services/api_service.dart` (行 655-680)
- **後端服務**: `backend/app/services/refund_service_v2.py`
- **Move 合約 V1**: `contracts/sources/financial/refund_module.move`
- **Move 合約 V2**: `contracts/sources/financial/refund_module_v2.move`
- **測試錢包腳本**: `contracts/create_test_wallet.sh`
- **退款池初始化**: `contracts/init_refund_pool.sh`

---

## 🎉 總結

您有 3 個選擇：

1. **立即測試** → 使用方案 1（測試錢包）
2. **生產部署** → 使用方案 2（V2 合約 + 前端整合）
3. **快速驗證** → 使用方案 3（繼續資料庫模式）

退款按鈕已經存在且可用，位於 `mobile/lib/trip_history_page.dart` 第 420-436 行，會顯示在所有已完成行程的卡片底部。

需要我幫您執行哪個方案嗎？
