"""
非託管付款 API（zkLogin + Enoki 贊助）— Phase 4

  POST /payments/zklogin/prepare   組交易 + 請 Enoki 贊助 → {bytes, digest}
  POST /payments/zklogin/execute   送出乘客簽好的贊助交易 → {digest, escrow_object_id}

passenger 一律取自登入使用者（app JWT）的 wallet_address（zkLogin 位址），不由前端傳入，避免冒名。
"""
import logging

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.api.deps import get_current_active_user
from app.models.user import User
from app.services.payment_zklogin_service import payment_zklogin_service, PaymentBuildError
from app.services.zklogin_service import ZkLoginError

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/payments/zklogin", tags=["payments-zklogin"])


class PrepareRequest(BaseModel):
    trip_id: int
    amount_mist: int
    driver: str
    platform: str | None = None


class ExecuteRequest(BaseModel):
    digest: str
    signature: str


@router.post("/prepare")
async def prepare_payment(body: PrepareRequest, user: User = Depends(get_current_active_user)):
    """組 lock_payment 並請 Enoki 贊助。回 {bytes, digest}（bytes 給前端簽）。"""
    passenger = user.wallet_address
    if not passenger:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "使用者無 zkLogin 位址，請以 zkLogin 登入")
    try:
        built = await payment_zklogin_service.build_lock_payment_kind(
            passenger=passenger,
            amount_mist=body.amount_mist,
            trip_id=body.trip_id,
            driver=body.driver,
            platform=body.platform,
        )
        sponsored = await payment_zklogin_service.sponsor_lock_payment(built["kind_bytes"], passenger)
        return {"bytes": sponsored.get("bytes"), "digest": sponsored.get("digest")}
    except PaymentBuildError as e:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(e))
    except ZkLoginError as e:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, f"Enoki 未就緒: {e}")
    except Exception as e:  # noqa: BLE001
        logger.error(f"prepare_payment 失敗: {e}")
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, f"贊助交易失敗: {e}")


@router.post("/execute")
async def execute_payment(body: ExecuteRequest, user: User = Depends(get_current_active_user)):
    """送出乘客簽好的贊助交易，回傳 escrow_object_id。"""
    try:
        return await payment_zklogin_service.execute_lock_payment(body.digest, body.signature)
    except ZkLoginError as e:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, f"Enoki 未就緒: {e}")
    except Exception as e:  # noqa: BLE001
        logger.error(f"execute_payment 失敗: {e}")
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, f"送出交易失敗: {e}")
