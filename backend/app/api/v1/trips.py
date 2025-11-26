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
    TripAcceptRequest, DriverTripInfo, TripSummary, PaymentConfirmation
)
from app.schemas.payment import WalletBalance, TransactionStatus, PaymentStatus
from app.config import settings
from app.websocket.dependencies import get_notifier
from app.websocket.notifier import WebSocketNotifier
from app.services.fcm_service import fcm_service
from sqlalchemy import select, and_, or_

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
    current_user: User = Depends(require_passenger_role),
    notifier: WebSocketNotifier = Depends(get_notifier)
):
    """
    創建叫車請求 (乘客端)
    """
    service = TripService(db)
    try:
        trip = await service.create_trip_request(current_user.id, trip_data)

        # WebSocket 推送新訂單給所有在線司機
        try:
            trip_info = {
                'trip_id': trip['trip_id'],
                'pickup_lat': trip['pickup_lat'],
                'pickup_lng': trip['pickup_lng'],
                'pickup_address': trip['pickup_address'],
                'dropoff_lat': trip['dropoff_lat'],
                'dropoff_lng': trip['dropoff_lng'],
                'dropoff_address': trip['dropoff_address'],
                'distance_km': trip['distance_km'],
                'estimated_fare_sui': trip['total_amount'] / 1_000_000_000,  # 轉換為 SUI
                'passenger_count': trip['passenger_count'],
                'priority': trip.get('priority', 2),
                'surge_reason': trip.get('surge_reason'),
                'waypoints': trip.get('waypoints', [])
            }
            await notifier.notify_new_trip_available(trip['trip_id'], trip_info)
            logger.info(f"✅ 已推送新訂單 {trip['trip_id']} 給所有在線司機")
        except Exception as e:
            logger.error(f"❌ WebSocket 推送失敗: {e}")
            # 推送失敗不影響訂單創建

        # FCM 推送通知給所有在線司機
        try:
            # 使用新的 session 查詢司機（避免 greenlet 錯誤）
            from app.core.database import async_session_maker
            async with async_session_maker() as fcm_session:
                result = await fcm_session.execute(
                    select(User).where(
                        and_(
                            or_(User.user_type == 'driver', User.user_type == 'both'),
                            User.fcm_token.isnot(None),
                            User.is_active == True
                        )
                    )
                )
                drivers = result.scalars().all()

                # 發送推送通知給每個司機
                estimated_earnings = trip['total_amount'] / 1_000_000_000  # 轉換為 SUI
                notification_count = 0

                for driver in drivers:
                    if driver.fcm_token:
                        success = await fcm_service.send_new_trip_notification(
                            fcm_token=driver.fcm_token,
                            trip_id=trip['trip_id'],
                            pickup_address=trip['pickup_address'],
                            dropoff_address=trip['dropoff_address'],
                            estimated_earnings=estimated_earnings
                        )
                        if success:
                            notification_count += 1

                if notification_count > 0:
                    logger.info(f"✅ 已發送 {notification_count} 條 FCM 推送通知")
                else:
                    logger.warning("⚠️ 沒有司機收到 FCM 推送通知")

        except Exception as e:
            logger.error(f"❌ FCM 推送失敗: {e}")
            # FCM 推送失敗不影響訂單創建

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
        trip = result["trip"]

        # WebSocket 推送：通知乘客司機已接單
        notifier = get_notifier()
        if notifier:
            try:
                driver_info = {
                    "id": current_user.id,
                    "username": current_user.username,
                    "phone": current_user.phone_number,
                    "estimated_arrival": accept_data.estimated_arrival_minutes
                }
                await notifier.notify_trip_accepted(trip_id, trip.passenger_id, driver_info)
                logger.info(f"已透過 WebSocket 通知乘客 {trip.passenger_id}：行程 {trip_id} 被接受")
            except Exception as ws_error:
                logger.error(f"WebSocket 推送失敗: {ws_error}")
                # 不影響主要流程

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
    current_user: User = Depends(require_passenger_role)
):
    """
    乘客確認上車（自駕車到達後，由乘客確認）
    """
    service = TripService(db)
    try:
        trip = await service.pickup_passenger(trip_id, current_user.id)

        # WebSocket 推送：通知行程已開始
        notifier = get_notifier()
        if notifier:
            try:
                await notifier.notify_trip_started(trip_id)
                logger.info(f"已透過 WebSocket 通知行程 {trip_id} 開始")
            except Exception as ws_error:
                logger.error(f"WebSocket 推送失敗: {ws_error}")

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
        trip = result["trip"]

        # WebSocket 推送：通知行程完成
        notifier = get_notifier()
        if notifier:
            try:
                await notifier.notify_trip_completed(trip_id)
                logger.info(f"已透過 WebSocket 通知行程 {trip_id} 完成")

                # 如果支付成功，也推送支付完成通知
                payment = result.get("payment")
                if payment and payment.get("status") == "completed":
                    await notifier.notify_payment_completed(
                        trip_id,
                        trip.passenger_id,
                        trip.driver_id,
                        float(trip.final_fare)
                    )
                    logger.info(f"已透過 WebSocket 通知行程 {trip_id} 支付完成")
            except Exception as ws_error:
                logger.error(f"WebSocket 推送失敗: {ws_error}")

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

    排序規則：
    1. 優先顯示 priority 1（快速叫車/動態定價）
    2. 然後顯示 priority 2（標準叫車/固定價格）
    3. 同優先級內按創建時間排序
    """
    from sqlalchemy import select, asc
    from app.models.ride import Trip

    try:
        # 查詢可用行程：狀態為 requested 且沒有司機
        # 按優先級升序（1 在前, 2 在後），然後按創建時間升序
        query = select(Trip).where(
            Trip.status == 'requested',
            Trip.driver_id.is_(None)
        ).order_by(
            asc(Trip.priority),      # Priority 1 優先顯示
            asc(Trip.requested_at)   # 同優先級內，先創建的先顯示
        ).offset(offset).limit(limit)

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
                pickup_lat=trip.pickup_lat,
                pickup_lng=trip.pickup_lng,
                dropoff_lat=trip.dropoff_lat,
                dropoff_lng=trip.dropoff_lng,
                distance_km=trip.distance_km,
                total_amount=trip.total_amount,  # 直接使用 SUI float 值
                passenger_count=trip.passenger_count,
                requested_at=trip.requested_at,
                completed_at=trip.completed_at,
                # 動態定價資訊
                priority=trip.priority,
                price_type=trip.price_type,
                surge_multiplier=trip.surge_multiplier,
                surge_reason=trip.surge_reason
            ))

        return summaries
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"獲取可用行程失敗: {str(e)}"
        )

@router.get("/my-active", response_model=Optional[TripResponse])
async def get_my_active_trip(
    db: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(require_driver_role)
):
    """
    獲取司機的當前進行中行程
    返回狀態為 accepted, picked_up, in_progress 的行程
    如果有多個進行中行程，返回最新的一個
    """
    from sqlalchemy import select, or_
    from sqlalchemy.orm import selectinload
    from app.models.ride import Trip

    try:
        # 查詢該司機的進行中行程（取最新的一個）
        # 預加載 waypoints 關聯避免異步問題
        query = select(Trip).where(
            Trip.driver_id == current_user.id,
            or_(
                Trip.status == 'accepted',
                Trip.status == 'picked_up',
                Trip.status == 'in_progress'
            )
        ).options(selectinload(Trip.waypoints)).order_by(Trip.requested_at.desc()).limit(1)

        result = await db.execute(query)
        trip = result.scalar_one_or_none()

        if not trip:
            return None

        service = TripService(db)
        return await service._build_trip_response(trip)
    except Exception as e:
        logger.error(f"獲取進行中行程失敗: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"獲取進行中行程失敗: {str(e)}"
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

@router.get("/{trip_id}/route")
async def get_trip_route(
    trip_id: int,
    db: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """
    獲取行程路線

    返回從起點→停靠點→終點的完整路線點集合
    用於在地圖上繪製路線
    """
    from app.services.directions_service import directions_service

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
        if trip.user_id != current_user.id and trip.driver_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="無權限查看此行程"
            )

        # 準備停靠點列表
        waypoints = None
        if trip.waypoints and len(trip.waypoints) > 0:
            waypoints = [(wp.lat, wp.lng) for wp in sorted(trip.waypoints, key=lambda x: x.sequence)]

        # 獲取路線
        route_points = await directions_service.get_route(
            origin_lat=trip.pickup_lat,
            origin_lng=trip.pickup_lng,
            dest_lat=trip.dropoff_lat,
            dest_lng=trip.dropoff_lng,
            waypoints=waypoints
        )

        # 計算總距離和時間（使用行程已有數據）
        distance_meters = trip.distance_km * 1000 if trip.distance_km else 0
        duration_seconds = trip.estimated_duration_minutes * 60 if trip.estimated_duration_minutes else 0

        # 返回路線點
        return {
            "success": True,
            "trip_id": trip_id,
            "route_points": [{"lat": p.lat, "lng": p.lng} for p in route_points],
            "distance_meters": distance_meters,
            "duration_seconds": duration_seconds,
            "waypoints": [
                {
                    "sequence": wp.sequence,
                    "lat": wp.lat,
                    "lng": wp.lng,
                    "address": wp.address
                }
                for wp in sorted(trip.waypoints, key=lambda x: x.sequence)
            ] if trip.waypoints else []
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"獲取行程路線失敗: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"獲取行程路線失敗: {str(e)}"
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
    payment_data: PaymentConfirmation,
    db: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """
    確認支付已鎖定（通過交易哈希自動提取託管對象 ID）

    用戶只需提供從錢包獲得的交易哈希（tx_hash），
    後端會自動從區塊鏈查詢並提取 escrow_object_id。

    Request Body:
    {
        "tx_hash": "交易哈希字串（從 Sui 錢包獲得）"
    }
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

        # 調用服務層方法，傳入 tx_hash（自動提取並驗證 escrow_object_id）
        result = await service.confirm_payment_lock(trip_id, payment_data.tx_hash)

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

@router.post("/{trip_id}/escrow-payment")
async def create_escrow_payment(
    trip_id: int,
    request_body: dict,
    db: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """
    創建託管支付 - 調用智能合約 lock_payment

    此端點會使用後端的 operator 錢包調用智能合約創建託管支付。
    支付金額會被鎖定在智能合約中，直到行程完成後才會釋放給司機。

    參數:
    - trip_id: 行程 ID
    - amount_sui: 支付金額（SUI 格式）
    - driver_wallet: 司機錢包地址（可選，會從行程數據中獲取）

    返回:
    - success: 是否成功
    - tx_hash: 交易哈希
    - escrow_id: 託管對象 ID
    """
    service = TripService(db)
    try:
        # 從 request body 中提取參數
        amount_sui = request_body.get('amount_sui')
        driver_wallet = request_body.get('driver_wallet')

        if not amount_sui:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="缺少 amount_sui 參數"
            )

        # 獲取行程
        trip = await service._get_trip_by_id(trip_id)
        if not trip:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="行程不存在"
            )

        # 檢查權限（必須是乘客）
        if trip.user_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="無權限為此行程創建支付"
            )

        # 檢查行程狀態
        if trip.status not in ['accepted', 'in_progress']:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"行程狀態不正確：{trip.status}。只能為已接受或進行中的行程創建支付"
            )

        # 如果沒有提供司機錢包地址，從行程中獲取
        if not driver_wallet:
            if not trip.driver or not trip.driver.wallet_address:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="無法獲取司機錢包地址"
                )
            driver_wallet = trip.driver.wallet_address

        # 獲取乘客錢包地址
        passenger_wallet = current_user.wallet_address
        if not passenger_wallet:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="用戶未綁定錢包地址"
            )

        # 計算金額（轉換為 MIST）
        amount_mist = int(amount_sui * 1_000_000_000)

        # 計算平台費用（5%）
        platform_fee = int(amount_mist * 0.05)

        logger.info(f"🔒 創建託管支付:")
        logger.info(f"   行程 ID: {trip_id}")
        logger.info(f"   金額: {amount_sui} SUI ({amount_mist} MIST)")
        logger.info(f"   平台費用: {platform_fee} MIST")
        logger.info(f"   司機: {driver_wallet[:20]}...")
        logger.info(f"   乘客: {passenger_wallet[:20]}...")

        # 🎭 模擬模式：生成模擬交易哈希
        # 注意：這是為了讓用戶體驗流暢，實際支付應該由用戶手動調用智能合約
        import hashlib
        from datetime import datetime

        logger.info(f"🎭 使用模擬模式創建託管支付（用戶應手動調用智能合約）")

        # 生成模擬交易哈希
        mock_tx_data = f"{trip_id}{amount_mist}{passenger_wallet}{datetime.utcnow().isoformat()}"
        mock_tx_hash = "0xsimulated" + hashlib.sha256(mock_tx_data.encode()).hexdigest()[:54]
        mock_escrow_id = mock_tx_hash  # 使用相同的 ID

        # 更新行程的支付狀態為 pending
        # 注意：這裡只是記錄意圖，實際的支付需要用戶手動完成
        from app.models.ride import Trip
        trip.payment_status = "pending"
        trip.payment_tx_hash = mock_tx_hash
        trip.escrow_object_id = mock_escrow_id
        await db.commit()

        logger.info(f"✅ 託管支付記錄已創建（模擬模式）: {mock_tx_hash[:20]}...")
        logger.info(f"⚠️  用戶需要手動在錢包中調用智能合約完成真實支付")

        return {
            "success": True,
            "tx_hash": mock_tx_hash,
            "escrow_id": mock_escrow_id,
            "amount_mist": amount_mist,
            "platform_fee": platform_fee,
            "message": "支付意圖已記錄（模擬模式）\n請在錢包中手動調用智能合約完成支付",
            "mode": "simulated",
            "note": "這是模擬交易，實際支付需要在錢包中手動調用智能合約"
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"創建託管支付異常: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"創建託管支付失敗: {str(e)}"
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
    支持模擬支付模式：當 tx_hash 以 '0xtx' 或 '0xsimulated' 開頭時，跳過區塊鏈驗證
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

        # 檢測是否為模擬支付（開發/測試模式）
        is_simulated = tx_hash.startswith('0xtx') or tx_hash.startswith('0xsimulated')

        if is_simulated:
            # 模擬支付模式：直接標記為已支付，不驗證區塊鏈
            logger.info(f"🧪 模擬支付驗證: trip={trip_id}, tx={tx_hash[:20]}...")

            # 更新行程支付狀態
            from app.models.ride import Trip
            trip.payment_status = "completed"
            trip.payment_tx_hash = tx_hash
            trip.escrow_object_id = tx_hash
            await db.commit()

            logger.info(f"✅ 模擬支付驗證成功: trip={trip_id}")

            return {
                "success": True,
                "message": "模擬支付驗證成功（測試模式）",
                "trip_id": trip_id,
                "tx_hash": tx_hash,
                "simulated": True,
                "amount_verified": int(trip.fare * 1000000000) if trip.fare else 0,
            }

        # 真實支付模式：完整驗證區塊鏈交易
        # 計算預期金額（SUI 直接轉為 MIST）
        # 1 SUI = 1,000,000,000 MIST
        # 使用 total_amount（包含平台費的總金額），而非 fare（僅司機車資）
        expected_amount_mist = int(trip.total_amount * 1000000000) if trip.total_amount else 0

        # 預期收款地址（智能合約地址或平台地址）
        expected_recipient = settings.CONTRACT_PACKAGE_ID or settings.PLATFORM_WALLET

        logger.info(f"🔍 驗證支付: trip={trip_id}, tx={tx_hash[:20]}...")
        logger.info(f"   預期金額: {expected_amount_mist} MIST ({trip.total_amount} SUI total)")
        logger.info(f"   (司機車資: {trip.fare} SUI + 平台費: {(trip.total_amount - trip.fare) if trip.total_amount and trip.fare else 0} SUI)")
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
            "simulated": False,
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