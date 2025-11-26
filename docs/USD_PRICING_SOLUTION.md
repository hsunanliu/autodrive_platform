# 美元錨定定價解決方案

## 問題總結

目前系統使用**固定 SUI 數量計價**，會受到 SUI 價格波動影響：

### 現況：
```python
起跳價 = 0.6 SUI（固定）
每公里 = 0.2 SUI（固定）
每分鐘 = 0.04 SUI（固定）
```

### 問題：
- SUI = $1 時，10km 行程 = 3.4 SUI = **$3.4**（太便宜）
- SUI = $5 時，10km 行程 = 3.4 SUI = **$17**（太貴）

---

## 解決方案：美元錨定定價

### 1. 修改費率定義（以美元為基準）

```python
# backend/app/services/trip_service.py

class TripService:
    def __init__(self, db: AsyncSession):
        self.db = db

        # ✅ 新方案：以美元定義價格（固定）
        self.BASE_FARE_USD = 1.50  # 起跳價 $1.5
        self.PER_KM_RATE_USD = 0.50  # 每公里 $0.5
        self.PER_MINUTE_RATE_USD = 0.10  # 每分鐘 $0.1
        self.PLATFORM_FEE_RATE = 0.05  # 平台費率 5%
```

### 2. 實時獲取 SUI/USD 匯率

#### 選項 A：使用 CoinGecko API（免費）

```python
# backend/app/services/price_oracle.py

import httpx
from typing import Optional
import logging
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)

class PriceOracle:
    """價格預言機 - 獲取 SUI/USD 匯率"""

    def __init__(self):
        self.cache_duration = timedelta(minutes=5)  # 快取 5 分鐘
        self._cached_price: Optional[float] = None
        self._cache_time: Optional[datetime] = None

    async def get_sui_usd_price(self) -> float:
        """
        獲取 SUI/USD 價格

        Returns:
            float: 1 SUI 的美元價格（例如 2.50 代表 1 SUI = $2.50）
        """
        # 檢查快取
        if self._is_cache_valid():
            logger.debug(f"使用快取的 SUI 價格: ${self._cached_price}")
            return self._cached_price

        try:
            # 調用 CoinGecko API
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    "https://api.coingecko.com/api/v3/simple/price",
                    params={
                        "ids": "sui",
                        "vs_currencies": "usd"
                    },
                    timeout=5.0
                )

                if response.status_code == 200:
                    data = response.json()
                    price = data['sui']['usd']

                    # 更新快取
                    self._cached_price = price
                    self._cache_time = datetime.now()

                    logger.info(f"✅ 獲取 SUI 價格: ${price}")
                    return price
                else:
                    logger.warning(f"CoinGecko API 失敗: {response.status_code}")
                    return self._get_fallback_price()

        except Exception as e:
            logger.error(f"❌ 獲取 SUI 價格失敗: {e}")
            return self._get_fallback_price()

    def _is_cache_valid(self) -> bool:
        """檢查快取是否有效"""
        if self._cached_price is None or self._cache_time is None:
            return False

        elapsed = datetime.now() - self._cache_time
        return elapsed < self.cache_duration

    def _get_fallback_price(self) -> float:
        """備用價格（API 失敗時）"""
        # 使用快取（即使過期）
        if self._cached_price:
            logger.warning(f"使用過期快取: ${self._cached_price}")
            return self._cached_price

        # 使用固定備用價格
        fallback = 2.0  # $2.0
        logger.warning(f"使用備用價格: ${fallback}")
        return fallback

# 全局單例
_price_oracle = PriceOracle()

def get_price_oracle() -> PriceOracle:
    return _price_oracle
```

#### 選項 B：使用 Pyth Network（鏈上預言機，更準確）

```python
# backend/app/services/pyth_oracle.py

from pyth_sdk_solana import PythClient
import asyncio

class PythOracle:
    """使用 Pyth Network 獲取鏈上價格"""

    def __init__(self):
        # Pyth SUI/USD Price Feed ID
        self.SUI_USD_FEED_ID = "0x23d7315113f5b1d3ba7a83604c44b94d79f4fd69af77f804fc7f920a6dc65744"

    async def get_sui_usd_price(self) -> float:
        # 實現 Pyth 價格查詢
        # 參考: https://docs.pyth.network/documentation/pythnet-price-feeds/sui
        pass
```

### 3. 修改費用計算邏輯

```python
# backend/app/services/trip_service.py

from app.services.price_oracle import get_price_oracle

class TripService:

    async def _calculate_fare(
        self,
        distance_km: float,
        duration_minutes: int,
        surge_multiplier: float = 1.0,
        surge_breakdown: Optional[Dict[str, float]] = None,
        surge_reason: Optional[str] = None
    ) -> TripFareBreakdown:
        """
        計算費用（美元錨定）

        流程：
        1. 以美元計算費用
        2. 獲取 SUI/USD 匯率
        3. 換算成 SUI 數量
        """
        # 1. 以美元計算
        base_fare_usd = self.BASE_FARE_USD
        distance_fare_usd = distance_km * self.PER_KM_RATE_USD
        time_fare_usd = duration_minutes * self.PER_MINUTE_RATE_USD

        # 應用動態加價係數
        subtotal_usd = (base_fare_usd + distance_fare_usd + time_fare_usd) * surge_multiplier
        platform_fee_usd = subtotal_usd * self.PLATFORM_FEE_RATE
        total_usd = subtotal_usd + platform_fee_usd
        driver_amount_usd = total_usd - platform_fee_usd

        # 2. 獲取 SUI/USD 匯率
        oracle = get_price_oracle()
        sui_price_usd = await oracle.get_sui_usd_price()

        # 3. 換算成 SUI（MIST）
        base_fare_mist = int((base_fare_usd / sui_price_usd) * 1_000_000_000)
        distance_fare_mist = int((distance_fare_usd / sui_price_usd) * 1_000_000_000)
        time_fare_mist = int((time_fare_usd / sui_price_usd) * 1_000_000_000)
        platform_fee_mist = int((platform_fee_usd / sui_price_usd) * 1_000_000_000)
        total_amount_mist = int((total_usd / sui_price_usd) * 1_000_000_000)
        driver_amount_mist = int((driver_amount_usd / sui_price_usd) * 1_000_000_000)

        logger.info(f"💰 費用計算: ${total_usd:.2f} USD = {total_amount_mist / 1e9:.4f} SUI (匯率: 1 SUI = ${sui_price_usd})")

        return TripFareBreakdown(
            base_fare=base_fare_mist,
            distance_fare=distance_fare_mist,
            time_fare=time_fare_mist,
            platform_fee=platform_fee_mist,
            total_amount=total_amount_mist,
            driver_amount=driver_amount_mist,
            distance_km=distance_km,
            duration_minutes=duration_minutes,
            per_km_rate=int((self.PER_KM_RATE_USD / sui_price_usd) * 1_000_000_000),
            per_minute_rate=int((self.PER_MINUTE_RATE_USD / sui_price_usd) * 1_000_000_000),
            platform_fee_rate=self.PLATFORM_FEE_RATE,
            surge_multiplier=surge_multiplier,
            surge_breakdown=surge_breakdown,
            surge_reason=surge_reason,
            # 新增：美元金額
            total_amount_usd=total_usd,
            sui_price_usd=sui_price_usd
        )
```

### 4. 前端顯示改進

#### 同時顯示美元和 SUI

```dart
// mobile/lib/payment_page.dart

class PaymentSummary extends StatelessWidget {
  final double totalAmountSui;
  final double totalAmountUsd;
  final double suiPriceUsd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          // 主要顯示：美元金額（穩定）
          Text(
            '\$${totalAmountUsd.toStringAsFixed(2)} USD',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),

          // 次要顯示：SUI 數量（動態）
          Text(
            '≈ ${totalAmountSui.toStringAsFixed(4)} SUI',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 4),

          // 匯率提示
          Text(
            '1 SUI = \$${suiPriceUsd.toStringAsFixed(2)} USD',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
```

---

## 效果對比

### 場景：10 公里行程

#### 舊方案（固定 SUI）：
| SUI 價格 | 用戶支付 | 實際成本 |
|---------|---------|---------|
| $1 | 3.4 SUI | $3.4 ❌ 太便宜 |
| $2.5 | 3.4 SUI | $8.5 ✅ 合理 |
| $5 | 3.4 SUI | $17 ❌ 太貴 |

#### 新方案（美元錨定）：
| SUI 價格 | 用戶支付 | 實際成本 |
|---------|---------|---------|
| $1 | 8.5 SUI | $8.5 ✅ 穩定 |
| $2.5 | 3.4 SUI | $8.5 ✅ 穩定 |
| $5 | 1.7 SUI | $8.5 ✅ 穩定 |

用戶永遠支付 **$8.5 美元等值的 SUI**，不受幣價波動影響！

---

## 實施步驟

### Phase 1: 後端改造（2-3 天）
1. 創建 `price_oracle.py`（價格預言機）
2. 修改 `trip_service.py` 的費率定義
3. 修改 `_calculate_fare()` 函數
4. 測試匯率獲取穩定性

### Phase 2: 資料庫遷移（1 天）
```sql
-- 新增欄位記錄美元金額和匯率
ALTER TABLE trips ADD COLUMN total_amount_usd DECIMAL(10, 2);
ALTER TABLE trips ADD COLUMN sui_price_usd DECIMAL(10, 4);
```

### Phase 3: 前端調整（2-3 天）
1. API 返回同時包含 SUI 和 USD 金額
2. UI 同時顯示美元和 SUI
3. 添加匯率提示

### Phase 4: 測試（1 天）
- 模擬 SUI 價格波動
- 驗證費用計算準確性
- 確保匯率獲取穩定

---

## 風險與應對

### 風險 1：API 限流（CoinGecko 免費版）
**應對**：
- 快取 5 分鐘（降低請求頻率）
- 使用備用價格機制
- 未來升級 Pyth Network（鏈上預言機）

### 風險 2：匯率劇烈波動導致用戶困惑
**應對**：
- 預估時鎖定匯率（5 分鐘內有效）
- UI 明確顯示「預估」字樣
- 實際支付時允許小幅差異（±5%）

### 風險 3：歷史數據不一致
**應對**：
- 資料庫同時保存 SUI 和 USD 金額
- 歷史行程顯示當時的匯率
- 報表統計時使用 USD 金額

---

## 結論

### 優點：
1. ✅ 用戶體驗穩定（永遠支付相同美元金額）
2. ✅ 平台收入可預測
3. ✅ 符合傳統叫車 app 用戶習慣
4. ✅ 與 ADM 積分系統一致（也是錨定美元）

### 缺點：
1. ❌ 需要依賴外部 API（有限流風險）
2. ❌ 增加系統複雜度
3. ❌ 匯率波動時 SUI 數量會變化

### 建議：
**立即實施美元錨定定價**，這是提升用戶體驗的關鍵！

與代幣經濟系統結合後，整體架構將是：
- **行程計價**：錨定美元（穩定）
- **ADM 積分**：錨定美元（穩定）
- **DRIVE 代幣**：市場波動（投資屬性）

這樣既保護了普通用戶，又給投資者留下了上漲空間。
