"""
AI Agent 護欄（Guardrails）— 防 Prompt Injection 越權（威脅 T8）

背景：目前決策是規則式、無 LLM；未來若導入 AutoGen 等 LLM Agent，LLM 產出的「動作」
在送上鏈前**必須先過本層強型別驗證**，再由鏈上 `OperatorCap` 的數值邊界做最後防線。
→ 即使 LLM 完全被注入操控，也無法：設定 0/負車資、超額動用、對非本人資產下手、
   夾帶自由文字繞過參數。

核心原則：
  - LLM 只能產出**結構化動作**（action + 明確欄位），絕不直接吐鏈上原始參數。
  - 動作類型限白名單，且必須在該用戶 OperatorCap 的 allowed_actions bitmask 內。
  - 金額有下限（>0）與上限（≤ 單筆/每日 cap 剩餘額度）。
  - 物件 ID 必須是良構 0x hex（擋自由文字/指令注入）。
  - 對象必須屬於 Agent 代理的那個用戶（不可跨用戶）。
"""

import re
from dataclasses import dataclass
from typing import Any, Dict, Optional

# 與合約 agent_registry.move 的 bitmask 一致
ACTION_BITS = {
    "release_escrow": 1,
    "refund": 2,
    "rate": 4,
    "match": 8,
}
# 需要金額邊界的動作（動用資金）
FUND_ACTIONS = {"release_escrow", "refund"}

_OBJECT_ID_RE = re.compile(r"^0x[0-9a-fA-F]{1,64}$")
_MIN_AMOUNT_MIST = 1  # >0；車資地板由合約 MIN_PAYMENT_MIST 另行把關


class GuardrailViolation(Exception):
    """Agent 動作違反護欄，拒絕建構交易。"""


@dataclass(frozen=True)
class AgentAction:
    action: str
    escrow_object_id: Optional[str]
    operator_cap_id: str
    trip_id: Optional[int]
    amount_mist: Optional[int]


def is_valid_object_id(value: Any) -> bool:
    """良構 Sui object id（0x + 1..64 hex）。"""
    return isinstance(value, str) and bool(_OBJECT_ID_RE.match(value))


def _require_object_id(value: Any, field: str) -> str:
    if not isinstance(value, str) or not _OBJECT_ID_RE.match(value):
        raise GuardrailViolation(f"{field} 非良構 object id（擋自由文字注入）")
    return value


def validate_action(
    raw: Dict[str, Any],
    *,
    allowed_actions_mask: int,
    max_spend_per_tx: int,
    daily_remaining: int,
    caller_user_id: int,
    resource_owner_user_id: int,
) -> AgentAction:
    """
    驗證 LLM/呼叫端產出的動作。通過回傳型別化 AgentAction；違規拋 GuardrailViolation。

    Args:
        allowed_actions_mask: 該用戶 OperatorCap 的 allowed_actions bitmask。
        max_spend_per_tx / daily_remaining: cap 的單筆上限與今日剩餘額度（MIST）。
        caller_user_id: Agent 代理的用戶。
        resource_owner_user_id: 目標資源（行程/託管）實際所屬用戶。
    """
    # 1. action 必須是已知白名單字串（拒絕任何未知/自由文字動作）
    action = raw.get("action")
    if action not in ACTION_BITS:
        raise GuardrailViolation(f"未知或不允許的動作: {action!r}")

    # 2. 對象必須屬於 Agent 所代理的用戶（不可跨用戶操作）
    if caller_user_id != resource_owner_user_id:
        raise GuardrailViolation("目標資源不屬於此用戶，拒絕代發")

    # 3. 動作必須在 OperatorCap 的 allowed_actions 內
    if not (allowed_actions_mask & ACTION_BITS[action]):
        raise GuardrailViolation(f"動作 {action} 不在 OperatorCap 授權範圍")

    # 4. cap id 必為良構 object id
    operator_cap_id = _require_object_id(raw.get("operator_cap_id"), "operator_cap_id")

    escrow_object_id = None
    trip_id = None
    amount_mist = None

    if action in FUND_ACTIONS:
        escrow_object_id = _require_object_id(raw.get("escrow_object_id"), "escrow_object_id")

        # 5. 金額邊界：>0（防 0/負車資）、≤ 單筆上限、≤ 每日剩餘
        amount_mist = raw.get("amount_mist")
        if not isinstance(amount_mist, int) or isinstance(amount_mist, bool):
            raise GuardrailViolation("amount_mist 必須是整數")
        if amount_mist < _MIN_AMOUNT_MIST:
            raise GuardrailViolation("金額必須為正（防 0 元車資）")
        if amount_mist > max_spend_per_tx:
            raise GuardrailViolation("金額超過 OperatorCap 單筆上限")
        if amount_mist > daily_remaining:
            raise GuardrailViolation("金額超過 OperatorCap 今日剩餘額度")

        tid = raw.get("trip_id")
        if tid is not None:
            if not isinstance(tid, int) or isinstance(tid, bool) or tid < 0:
                raise GuardrailViolation("trip_id 非法")
            trip_id = tid

    return AgentAction(
        action=action,
        escrow_object_id=escrow_object_id,
        operator_cap_id=operator_cap_id,
        trip_id=trip_id,
        amount_mist=amount_mist,
    )
