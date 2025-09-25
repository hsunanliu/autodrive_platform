# backend/app/api/v1/trips.py

"""
行程管理 API
完整的叫車和行程生命週期管理
"""

from fastapi import APIRouter, HTTPException, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, desc
from typing import List, Optional
from datetime import datetime

from app.core.database import get_async_session
from app.models.trip import Trip
from app.models.vehicle import Vehicle
from app.models.user import User
from app.schemas.trip import TripResponse, TripCreate, TripStatusUpdate, StartTripRequest
from app.api.deps import get_current_user
from app.services.location_service import LocationService
from app.services.pricing_service import PricingService

router = APIRouter(prefix="/api/trips", tags=["trips"])

@router.post("/start", response_model=TripResponse)
async def start_trip(
    trip_data: StartTripRequest,
    session: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """
    發起叫車請求（複用隊友邏輯）
    若未帶 distance/fare，後端自動計算
    """
    
    # 計算距離和費用（複用隊友邏輯）
    distance_km = trip_data.distance_km
    if distance_km is None:
        distance_km = LocationService.haversine_km(
            trip_data.pickup_lat, trip_data.pickup_lng,
            trip_data.dropoff_lat, trip_data.dropoff_lng
        )
        distance_km = round(distance_km, 2)
    
    fare = trip_data.fare
    if fare is None:
        fare = PricingService.calculate_fare(distance_km)
    
    # 檢查車輛可用性
    if trip_data.vehicle_id:
        result = await session.execute(
            select(Vehicle).where(
                and_(
                    Vehicle.vehicle_id == trip_data.vehicle_id,
                    Vehicle.status == "available"
                )
            )
        )
        vehicle = result.scalar_one_or_none()
        if not vehicle:
            raise HTTPException(status_code=400, detail="車輛不可用")
    
    # 創建行程
    trip = Trip(
        user_id=current_user.id,
        vehicle_id=trip_data.vehicle_id,
        pickup_lat=trip_data.pickup_lat,
        pickup_lng=trip_data.pickup_lng,
        pickup_address=trip_data.pickup_address,
        dropoff_lat=trip_data.dropoff_lat,
        dropoff_lng=trip_data.dropoff_lng,
        dropoff_address=trip_data.dropoff_address,
        distance_km=distance_km,
        fare=fare,
        passenger_count=trip_data.passenger_count,
        status="matched" if trip_data.vehicle_id else "requested"
    )
    
    session.add(trip)
    
    # 如果有指定車輛，更新車輛狀態
    if trip_data.vehicle_id:
        vehicle.status = "on_trip"
    
    await session.commit()
    await session.refresh(trip)
    
    return trip

@router.post("/record", response_model=dict)
async def record_trip(
    trip_data: TripCreate,
    session: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """
    記錄完成的行程（複用隊友邏輯）
    寫入行程；若未帶 distance/fare，後端自動計算
    """
    
    # 自動計算距離和費用
    distance_km = trip_data.distance_km
    if distance_km is None:
        distance_km = LocationService.haversine_km(
            trip_data.pickup_lat, trip_data.pickup_lng,
            trip_data.dropoff_lat, trip_data.dropoff_lng
        )
        distance_km = round(distance_km, 2)
    
    fare = trip_data.fare
    if fare is None:
        fare = PricingService.calculate_fare(distance_km)
    
    # 創建已完成的行程記錄
    trip = Trip(
        user_id=current_user.id,
        vehicle_id=trip_data.vehicle_id,
        pickup_lat=trip_data.pickup_lat,
        pickup_lng=trip_data.pickup_lng,
        dropoff_lat=trip_data.dropoff_lat,
        dropoff_lng=trip_data.dropoff_lng,
        distance_km=distance_km,
        fare=fare,
        status="completed",
        picked_up_at=func.now(),
        dropped_off_at=func.now(),
        completed_at=func.now()
    )
    
    session.add(trip)
    
    # 將車輛標回可用
    if trip_data.vehicle_id:
        result = await session.execute(
            select(Vehicle).where(Vehicle.vehicle_id == trip_data.vehicle_id)
        )
        vehicle = result.scalar_one_or_none()
        if vehicle:
            vehicle.status = "available"
            vehicle.total_trips += 1
            vehicle.total_distance_km += distance_km
    
    await session.commit()
    
    return {
        "success": True,
        "distance_km": distance_km,
        "fare": fare
    }

@router.get("/", response_model=List[TripResponse])
async def get_my_trips(
    limit: int = Query(50, description="最大返回數量"),
    offset: int = Query(0, description="偏移量"),
    session: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """取得我的行程歷史"""
    
    result = await session.execute(
        select(Trip)
        .where(Trip.user_id == current_user.id)
        .order_by(desc(Trip.requested_at))
        .limit(limit)
        .offset(offset)
    )
    trips = result.scalars().all()
    
    return trips

@router.get("/latest", response_model=Optional[TripResponse])
async def get_latest_trip(
    session: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """取得最新的行程"""
    
    result = await session.execute(
        select(Trip)
        .where(Trip.user_id == current_user.id)
        .order_by(desc(Trip.requested_at))
        .limit(1)
    )
    trip = result.scalar_one_or_none()
    
    return trip

@router.get("/active", response_model=List[TripResponse])
async def get_active_trips(
    session: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """取得進行中的行程"""
    
    result = await session.execute(
        select(Trip).where(
            and_(
                Trip.user_id == current_user.id,
                Trip.status.in_(["requested", "matched", "picked_up", "in_progress"])
            )
        )
    )
    trips = result.scalars().all()
    
    return trips

@router.put("/{trip_id}/status")
async def update_trip_status(
    trip_id: int,
    status_update: TripStatusUpdate,
    session: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """更新行程狀態"""
    
    result = await session.execute(
        select(Trip).where(Trip.trip_id == trip_id)
    )
    trip = result.scalar_one_or_none()
    if not trip:
        raise HTTPException(status_code=404, detail="行程不存在")
    
    # 檢查權限（乘客或司機都可以更新）
    if trip.user_id != current_user.id and trip.driver_id != current_user.id:
        raise HTTPException(status_code=403, detail="無權限更新此行程")
    
    # 更新狀態
    trip.update_status(status_update.status)
    
    if status_update.cancellation_reason:
        trip.cancellation_reason = status_update.cancellation_reason
    
    await session.commit()
    
    return {"success": True, "status": trip.status}

@router.get("/{trip_id}", response_model=TripResponse)
async def get_trip_details(
    trip_id: int,
    session: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """取得行程詳細資訊"""
    
    result = await session.execute(
        select(Trip).where(Trip.trip_id == trip_id)
    )
    trip = result.scalar_one_or_none()
    if not trip:
        raise HTTPException(status_code=404, detail="行程不存在")
    
    # 檢查權限
    if trip.user_id != current_user.id and trip.driver_id != current_user.id:
        raise HTTPException(status_code=403, detail="無權限查看此行程")
    
    return trip
