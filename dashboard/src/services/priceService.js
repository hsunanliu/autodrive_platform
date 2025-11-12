// dashboard/src/services/priceService.js

/**
 * 價格服務 - 處理 SUI 與 USD 轉換
 *
 * 功能：
 * - 從 CoinGecko API 獲取 SUI 價格
 * - 緩存價格（5 分鐘有效期）
 * - 格式化雙幣顯示（SUI + USD）
 */

const COINGECKO_API = 'https://api.coingecko.com/api/v3/simple/price';
const CACHE_DURATION_MS = 5 * 60 * 1000; // 5 分鐘緩存

let priceCache = {
  price: null,
  timestamp: null,
};

/**
 * 獲取 SUI/USD 價格
 * @returns {Promise<number|null>} SUI 價格（美元）
 */
export async function getSuiUsdPrice() {
  // 檢查緩存
  const now = Date.now();
  if (priceCache.price !== null &&
      priceCache.timestamp !== null &&
      (now - priceCache.timestamp) < CACHE_DURATION_MS) {
    return priceCache.price;
  }

  try {
    const response = await fetch(
      `${COINGECKO_API}?ids=sui&vs_currencies=usd`,
      {
        method: 'GET',
        headers: { 'Accept': 'application/json' },
        signal: AbortSignal.timeout(5000) // 5 秒超時
      }
    );

    if (!response.ok) {
      console.warn('CoinGecko API 請求失敗:', response.status);
      return null;
    }

    const data = await response.json();
    const price = data?.sui?.usd;

    if (price != null) {
      // 更新緩存
      priceCache = {
        price: parseFloat(price),
        timestamp: now,
      };
      console.log(`✅ SUI 價格更新: $${price} USD`);
      return priceCache.price;
    }

    return null;
  } catch (error) {
    console.warn('獲取 SUI 價格失敗:', error.message);
    return null;
  }
}

/**
 * 格式化為雙幣顯示
 * @param {number} suiAmount - SUI 數量
 * @returns {Promise<string>} 格式化字串 "X.XXXX SUI ≈ $X.XX USD"
 */
export async function formatDualCurrency(suiAmount) {
  if (suiAmount == null || isNaN(suiAmount)) {
    return '0.0000 SUI';
  }

  const sui = parseFloat(suiAmount);
  const price = await getSuiUsdPrice();

  if (price === null) {
    // 無法獲取價格，只顯示 SUI
    return `${sui.toFixed(4)} SUI`;
  }

  const usd = sui * price;
  return `${sui.toFixed(4)} SUI ≈ $${usd.toFixed(2)} USD`;
}

/**
 * 獲取緩存狀態（用於調試）
 * @returns {Object} 緩存信息
 */
export function getCacheInfo() {
  return {
    price: priceCache.price,
    timestamp: priceCache.timestamp,
    isValid: priceCache.price !== null &&
             priceCache.timestamp !== null &&
             (Date.now() - priceCache.timestamp) < CACHE_DURATION_MS,
  };
}

const priceService = {
  getSuiUsdPrice,
  formatDualCurrency,
  getCacheInfo,
};

export default priceService;
