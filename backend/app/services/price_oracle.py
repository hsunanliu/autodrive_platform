"""
價格預言機服務
獲取 SUI/USD 實時匯率
"""
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
        self._fallback_price = 2.0  # 備用價格 $2.0

    async def get_sui_usd_price(self) -> float:
        """
        獲取 SUI/USD 價格

        Returns:
            float: 1 SUI 的美元價格（例如 2.50 代表 1 SUI = $2.50）
        """
        # 檢查快取
        if self._is_cache_valid():
            logger.debug(f"💰 使用快取的 SUI 價格: ${self._cached_price}")
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
                    logger.warning(f"⚠️  CoinGecko API 失敗: {response.status_code}")
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
            logger.warning(f"⚠️  使用過期快取: ${self._cached_price}")
            return self._cached_price

        # 使用固定備用價格
        logger.warning(f"⚠️  使用備用價格: ${self._fallback_price}")
        return self._fallback_price

    def clear_cache(self):
        """清除快取（測試用）"""
        self._cached_price = None
        self._cache_time = None


# 全局單例
_price_oracle = PriceOracle()


def get_price_oracle() -> PriceOracle:
    """獲取價格預言機實例"""
    return _price_oracle
