# backend/app/api/v1/trips.py
"""
行程管理 API
處理叫車、配對、行程狀態管理等功能
"""

import logging
from fastapi import APIRouter, HTTPException, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Optional

from app.core.database import get_async_session
from app.api.deps import get_current_user, require_passenger_role, require_driver_role
from app.models.user import User
from app.services.trip_service import TripService
from app.services.sui_service import sui_service as iota_service
from app.schemas.trip import (
    TripCreate, TripResponse, TripEstimate, TripCancelRequest,
    TripAcceptRequest, DriverTripInfo, TripSummary
)
from app.schemas.payment import WalletBalance, TransactionStatus, PaymentStatus
from app.config import settings

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/trips", tags=["trips"])

@router.post("/estimate", response_model=TripEstimate)
async def get_trip_estimate(
    pickup_lat: float = Query(..., description="上車點緯度"),
    pickup_lng: float = Query(..., description="上車點經度"),
    dropoff_lat: float = Query(..., description="下車點緯度"),
    dropoff_lng: float = Query(..., description="下車點經度"),
    db: AsyncSession = Depends(get_async_session)
):
    """
    獲取行程預估 (費用、時間、可用車輛)
    """
    service = TripService(db)
    try:
        estimate = await service.get_trip_estimate(pickup_lat, pickup_lng, dropoff_lat, dropoff_lng)
        return estimate
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"預估計算失敗: {str(e)}"
        )

@router.post("/", response_model=TripResponse)
async def create_trip_request(
    trip_data: TripCreate,
    db: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(require_passenger_role)
):
    """
    創建叫車請求 (乘客端)
    """
    service = TripService(db)
    try:
        trip = await service.create_trip_request(current_user.id, trip_data)
        
        # 暫時禁用自動配對，讓司機手動接單
        # # 自動觸發配對 (異步)
        # try:
        #     match_result = await service.find_and_match_driver(trip.trip_id)
        #     if match_result:
        #         # 這裡可以發送推送通知給司機
        #         pass
        # except Exception as e:
        #     # 配對失敗不影響行程創建
        #     pass
        
        return trip
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"創建行程失敗: {str(e)}"
        )

@router.post("/{trip_id}/match", response_model=Optional[DriverTripInfo])
async def match_driver(
    trip_id: int,
    db: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """
    手動觸發司機配對 (管理員或乘客)
    """
    service = TripService(db)
    try:
        match_result = await service.find_and_match_driver(trip_id)
        return match_result
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"配對失敗: {str(e)}"
        )

@router.post("/{trip_id}/accept")
async def accept_trip(
    trip_id: int,
    accept_data: TripAcceptRequest,
    db: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(require_driver_role)
):
    """
    司機接受行程
    """
    service = TripService(db)
    try:
        result = await service.accept_trip(trip_id, current_user.id, accept_data.estimated_arrival_minutes)
        # accept_trip 返回一個包含 trip 和 escrow_transaction 的字典
        return {
            "success": True,
            "trip": result["trip"],
            "escrow_transaction": result.get("escrow_transaction"),
            "message": "接單成功"
        }
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"接受行程失敗: {str(e)}"
        )

@router.put("/{trip_id}/pickup", response_model=TripResponse)
async def pickup_passenger(
    trip_id: int,
    db: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(require_driver_role)
):
    """
    確認乘客上車
    """
    service = TripService(db)
    try:
        trip = await service.pickup_passenger(trip_id, current_user.id)
        return trip
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"確認上車失敗: {str(e)}"
        )

@router.put("/{trip_id}/complete")
async def complete_trip(
    trip_id: int,
    db: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(require_driver_role)
):
    """
    完成行程並處理支付
    """
    service = TripService(db)
    try:
        result = await service.complete_trip(trip_id, current_user.id)
        return {
            "success": True,
            "message": "行程完成並已處理支付",
            "trip": result["trip"],
            "payment": result["payment"]
        }
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"完成行程失敗: {str(e)}"
        )

@router.put("/{trip_id}/cancel", response_model=TripResponse)
async def cancel_trip(
    trip_id: int,
    cancel_data: TripCancelRequest,
    db: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """
    取消行程
    """
    service = TripService(db)
    try:
        trip = await service.cancel_trip(
            trip_id, current_user.id, cancel_data.reason, cancel_data.cancelled_by
        )
        return trip
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"取消行程失敗: {str(e)}"
        )

@router.get("/available", response_model=List[TripSummary])
async def get_available_trips(
    limit: int = Query(10, ge=1, le=50, description="返回數量"),
    offset: int = Query(0, ge=0, description="偏移量"),
    db: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(require_driver_role)
):
    """
    獲取可接單的行程列表（司機端）
    只返回狀態為 'requested' 且未被接單的行程
    """
    from sqlalchemy import select, desc
    from app.models.ride import Trip
    
    try:
        # 查詢可用行程：狀態為 requested 且沒有司機
        query = select(Trip).where(
            Trip.status == 'requested',
            Trip.driver_id.is_(None)
        ).order_by(desc(Trip.requested_at)).offset(offset).limit(limit)
        
        result = await db.execute(query)
        trips = result.scalars().all()
        
        # 轉換為摘要格式
        summaries = []
        for trip in trips:
            summaries.append(TripSummary(
                trip_id=trip.trip_id,
                status=trip.status,
                pickup_address=trip.pickup_address,
                dropoff_address=trip.dropoff_address,
                distance_km=trip.distance_km,
                total_amount=int(trip.total_amount * 1000000) if trip.total_amount else None,
                requested_at=trip.requested_at,
                completed_at=trip.completed_at
            ))
        
        return summaries
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"獲取可用行程失敗: {str(e)}"
        )

@router.get("/{trip_id}", response_model=TripResponse)
async def get_trip_details(
    trip_id: int,
    db: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """
    獲取行程詳情
    """
    service = TripService(db)
    try:
        trip = await service._get_trip_by_id(trip_id)
        if not trip:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="行程不存在"
            )
        
        # 檢查權限 (只有乘客或司機可以查看)
        if trip.user_id != current_user.id and trip.driver_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="無權限查看此行程"
            )
        
        return await service._build_trip_response(trip)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"獲取行程詳情失敗: {str(e)}"
        )

@router.get("/", response_model=List[TripSummary])
async def get_user_trips(
    status: Optional[str] = Query(None, description="篩選狀態"),
    limit: int = Query(20, ge=1, le=100, description="返回數量"),
    offset: int = Query(0, ge=0, description="偏移量"),
    db: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """
    獲取用戶行程列表 (乘客和司機)
    """
    from sqlalchemy import select, or_, desc
    from app.models.ride import Trip
    
    try:
        # 構建查詢
        query = select(Trip).where(
            or_(Trip.user_id == current_user.id, Trip.driver_id == current_user.id)
        )
        
        if status:
            query = query.where(Trip.status == status)
        
        query = query.order_by(desc(Trip.requested_at)).offset(offset).limit(limit)
        
        result = await db.execute(query)
        trips = result.scalars().all()
        
        # 轉換為摘要格式
        summaries = []
        for trip in trips:
            summaries.append(TripSummary(
                trip_id=trip.trip_id,
                status=trip.status,
                pickup_address=trip.pickup_address,
                dropoff_address=trip.dropoff_address,
                distance_km=trip.distance_km,
                total_amount=int(trip.total_amount * 1000000) if trip.total_amount else None,
                requested_at=trip.requested_at,
                completed_at=trip.completed_at
            ))
        
        return summaries
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"獲取行程列表失敗: {str(e)}"
        )

# 區塊鏈支付相關端點

@router.get("/payment/wallet/balance", response_model=WalletBalance)
async def get_wallet_balance(
    current_user: User = Depends(get_current_user)
):
    """
    查詢用戶錢包餘額
    """
    try:
        balance = await iota_service.get_wallet_balance(current_user.wallet_address)
        return balance
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"查詢錢包餘額失敗: {str(e)}"
        )

@router.get("/payment/transaction/{tx_hash}", response_model=TransactionStatus)
async def get_transaction_status(
    tx_hash: str,
    current_user: User = Depends(get_current_user)
):
    """
    查詢區塊鏈交易狀態
    """
    try:
        status_info = await iota_service.get_transaction_status(tx_hash)
        return status_info
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"查詢交易狀態失敗: {str(e)}"
        )

@router.post("/{trip_id}/confirm-payment", response_model=TripResponse)
async def confirm_payment_lock(
    trip_id: int,
    escrow_object_id: str = Query(..., description="託管對象 ID"),
    db: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """
    確認支付已鎖定，保存託管對象 ID
    """
    service = TripService(db)
    try:
        # 獲取行程
        trip = await service._get_trip_by_id(trip_id)
        if not trip:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="行程不存在"
            )
        
        # 檢查權限（乘客或司機都可以確認）
        if trip.user_id != current_user.id and trip.driver_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="無權限確認此行程支付"
            )
        
        # 調用服務層方法保存託管 ID
        result = await service.confirm_payment_lock(trip_id, escrow_object_id)
        
        return result
        
    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"確認支付失敗: {str(e)}"
        )

@router.post("/{trip_id}/verify-payment")
async def verify_trip_payment(
    trip_id: int,
    tx_hash: str = Query(..., description="交易 Hash"),
    db: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """
    驗證行程支付交易 - 完整驗證金額和收款地址
    """
    service = TripService(db)
    try:
        # 獲取行程
        trip = await service._get_trip_by_id(trip_id)
        if not trip:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="行程不存在"
            )
        
        # 檢查權限
        if trip.user_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="無權限驗證此行程"
            )
        
        # 計算預期金額（micro SUI 轉為 MIST）
        # 1 SUI = 1,000,000 micro SUI = 1,000,000,000 MIST
        expected_amount_micro_sui = int(trip.fare * 1000000) if trip.fare else 0
        expected_amount_mist = expected_amount_micro_sui * 1000
        
        # 預期收款地址（智能合約地址或平台地址）
        expected_recipient = settings.CONTRACT_PACKAGE_ID or settings.PLATFORM_WALLET
        
        logger.info(f"🔍 驗證支付: trip={trip_id}, tx={tx_hash[:20]}...")
        logger.info(f"   預期金額: {expected_amount_mist} MIST ({expected_amount_micro_sui} micro SUI)")
        logger.info(f"   預期收款: {expected_recipient[:20]}...")
        
        # 完整驗證交易
        verification = await iota_service.verify_payment_transaction(
            tx_hash=tx_hash,
            expected_recipient=expected_recipient,
            expected_amount=expected_amount_mist
        )
        
        if not verification.get("valid"):
            error_msg = verification.get('error', '未知錯誤')
            logger.error(f"❌ 驗證失敗: {error_msg}")
            return {
                "success": False,
                "error": error_msg,
                "message": f"支付驗證失敗: {error_msg}",
                "transaction_hash": tx_hash
            }
        
        # 驗證成功，更新行程支付狀態
        from app.models.ride import Trip
        trip.payment_status = "completed"
        trip.payment_tx_hash = tx_hash
        trip.escrow_object_id = tx_hash
        await db.commit()
        
        logger.info(f"✅ 支付驗證成功: trip={trip_id}")
        
        return {
            "success": True,
            "message": "支付驗證成功",
            "trip_id": trip_id,
            "tx_hash": tx_hash,
            "amount_verified": verification.get("amount_received"),
            "recipient_verified": verification.get("recipient")
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"驗證支付異常: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"驗證支付失敗: {str(e)}"
        )