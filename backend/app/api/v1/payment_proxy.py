# backend/app/api/v1/payment_proxy.py
"""
支付代理 API - 處理乘客轉帳並調用智能合約

⚠️ 後備路徑（問題 9）：此端點採「乘客先轉帳到平台位址 → 平台代簽 lock_payment」的半託管模式。
正式主流程為**非託管**：乘客直接用自己的錢包簽 lock_payment（見 trips.py 的 /escrow-payment
非 MOCK_MODE 分支回傳的 on_chain_call）。保留此端點作為相容/後備，勿作為主路徑。
"""

from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
import logging

from app.core.database import get_async_session
from app.core.rate_limit import rate_limit
from app.api.deps import get_current_user
from app.models.ride import Trip
from app.models import User
from app.services.sui_service import sui_service
from app.config import settings

logger = logging.getLogger(__name__)

router = APIRouter()


class ProcessPaymentRequest(BaseModel):
    """處理支付請求"""
    trip_id: int
    tx_hash: str  # 乘客轉帳的交易 hash


@router.post(
    "/process-payment",
    dependencies=[Depends(rate_limit(times=5, seconds=60, scope="process-payment"))],
)
async def process_payment(
    request: ProcessPaymentRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_session)
):
    """
    處理乘客支付：
    1. 驗證乘客已轉帳到臨時地址
    2. 調用智能合約 lock_payment
    3. 保存 escrow_object_id

    安全：此端點會觸發「平台錢包付 gas 的鏈上交易」，先前無認證（威脅 T5，經濟型 DoS）。
    現在要求登入、限流，且行程必須屬於呼叫者本人。
    """
    try:
        logger.info(f"🔄 處理支付: Trip {request.trip_id}, TX {request.tx_hash}")

        # 1. 獲取行程信息
        result = await db.execute(
            select(Trip).where(Trip.trip_id == request.trip_id)
        )
        trip = result.scalar_one_or_none()

        if not trip:
            raise HTTPException(status_code=404, detail="行程不存在")

        # 只有該行程的乘客本人可觸發支付處理
        if trip.user_id != current_user.id:
            raise HTTPException(status_code=403, detail="無權處理此行程的支付")

        # 2. 驗證轉帳交易
        logger.info(f"📝 驗證轉帳交易: {request.tx_hash}")
        
        # 臨時託管地址（使用操作錢包地址）
        temp_escrow_address = settings.PLATFORM_WALLET
        
        verification = await sui_service.verify_payment_transaction(
            tx_hash=request.tx_hash,
            expected_recipient=temp_escrow_address,
            expected_amount=trip.estimated_fare
        )
        
        if not verification.get('valid'):
            error_msg = verification.get('error', '交易驗證失敗')
            logger.error(f"❌ 驗證失敗: {error_msg}")
            raise HTTPException(status_code=400, detail=error_msg)
        
        logger.info(f"✅ 轉帳驗證成功: {verification['amount_received']} MIST")
        
        # 3. 調用智能合約 lock_payment
        logger.info(f"📞 調用智能合約 lock_payment...")

        # 平台費由合約以 PLATFORM_FEE_RATE（250 bps = 2.5%）於鏈上計算，
        # 後端不再自算 10%（避免鏈上/鏈下不一致，威脅 T10）。此處僅為回應顯示用途。
        total_amount = verification['amount_received']
        PLATFORM_FEE_BPS = 250
        platform_fee = total_amount * PLATFORM_FEE_BPS // 10000

        # 使用後端的操作錢包調用合約（platform_fee 不再傳入，改由鏈上計算）
        contract_result = await sui_service.call_contract_lock_payment(
            package_id=settings.CONTRACT_PACKAGE_ID,
            amount_mist=total_amount,
            trip_id=request.trip_id,
            driver_address=trip.driver_wallet_address,
            platform_address=settings.PLATFORM_WALLET,
            platform_fee_mist=0,  # 已棄用參數；費率由合約計算
        )
        
        if not contract_result.get('success'):
            error_msg = contract_result.get('error', '智能合約調用失敗')
            logger.error(f"❌ 合約調用失敗: {error_msg}")
            raise HTTPException(status_code=500, detail=error_msg)
        
        escrow_object_id = contract_result.get('escrow_object_id')
        contract_tx_hash = contract_result.get('transaction_hash')
        
        logger.info(f"✅ 智能合約調用成功")
        logger.info(f"   Escrow Object ID: {escrow_object_id}")
        logger.info(f"   Contract TX: {contract_tx_hash}")
        
        # 4. 更新行程記錄
        trip.escrow_object_id = escrow_object_id
        trip.payment_tx_hash = request.tx_hash
        # 添加 contract_tx_hash 字段（如果模型中沒有，可以先註釋掉）
        # trip.contract_tx_hash = contract_tx_hash
        
        await db.commit()
        await db.refresh(trip)
        
        logger.info(f"✅ 支付處理完成: Trip {request.trip_id}")
        
        return {
            "success": True,
            "message": "支付處理成功",
            "escrow_object_id": escrow_object_id,
            "payment_tx_hash": request.tx_hash,
            "contract_tx_hash": contract_tx_hash,
            "amount_received": verification['amount_received'],
            "platform_fee": platform_fee
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ 處理支付失敗: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get(
    "/temp-escrow-address",
    dependencies=[Depends(rate_limit(times=30, seconds=60, scope="escrow-address"))],
)
async def get_temp_escrow_address(
    current_user: User = Depends(get_current_user),
):
    """
    獲取臨時託管地址（乘客轉帳目標）。需登入（先前匿名可讀，會洩漏平台錢包位址）。
    """
    return {
        "address": settings.PLATFORM_WALLET,
        "network": settings.SUI_NETWORK,
        "note": "請將支付金額轉到此地址，後端會自動處理智能合約調用"
    }
