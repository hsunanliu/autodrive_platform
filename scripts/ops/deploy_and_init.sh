#!/usr/bin/env bash
#
# deploy_and_init.sh — 發布 ChainSUI Move 合約並擷取初始化產生的物件 ID
#
# 合約各模組的 init() 會建立多個 shared 物件與能力物件（AdminCap 等）。
# 本腳本發布套件後，從 objectChanges 解析出這些 ID，直接印成可貼進 backend/.env 的變數。
#
# 用法：
#   scripts/ops/deploy_and_init.sh [--gas-budget N]
#
# 前置：
#   - 已安裝並登入 sui CLI（sui client active-address 有值、該地址有 gas）
#   - 已安裝 jq
#
# 注意：本腳本只發布與讀取，不改動 .env（避免覆蓋你的機密）；請自行把輸出貼上。
set -euo pipefail

GAS_BUDGET="500000000"
if [[ "${1:-}" == "--gas-budget" && -n "${2:-}" ]]; then GAS_BUDGET="$2"; fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTRACTS_DIR="$(cd "$SCRIPT_DIR/../../contracts" && pwd)"

command -v sui >/dev/null || { echo "❌ 找不到 sui CLI"; exit 1; }
command -v jq  >/dev/null || { echo "❌ 找不到 jq（brew install jq）"; exit 1; }

echo "📦 發布套件：$CONTRACTS_DIR"
echo "   active-address: $(sui client active-address)"
echo "   gas-budget:     $GAS_BUDGET"
echo

OUT="$(sui client publish "$CONTRACTS_DIR" --gas-budget "$GAS_BUDGET" --json)"

# 套件 ID
PACKAGE_ID="$(echo "$OUT" | jq -r '.objectChanges[] | select(.type=="published") | .packageId')"

# 依 objectType 後綴擷取「created」物件的 objectId
oid_by_type() {
  local suffix="$1"
  echo "$OUT" | jq -r --arg s "$suffix" \
    '.objectChanges[] | select(.type=="created" and (.objectType|endswith($s))) | .objectId' \
    | head -1
}

USER_REGISTRY_ID="$(oid_by_type '::user_registry::UserRegistry')"
VEHICLE_REGISTRY_ID="$(oid_by_type '::vehicle_registry::VehicleRegistry')"
DID_REGISTRY_ID="$(oid_by_type '::did_registry::DIDRegistry')"
CREDENTIAL_REGISTRY_ID="$(oid_by_type '::credential_verifier::CredentialRegistry')"
CREDENTIAL_ADMIN_CAP_ID="$(oid_by_type '::credential_verifier::CredentialAdminCap')"
TRUSTED_ISSUERS_ID="$(oid_by_type '::trusted_issuers::TrustedIssuersRegistry')"
REFUND_POOL_ID="$(oid_by_type '::refund_module_v2::RefundPoolV2')"
REFUND_CAP_ID="$(oid_by_type '::refund_module_v2::RefundCapability')"
RATING_ADMIN_CAP_ID="$(oid_by_type '::rating_proof::RatingAdminCap')"
ARBITER_CAP_ID="$(oid_by_type '::payment_escrow::ArbiterCap')"

echo "✅ 發布完成。以下貼進 backend/.env："
echo
cat <<ENVOUT
CONTRACT_PACKAGE_ID=$PACKAGE_ID
USER_REGISTRY_ID=$USER_REGISTRY_ID
VEHICLE_REGISTRY_ID=$VEHICLE_REGISTRY_ID
DID_REGISTRY_ID=$DID_REGISTRY_ID
CREDENTIAL_REGISTRY_ID=$CREDENTIAL_REGISTRY_ID
TRUSTED_ISSUERS_ID=$TRUSTED_ISSUERS_ID
REFUND_POOL_ID=$REFUND_POOL_ID
ENVOUT

echo
echo "🔑 平台持有的能力物件（保管好，勿外流）："
echo "   CredentialAdminCap: $CREDENTIAL_ADMIN_CAP_ID   # 註冊 ZKP 驗證密鑰用"
echo "   RefundCapability:   $REFUND_CAP_ID              # 批准退款用"
echo "   RatingAdminCap:     $RATING_ADMIN_CAP_ID        # 建立車輛評分統計用"
echo "   ArbiterCap:         $ARBITER_CAP_ID             # 爭議仲裁用（resolve_dispute）"
echo
echo "📝 後續："
echo "   1. 用 CredentialAdminCap 呼叫 credential_verifier::register_verification_key 註冊 age/license vk。"
echo "   2. 用 RefundCapability 對 RefundPoolV2 注資（fund_pool）。"
echo "   3. 用戶各自呼叫 agent_registry::issue_operator_cap 授權 Agent（D2 代發交易的前置）。"
