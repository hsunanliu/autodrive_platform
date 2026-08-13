"""
委託服務 — 管理使用者簽發給平台 Agent 的 OperatorCap（Phase 1）

使用者在自己的錢包簽發 agent_registry::issue_operator_cap 後，把 cap object id 回報。
本服務上鏈驗證該 cap（agent==平台、未撤銷、user==本人錢包），存 DB，供後端代發交易時查找。
"""
import logging
from datetime import datetime, timezone
from typing import Any, Dict, Optional

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.delegation import OperatorDelegation
from app.models.user import User

logger = logging.getLogger(__name__)


class DelegationService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def _fetch_cap_fields(self, cap_object_id: str) -> Optional[Dict[str, Any]]:
        """上鏈讀取 OperatorCap 物件的欄位。"""
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                resp = await client.post(
                    settings.SUI_NODE_URL,
                    json={
                        "jsonrpc": "2.0", "id": 1, "method": "sui_getObject",
                        "params": [cap_object_id, {"showContent": True}],
                    },
                )
                data = resp.json().get("result", {}).get("data")
                if not data:
                    return None
                return (data.get("content") or {}).get("fields")
        except Exception as e:  # noqa: BLE001
            logger.error(f"讀取 OperatorCap 失敗: {e}")
            return None

    @staticmethod
    def _addr_eq(a: Optional[str], b: Optional[str]) -> bool:
        return bool(a) and bool(b) and a.lower() == b.lower()

    async def record_delegation(self, user_id: int, cap_object_id: str) -> Dict[str, Any]:
        """回報並驗證一個使用者簽發的 OperatorCap。"""
        fields = await self._fetch_cap_fields(cap_object_id)
        if not fields:
            return {"success": False, "error": "找不到該 OperatorCap 物件（尚未上鏈或 id 錯誤）"}
        if not self._addr_eq(fields.get("agent"), settings.PLATFORM_WALLET):
            return {"success": False, "error": "此 cap 的 agent 不是平台位址，拒絕接受"}
        if fields.get("revoked"):
            return {"success": False, "error": "此 cap 已撤銷"}

        user = (await self.db.execute(
            select(User).where(User.id == user_id)
        )).scalar_one_or_none()
        if user and user.wallet_address and not self._addr_eq(fields.get("user"), user.wallet_address):
            return {"success": False, "error": "此 cap 的 user 與您的錢包位址不符"}

        valid_until = None
        try:
            vms = int(fields.get("valid_until_ms") or 0)
            if vms:
                valid_until = datetime.fromtimestamp(vms / 1000, tz=timezone.utc)
        except (ValueError, TypeError):
            pass

        def _int(x):
            try:
                return int(x)
            except (ValueError, TypeError):
                return None

        existing = (await self.db.execute(
            select(OperatorDelegation).where(OperatorDelegation.cap_object_id == cap_object_id)
        )).scalar_one_or_none()

        if existing:
            existing.revoked = bool(fields.get("revoked", False))
            existing.valid_until = valid_until
        else:
            self.db.add(OperatorDelegation(
                user_id=user_id,
                cap_object_id=cap_object_id,
                agent_address=fields.get("agent"),
                max_spend_per_tx=_int(fields.get("max_spend_per_tx")),
                daily_limit=_int(fields.get("daily_limit")),
                valid_until=valid_until,
                allowed_actions=_int(fields.get("allowed_actions")),
                revoked=bool(fields.get("revoked", False)),
            ))
        await self.db.commit()
        return {"success": True, "cap_object_id": cap_object_id, "user_id": user_id}

    async def get_active_cap(self, user_id: int) -> Optional[str]:
        """回傳該用戶目前有效（未撤銷、未過期）的 cap object id，找不到回 None。"""
        now = datetime.now(timezone.utc)
        rows = (await self.db.execute(
            select(OperatorDelegation)
            .where(OperatorDelegation.user_id == user_id, OperatorDelegation.revoked == False)  # noqa: E712
            .order_by(OperatorDelegation.created_at.desc())
        )).scalars().all()
        for r in rows:
            if r.valid_until is None or r.valid_until > now:
                return r.cap_object_id
        return None

    async def revoke(self, user_id: int) -> Dict[str, Any]:
        """撤銷該用戶的所有委託（DB 標記；鏈上 revoke 由用戶錢包另行簽署）。"""
        rows = (await self.db.execute(
            select(OperatorDelegation).where(
                OperatorDelegation.user_id == user_id,
                OperatorDelegation.revoked == False,  # noqa: E712
            )
        )).scalars().all()
        for r in rows:
            r.revoked = True
        await self.db.commit()
        return {"success": True, "revoked_count": len(rows)}
