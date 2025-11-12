// dashboard/src/components/DualCurrencyDisplay.jsx

import React, { useState, useEffect } from 'react';
import priceService from '../services/priceService';

/**
 * 雙幣顯示組件
 *
 * 自動從 CoinGecko 獲取 SUI/USD 匯率並格式化顯示
 *
 * @param {number} suiAmount - SUI 數量
 * @param {object} style - 自定義樣式
 */
const DualCurrencyDisplay = ({ suiAmount, style = {} }) => {
  const [displayText, setDisplayText] = useState('');
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    let isMounted = true;

    const fetchAndFormat = async () => {
      setIsLoading(true);
      try {
        const formatted = await priceService.formatDualCurrency(suiAmount);
        if (isMounted) {
          setDisplayText(formatted);
        }
      } catch (error) {
        console.error('格式化貨幣失敗:', error);
        if (isMounted) {
          // 降級顯示
          setDisplayText(`${Number(suiAmount || 0).toFixed(4)} SUI`);
        }
      } finally {
        if (isMounted) {
          setIsLoading(false);
        }
      }
    };

    fetchAndFormat();

    return () => {
      isMounted = false;
    };
  }, [suiAmount]);

  if (isLoading) {
    return <span style={style}>...</span>;
  }

  return <span style={style}>{displayText}</span>;
};

export default DualCurrencyDisplay;
