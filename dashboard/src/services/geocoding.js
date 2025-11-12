/**
 * Google Geocoding API Service
 *
 * 功能：
 * 1. 經緯度 → 地址轉換
 * 2. localStorage 緩存優化
 * 3. 節省 API 查詢次數
 */

const GOOGLE_GEOCODING_API_KEY = import.meta.env.VITE_GOOGLE_GEOCODING_API_KEY || 'YOUR_API_KEY';
const CACHE_KEY = 'geo_cache';
const CACHE_EXPIRY_DAYS = 30; // 緩存有效期 30 天

class GeocodingService {
  constructor() {
    this.cache = this.loadCache();
  }

  /**
   * 從 localStorage 載入緩存
   */
  loadCache() {
    try {
      const cached = localStorage.getItem(CACHE_KEY);
      if (cached) {
        const data = JSON.parse(cached);
        // 檢查緩存是否過期
        if (data.timestamp && this._isExpired(data.timestamp)) {
          console.log('🗑️ 緩存已過期，清除...');
          this.clearCache();
          return {};
        }
        console.log(`📦 載入地址緩存: ${Object.keys(data.addresses || {}).length} 條記錄`);
        return data.addresses || {};
      }
    } catch (error) {
      console.error('載入緩存失敗:', error);
    }
    return {};
  }

  /**
   * 保存緩存到 localStorage
   */
  saveCache() {
    try {
      const data = {
        timestamp: Date.now(),
        addresses: this.cache,
      };
      localStorage.setItem(CACHE_KEY, JSON.stringify(data));
      console.log(`💾 已保存 ${Object.keys(this.cache).length} 條地址緩存`);
    } catch (error) {
      console.error('保存緩存失敗:', error);
    }
  }

  /**
   * 清除緩存
   */
  clearCache() {
    this.cache = {};
    localStorage.removeItem(CACHE_KEY);
    console.log('🗑️ 已清除地址緩存');
  }

  /**
   * 檢查緩存是否過期
   */
  _isExpired(timestamp) {
    const now = Date.now();
    const diff = now - timestamp;
    const expiryMs = CACHE_EXPIRY_DAYS * 24 * 60 * 60 * 1000;
    return diff > expiryMs;
  }

  /**
   * 生成緩存鍵
   */
  _getCacheKey(lat, lng) {
    // 四捨五入到小數點後 6 位（約 0.11 米精度）
    const roundedLat = parseFloat(lat).toFixed(6);
    const roundedLng = parseFloat(lng).toFixed(6);
    return `${roundedLat},${roundedLng}`;
  }

  /**
   * 從緩存獲取地址
   */
  getFromCache(lat, lng) {
    const key = this._getCacheKey(lat, lng);
    if (this.cache[key]) {
      console.log(`✅ 緩存命中: ${key}`);
      return this.cache[key];
    }
    return null;
  }

  /**
   * 保存到緩存
   */
  saveToCache(lat, lng, address) {
    const key = this._getCacheKey(lat, lng);
    this.cache[key] = {
      address,
      lat: parseFloat(lat),
      lng: parseFloat(lng),
      timestamp: Date.now(),
    };
    this.saveCache();
  }

  /**
   * 將經緯度轉換為地址
   * @param {number} lat - 緯度
   * @param {number} lng - 經度
   * @returns {Promise<string>} 地址字串
   */
  async getAddress(lat, lng) {
    // 檢查緩存
    const cached = this.getFromCache(lat, lng);
    if (cached) {
      return cached.address;
    }

    // 調用 Google Geocoding API
    try {
      console.log(`🌍 查詢地址: ${lat}, ${lng}`);

      const url = `https://maps.googleapis.com/maps/api/geocode/json?latlng=${lat},${lng}&key=${GOOGLE_GEOCODING_API_KEY}&language=zh-TW`;

      const response = await fetch(url);
      const data = await response.json();

      if (data.status === 'OK' && data.results.length > 0) {
        const address = data.results[0].formatted_address;

        // 保存到緩存
        this.saveToCache(lat, lng, address);

        console.log(`✅ 獲取地址成功: ${address}`);
        return address;
      } else if (data.status === 'ZERO_RESULTS') {
        const fallback = `📍 ${lat}, ${lng}`;
        this.saveToCache(lat, lng, fallback);
        return fallback;
      } else {
        console.error('Geocoding API 錯誤:', data.status, data.error_message);
        return `📍 ${lat}, ${lng}`;
      }
    } catch (error) {
      console.error('獲取地址失敗:', error);
      return `📍 ${lat}, ${lng}`;
    }
  }

  /**
   * 批量獲取地址
   * @param {Array<{lat: number, lng: number}>} locations - 位置列表
   * @returns {Promise<Array<string>>} 地址列表
   */
  async getBatchAddresses(locations) {
    const promises = locations.map(loc => this.getAddress(loc.lat, loc.lng));
    return Promise.all(promises);
  }

  /**
   * 預載入地址（用於提高性能）
   * @param {Array<{lat: number, lng: number}>} locations - 位置列表
   */
  async preloadAddresses(locations) {
    // 過濾出未緩存的位置
    const uncached = locations.filter(loc => !this.getFromCache(loc.lat, loc.lng));

    if (uncached.length === 0) {
      console.log('✅ 所有地址已緩存');
      return;
    }

    console.log(`📥 預載入 ${uncached.length} 個地址...`);

    // 分批查詢（每次最多 10 個，避免超過 API 限制）
    const batchSize = 10;
    for (let i = 0; i < uncached.length; i += batchSize) {
      const batch = uncached.slice(i, i + batchSize);
      await this.getBatchAddresses(batch);

      // 避免超過 API 限制，每批之間延遲 1 秒
      if (i + batchSize < uncached.length) {
        await new Promise(resolve => setTimeout(resolve, 1000));
      }
    }

    console.log('✅ 預載入完成');
  }

  /**
   * 匯出緩存為 JSON 檔案
   */
  exportCacheAsJSON() {
    const cacheData = {
      exported_at: new Date().toISOString(),
      total_entries: Object.keys(this.cache).length,
      cache: this.cache,
    };

    const blob = new Blob([JSON.stringify(cacheData, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = 'geo_cache.json';
    link.click();
    URL.revokeObjectURL(url);

    console.log(`📥 已匯出 ${Object.keys(this.cache).length} 條緩存記錄`);
  }

  /**
   * 獲取緩存統計
   */
  getCacheStats() {
    const entries = Object.keys(this.cache).length;
    const oldestEntry = entries > 0
      ? Math.min(...Object.values(this.cache).map(v => v.timestamp))
      : null;

    return {
      totalEntries: entries,
      oldestEntryDate: oldestEntry ? new Date(oldestEntry).toISOString() : null,
      cacheSize: new Blob([JSON.stringify(this.cache)]).size,
    };
  }
}

// 創建單例實例
const geocodingService = new GeocodingService();

export default geocodingService;
