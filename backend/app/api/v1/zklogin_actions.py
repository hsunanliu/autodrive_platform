"""
非託管動作 API（zkLogin + Enoki 贊助）— Phase 5（委託）/ Phase 6（爭議）

  POST /agent/zklogin/delegate/prepare   組 issue_operator_cap + 贊助 → {bytes, digest}
  POST /agent/zklogin/delegate/execute   送出 → {digest, cap_object_id}
  POST /disputes/zklogin/prepare         組 raise_dispute + 贊助 → {bytes, digest}
  POST /disputes/zklogin/execute         送出 → {digest, dispute_object_id}

user/passenger 一律取自登入 JWT 的 wallet_address（zkLogin 位址），不由前端傳入。
"""
import logging

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.api.deps import get_current_active_user
from app.models.user import User
from app.services.zklogin_tx_service import zklogin_tx_service, ZkTxBuildError
from app.services.zklogin_service import ZkLoginError

logger = logging.getLogger(__name__)
router = APIRouter(tags=["zklogin-actions"])


class DelegatePrepareRequest(BaseModel):
    max_spend_mist: int
    daily_limit_mist: int
    valid_for_ms: int
    allowed_actions: int | None = None  # 預設 RELEASE|REFUND


class DisputePrepareRequest(BaseModel):
    escrow_object_id: str
    reason: str


class ExecuteRequest(BaseModel):
    digest: str
    signature: str


def _require_addr(user: User) -> str:
    if not user.wallet_address:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "使用者無 zkLogin 位址，請以 zkLogin 登入")
    return user.wallet_address


# ── Phase 5：委託 ─────────────────────────────────────────────
@router.post("/agent/zklogin/delegate/prepare")
async def delegate_prepare(body: DelegatePrepareRequest, user: User = Depends(get_current_active_user)):
    addr = _require_addr(user)
    try:
        kwargs = dict(
            user=addr,
            max_spend_mist=body.max_spend_mist,
            daily_limit_mist=body.daily_limit_mist,
            valid_for_ms=body.valid_for_ms,
        )
        if body.allowed_actions is not None:
            kwargs["allowed_actions"] = body.allowed_actions
        built = zklogin_tx_service.build_issue_operator_cap(**kwargs)
        sponsored = await zklogin_tx_service.sponsor(built["kind_bytes"], addr, built["target"])
        return {"bytes": sponsored.get("bytes"), "digest": sponsored.get("digest")}
    except ZkTxBuildError as e:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(e))
    except ZkLoginError as e:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, f"Enoki 未就緒: {e}")
    except Exception as e:  # noqa: BLE001
        logger.error(f"delegate_prepare 失敗: {e}")
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, f"贊助交易失敗: {e}")


@router.post("/agent/zklogin/delegate/execute")
async def delegate_execute(body: ExecuteRequest, user: User = Depends(get_current_active_user)):
    try:
        result = await zklogin_tx_service.execute(body.digest, body.signature, "agent_registry::OperatorCap")
        return {"digest": result["digest"], "cap_object_id": result["object_id"]}
    except ZkLoginError as e:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, f"Enoki 未就緒: {e}")
    except Exception as e:  # noqa: BLE001
        logger.error(f"delegate_execute 失敗: {e}")
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, f"送出交易失敗: {e}")


# ── Phase 6：爭議 ─────────────────────────────────────────────
@router.post("/disputes/zklogin/prepare")
async def dispute_prepare(body: DisputePrepareRequest, user: User = Depends(get_current_active_user)):
    addr = _require_addr(user)
    if len(body.reason.strip()) < 5:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "爭議原因太短")
    try:
        built = zklogin_tx_service.build_raise_dispute(addr, body.escrow_object_id, body.reason)
        sponsored = await zklogin_tx_service.sponsor(built["kind_bytes"], addr, built["target"])
        return {"bytes": sponsored.get("bytes"), "digest": sponsored.get("digest")}
    except ZkTxBuildError as e:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(e))
    except ZkLoginError as e:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, f"Enoki 未就緒: {e}")
    except Exception as e:  # noqa: BLE001
        logger.error(f"dispute_prepare 失敗: {e}")
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, f"贊助交易失敗: {e}")


@router.post("/disputes/zklogin/execute")
async def dispute_execute(body: ExecuteRequest, user: User = Depends(get_current_active_user)):
    try:
        result = await zklogin_tx_service.execute(body.digest, body.signature, "payment_escrow::Dispute")
        return {"digest": result["digest"], "dispute_object_id": result["object_id"]}
    except ZkLoginError as e:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, f"Enoki 未就緒: {e}")
    except Exception as e:  # noqa: BLE001
        logger.error(f"dispute_execute 失敗: {e}")
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, f"送出交易失敗: {e}")
