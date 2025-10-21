# backend/app/api/v1/payment_proxy.py
"""
支付代理 API - 處理乘客轉帳並調用智能合約
"""

from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
import logging

from app.core.database import get_async_session
from app.models.ride import Trip
from app.services.sui_service import sui_service
from app.config import settings

logger = logging.getLogger(__name__)

router = APIRouter()


class ProcessPaymentRequest(BaseModel):
    """處理支付請求"""
    trip_id: int
    tx_hash: str  # 乘客轉帳的交易 hash


@router.post("/process-payment")
async def process_payment(
    request: ProcessPaymentRequest,
    db: AsyncSession = Depends(get_async_session)
):
    """
    處理乘客支付：
    1. 驗證乘客已轉帳到臨時地址
    2. 調用智能合約 lock_payment
    3. 保存 escrow_object_id
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
        
        # 計算平台費用（10%）
        total_amount = verification['amount_received']
        platform_fee = int(total_amount * 0.1)
        
        # 使用後端的操作錢包調用合約
        contract_result = await sui_service.call_contract_lock_payment(
            package_id=settings.CONTRACT_PACKAGE_ID,
            amount_mist=total_amount,
            trip_id=request.trip_id,
            driver_address=trip.driver_wallet_address,
            platform_address=settings.PLATFORM_WALLET,
            platform_fee_mist=platform_fee
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


@router.get("/temp-escrow-address")
async def get_temp_escrow_address():
    """
    獲取臨時託管地址（乘客轉帳目標）
    """
    return {
        "address": settings.PLATFORM_WALLET,
        "network": settings.SUI_NETWORK,
        "note": "請將支付金額轉到此地址，後端會自動處理智能合約調用"
    }
