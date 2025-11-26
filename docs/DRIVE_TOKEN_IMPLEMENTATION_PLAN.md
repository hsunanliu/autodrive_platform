# DRIVE 代幣實施計劃

## 📋 總覽

本文檔詳細說明 AutoDrive 雙代幣系統（DRIVE + ADM）的技術實施方案。

**時間估算**：7-12 週（2-3 個月）
**技術棧**：Sui Move, FastAPI, PostgreSQL, Flutter
**預算**：$55,000 - $110,000 USD（主要用於審計和流動性）

---

## 🎯 代幣架構設計

### 1. 雙代幣系統

#### **DRIVE（治理代幣）**
- **類型**：基於 Sui Coin Standard 的可交易代幣
- **總供應量**：100,000,000 DRIVE（1 億）
- **小數位數**：9（與 SUI 一致）
- **用途**：
  - 治理投票
  - 質押獲得分紅
  - 持有享受折扣（乘客 20%、司機降低抽成）
  - 流動性挖礦

#### **ADM（哩程積分）**
- **類型**：鏈下積分系統（PostgreSQL）
- **價值錨定**：$0.01 USD = 1 ADM（固定）
- **不可交易**：僅限平台內使用
- **用途**：
  - 兌換折扣券
  - 升級 VIP
  - 未來：兌換實體商品

---

## 🏗️ 智能合約架構

### 核心合約（5 個）

#### 1. **drive_token.move** - DRIVE 代幣合約
```
功能：
- 基於 sui::coin 標準
- 鑄造/燃燒功能
- TreasuryCap 管理

核心函數：
- init() - 初始化代幣，創建 TreasuryCap
- mint() - 鑄造新代幣（僅 TreasuryCap 持有者）
- burn() - 燃燒代幣
- batch_mint() - 批次空投
```

#### 2. **drive_staking.move** - 質押合約
```
功能：
- 用戶質押 DRIVE 獲得分紅
- 分紅來源：平台收入的 50%
- 支持靈活解押

核心函數：
- stake() - 質押 DRIVE
- unstake() - 解押並領取獎勵
- claim_rewards() - 領取獎勵（不解押）
- add_rewards() - 平台注入分紅（後端調用）

數據結構：
- StakingPool（共享對象）
  - total_staked: 總質押量
  - reward_pool: SUI 獎勵池
  - accumulated_reward_per_token: 累積獎勵係數

- StakePosition（用戶 NFT）
  - staked_amount: 質押數量
  - stake_time: 質押時間
  - reward_debt: 已領獎勵基準
```

#### 3. **platform_treasury.move** - 平台金庫
```
功能：
- 接收每筆行程 15% 的平台費
- 支持多簽提款
- 資金分配：30% 營運 + 50% 質押分紅 + 20% 金庫儲備

核心函數：
- deposit() - 接收行程支付
- withdraw() - 多簽提款
- distribute_to_staking() - 分配給質押池
```

#### 4. **payment_escrow.move（修改版）** - 簡化支付
```
原有邏輯：100% -> 司機
新邏輯：85% -> 司機 + 15% -> 平台金庫

關鍵改動：
- 移除複雜的即時分紅邏輯
- 改為簡單的兩方分配
- 降低 Gas 費
```

#### 5. **vested_drive.move** - 鎖倉代幣（可選）
```
功能：
- 發放鎖倉的 DRIVE 獎勵
- 防止「挖提賣」
- 線性解鎖機制

核心函數：
- create_vesting() - 創建鎖倉計劃（3-6 個月）
- claim_unlocked() - 領取已解鎖部分
- get_vesting_schedule() - 查詢解鎖進度
```

---

## 💾 後端系統架構

### 1. ADM 積分系統

#### **資料庫模型**（PostgreSQL）
```sql
-- 用戶積分表
CREATE TABLE user_points (
    user_id INT PRIMARY KEY,
    adm_balance INT DEFAULT 0,
    total_earned INT DEFAULT 0,
    total_spent INT DEFAULT 0,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- 積分交易記錄
CREATE TABLE point_transactions (
    id SERIAL PRIMARY KEY,
    user_id INT,
    amount INT,  -- 正數=獲得，負數=消費
    type VARCHAR(50),  -- 'ride_reward', 'referral', 'rating', 'exchange'
    description TEXT,
    metadata JSONB,  -- 額外信息（行程ID、推薦碼等）
    created_at TIMESTAMP
);

-- 兌換商品目錄
CREATE TABLE adm_rewards (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    description TEXT,
    cost_adm INT,
    type VARCHAR(50),  -- 'discount_coupon', 'vip_upgrade'
    value_usd DECIMAL(10, 2),
    is_active BOOLEAN DEFAULT TRUE
);
```

#### **ADM 獲取規則**
```python
# 行程完成獎勵
def calculate_ride_reward(distance_km, rating):
    base_reward = distance_km * 10  # 每公里 10 ADM
    rating_bonus = 0

    if rating >= 4.5:
        rating_bonus = 50  # 高評分額外獎勵
    elif rating >= 4.0:
        rating_bonus = 20

    return base_reward + rating_bonus

# 推薦獎勵
def referral_reward():
    referrer = 500 ADM  # 推薦人
    referee = 200 ADM   # 被推薦人首次完成行程
    return (referrer, referee)

# 連續使用獎勵（每週）
def weekly_streak_bonus(trips_count):
    if trips_count >= 5:
        return 300 ADM
    elif trips_count >= 3:
        return 100 ADM
    return 0
```

#### **ADM 兌換商城**
```python
REWARD_CATALOG = {
    "discount_1_usd": {
        "cost_adm": 100,  # 100 ADM = $1 折扣券
        "value_usd": 1.00
    },
    "discount_5_usd": {
        "cost_adm": 500,
        "value_usd": 5.00
    },
    "vip_month": {
        "cost_adm": 2000,  # VIP 會員 1 個月
        "benefits": "20% 折扣 + 優先配對 + 專屬客服"
    }
}
```

### 2. DRIVE 分發腳本（每週批次）

```python
# backend/app/tasks/drive_distribution.py

async def weekly_drive_distribution():
    """每週日晚上 23:00 執行"""

    # 1. 計算司機獎勵
    drivers = await calculate_driver_rewards()
    # 依據：總里程 + 評分 + 在線時長

    # 2. 計算乘客獎勵
    passengers = await calculate_passenger_rewards()
    # 依據：行程數 + 推薦數

    # 3. 調用智能合約批次鑄造
    recipients = [d['address'] for d in drivers + passengers]
    amounts = [d['reward_amount'] for d in drivers + passengers]

    # 注意：這裡鑄造的是「鎖倉 DRIVE」（6 個月線性解鎖）
    await sui_client.call_contract(
        package=DRIVE_PACKAGE_ID,
        module="vested_drive",
        function="batch_create_vesting",
        args=[recipients, amounts, vesting_duration=180*24*3600]  # 6 個月
    )

    # 4. 記錄到資料庫
    await save_distribution_records(drivers + passengers)
```

### 3. 質押分紅結算（每週）

```python
# backend/app/tasks/staking_rewards.py

async def weekly_staking_distribution():
    """每週一凌晨 00:00 執行"""

    # 1. 計算過去一週平台總收入
    total_revenue = await get_weekly_platform_revenue()  # 單位: SUI

    # 2. 計算質押者分紅（50%）
    staking_rewards = total_revenue * 0.5

    # 3. 從平台金庫提取 SUI
    sui_coin = await withdraw_from_treasury(staking_rewards)

    # 4. 注入質押池
    await sui_client.call_contract(
        package=DRIVE_PACKAGE_ID,
        module="drive_staking",
        function="add_rewards",
        args=[STAKING_POOL_ID, sui_coin]
    )

    # 5. 通知所有質押者
    await notify_stakers("本週分紅已到賬，請前往領取！")
```

### 4. 回購與燃燒（每月）

```python
# backend/app/tasks/buyback_burn.py

async def monthly_buyback_burn():
    """每月 1 號執行"""

    # 1. 計算回購金額（平台收入的 5%）
    monthly_revenue = await get_monthly_platform_revenue()
    buyback_amount = monthly_revenue * 0.05

    # 2. 從金庫提取 SUI
    sui_for_buyback = await withdraw_from_treasury(buyback_amount)

    # 3. 調用 DEX 回購 DRIVE
    # 使用 Cetus DEX 或 Turbos Finance
    drive_bought = await dex_swap(
        dex="cetus",
        from_coin="SUI",
        to_coin="DRIVE",
        amount=sui_for_buyback,
        slippage=0.05  # 5% 滑點容忍
    )

    # 4. 燃燒回購的 DRIVE
    await sui_client.call_contract(
        package=DRIVE_PACKAGE_ID,
        module="drive_token",
        function="burn",
        args=[TREASURY_CAP_ID, drive_bought]
    )

    # 5. 公開透明度報告
    await publish_burn_report({
        "date": datetime.now(),
        "sui_spent": buyback_amount,
        "drive_burned": drive_bought,
        "new_total_supply": await get_total_supply()
    })
```

---

## 📱 前端開發

### 1. ADM 積分頁面
```dart
// mobile/lib/pages/adm_points_page.dart

class AdmPointsPage extends StatefulWidget {
  // 功能：
  // - 顯示當前 ADM 餘額
  // - 獲得/消費歷史記錄
  // - 動畫效果（獲得 ADM 時顯示 +100 飛入效果）
}
```

### 2. ADM 兌換商城
```dart
// mobile/lib/pages/adm_shop_page.dart

class AdmShopPage extends StatefulWidget {
  // 功能：
  // - 展示可兌換商品
  // - 折扣券、VIP 升級
  // - 兌換確認流程
  // - 兌換成功後自動發放
}
```

### 3. DRIVE 錢包整合
```dart
// mobile/lib/pages/drive_wallet_page.dart

class DriveWalletPage extends StatefulWidget {
  // 功能：
  // - 顯示 DRIVE 餘額
  //   - 可用餘額
  //   - 鎖倉餘額（顯示解鎖進度）
  //   - 質押中餘額
  // - 轉帳功能（使用 Sui Wallet）
  // - 交易歷史
}
```

### 4. 質押頁面
```dart
// mobile/lib/pages/staking_page.dart

class StakingPage extends StatefulWidget {
  // 功能：
  // - 質押 DRIVE
  // - 解押（顯示冷卻期）
  // - 當前質押總量 & 個人質押量
  // - APY 計算器
  // - 領取分紅（顯示累積 SUI 獎勵）
}
```

### 5. 代幣經濟統計 Dashboard
```dart
// dashboard/src/pages/TokenEconomics.jsx

const TokenEconomicsPage = () => {
  // 展示數據：
  // - DRIVE 總供應量 & 流通量
  // - 總質押量 & 質押率
  // - 本週/本月燃燒量
  // - ADM 總發放量
  // - 平台總收入圖表
};
```

---

## ⏱️ 實施時間線

### **Phase 1: 架構設計（3-5 天）**
- [ ] 確定 ADM 價值錨定（$0.01 USD）
- [ ] 設計簡化版鏈上支付流程
- [ ] 設計 ADM 獲取規則與兌換比例
- [ ] 設計 DRIVE 分發與鎖倉機制
- [ ] 輸出：`token_economics_v1.0_final.md`

### **Phase 2: 智能合約開發（2-3 週）**
- [ ] 開發 `drive_token.move`（3-4 天）
- [ ] 開發 `drive_staking.move`（4-5 天）
- [ ] 開發 `platform_treasury.move`（2-3 天）
- [ ] 修改 `payment_escrow.move`（2 天）
- [ ] 開發 `vested_drive.move`（可選，3 天）
- [ ] 合約測試與審計（3-4 天）
- [ ] 輸出：5 個測試通過的智能合約

### **Phase 3: 後端系統開發（2-3 週）**
- [ ] ADM 積分系統（3-4 天）
  - 資料庫模型
  - API: `/api/v1/points/*`
- [ ] ADM 獲取邏輯（4-5 天）
  - 行程完成獎勵
  - 推薦系統
  - WebSocket 通知
- [ ] ADM 兌換系統（3-4 天）
  - 商城 API
  - 兌換流程
- [ ] DRIVE 分發腳本（2-3 天）
- [ ] 質押分紅結算（3-4 天）
- [ ] 回購燃燒腳本（3 天）
- [ ] 代幣經濟統計 API（2 天）
- [ ] 輸出：完整後端系統 + 定時任務

### **Phase 4: 前端開發（2-3 週）**
- [ ] ADM 積分頁面（3-4 天）
- [ ] ADM 兌換商城（4-5 天）
- [ ] DRIVE 錢包整合（3-4 天）
- [ ] 質押頁面（4-5 天）
- [ ] 代幣經濟統計 Dashboard（2-3 天）
- [ ] UI/UX 優化（2-3 天）
- [ ] 輸出：完整 UI 流程

### **Phase 5: 整合測試與上線（1-2 週）**
- [ ] 端到端流程測試（3-4 天）
- [ ] 經濟模型驗證（2-3 天）
  - 模擬 1000 筆訂單
  - 驗證 ADM 通膨率
- [ ] 安全審計（2-3 天，建議第三方）
- [ ] 文檔編寫（1-2 天）
- [ ] Testnet 部署（1 天）
- [ ] Mainnet 部署（1 天）
- [ ] 輸出：正式上線

---

## 🔑 關鍵技術要點

### 1. **ADM 價值錨定機制**
```
問題：如何確保 1 ADM = $0.01 USD？
解決方案：
- ADM 是鏈下積分，不是鏈上代幣
- 兌換折扣券時，動態計算 SUI 數量
- 例如：$1 折扣券 = 100 ADM
  - 如果 SUI = $2，券面值 = 0.5 SUI
  - 如果 SUI = $1，券面值 = 1 SUI
- 用戶看到的是美元面額，後端自動處理匯率
```

### 2. **質押分紅算法**
```
核心公式（類似 Uniswap v2 LP Staking）：

accumulated_reward_per_token += (new_rewards / total_staked)
user_pending_rewards = (user_staked * accumulated_reward_per_token) - user_reward_debt

優點：
- Gas 高效（每次分紅只更新一個全局變量）
- 自動按比例分配
- 用戶隨時可領取
```

### 3. **鎖倉機制**
```
為何需要鎖倉？
- 防止短期投機者「挖提賣」砸盤
- 確保獲得獎勵的人是長期持有者

實現方式：
- 空投獎勵：6 個月線性解鎖
- LP 挖礦獎勵：3 個月線性解鎖
- 用戶仍可享受分紅（鎖倉期間可質押）
```

### 4. **Gas 費優化**
```
簡化前（複雜版）：
每筆行程 -> 5 次鏈上操作 + 1 次 DEX 交換 = 高 Gas

簡化後（金庫模式）：
每筆行程 -> 2 次轉帳（司機 + 金庫）= 低 Gas
每週批次 -> 1 次分紅 + 1 次回購 = 可控成本
```

---

## 💰 預算估算

| 項目 | 金額（USD） | 說明 |
|-----|-----------|------|
| 智能合約審計 | $5,000 - $10,000 | 建議第三方（CertiK、SlowMist） |
| DEX 流動性提供 | $50,000 - $100,000 | DRIVE/SUI 交易對（可回收） |
| Testnet Gas 費 | $500 | 測試代幣 |
| **總計** | **$55,500 - $110,500** | |

---

## ⚠️ 風險與應對

### 1. **經濟模型失衡**
- **風險**：ADM 發放過多導致通膨
- **應對**：
  - 前 3 個月密切監控數據
  - 準備動態調整獎勵係數
  - 設定 ADM 發放上限

### 2. **智能合約漏洞**
- **風險**：資金被盜
- **應對**：
  - 必須第三方審計
  - 質押池設置緊急暫停功能
  - 金庫使用多簽（至少 2/3）

### 3. **代幣價格波動**
- **風險**：DRIVE 暴跌影響用戶信心
- **應對**：
  - 強調長期價值（分紅 + 通縮）
  - 初期流動性挖礦穩定價格
  - DAO 回購支撐

### 4. **技術複雜度**
- **風險**：一人開發進度慢
- **應對**：
  - 專注 v1.0 核心功能
  - 社交代幣等高級功能推遲到 v2.0
  - 考慮外包審計

---

## 📝 總結

### 我對你的建議：

1. **立刻開始 Phase 1**（本週內完成設計）
2. **專注簡化版本**（金庫模式 + 批次處理）
3. **必須審計合約**（這是最大風險）
4. **數據驅動調整**（前 3 個月密切監控經濟模型）

### 你現有的優勢：

- ✅ 已有完整的經濟模型文檔
- ✅ 已有 Sui Move 開發經驗（payment_escrow）
- ✅ 已有完整的後端架構（FastAPI）
- ✅ 已有 Flutter 前端基礎

### 下一步行動：

1. 確認是否採用「簡化版金庫模式」
2. 確認 ADM 錨定美元（而非 SUI）
3. 確認是否有預算進行第三方審計
4. 決定全職投入（2 個月）還是兼職（3-4 個月）

老哥，這是一個紮實且可執行的計劃。關鍵是**先做 v1.0 核心功能，快速驗證經濟模型，然後迭代**。

你準備好開始了嗎？
