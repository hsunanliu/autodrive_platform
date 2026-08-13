#!/usr/bin/env bash
#
# fund_refund_pool.sh — 對 RefundPoolV2 注資（平台簽）
#
# 退款池初始餘額為 0；admin 退款前必須先注資。本腳本用一筆 PTB 從 gas 拆出指定金額
# 並呼叫 refund_module_v2::fund_pool。
#
# 用法：
#   scripts/ops/fund_refund_pool.sh <amount_mist> [package_id] [pool_id]
#   （package_id / pool_id 省略時從 backend/.env 讀 CONTRACT_PACKAGE_ID / REFUND_POOL_ID）
#
# 前置：sui CLI 已登入且 active-address 為平台錢包（RefundPoolV2.platform_address）。
set -euo pipefail

AMOUNT="${1:?請提供注資金額（MIST），例：1000000000 = 1 SUI}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../../backend/.env"

read_env() { grep -E "^$1=" "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2-; }

PKG="${2:-$(read_env CONTRACT_PACKAGE_ID)}"
POOL="${3:-$(read_env REFUND_POOL_ID)}"

[ -n "$PKG" ]  || { echo "❌ 缺 CONTRACT_PACKAGE_ID"; exit 1; }
[ -n "$POOL" ] || { echo "❌ 缺 REFUND_POOL_ID"; exit 1; }

echo "💰 注資退款池"
echo "   package: $PKG"
echo "   pool:    $POOL"
echo "   amount:  $AMOUNT MIST"
echo "   signer:  $(sui client active-address)"
echo

sui client ptb \
  --split-coins gas "[$AMOUNT]" \
  --assign funded \
  --move-call "$PKG::refund_module_v2::fund_pool" @"$POOL" funded.0 \
  --gas-budget 20000000

echo "✅ 注資完成。可用 sui_getObject 查 pool.balance 驗證。"
