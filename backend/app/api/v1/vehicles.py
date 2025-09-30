# backend/app/api/v1/vehicles.py

"""
車輛管理 API
基於隊友Flask邏輯的FastAPI實現
"""

from fastapi import APIRouter, HTTPException, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, func
from typing import List, Optional
import time
import math
import random
import logging

logger = logging.getLogger(__name__)

from app.core.database import get_async_session
from app.models.vehicle import Vehicle
from app.models.user import User
from app.schemas.vehicle import VehicleResponse, VehicleCreate, VehicleUpdate, VehicleLocationUpdate
from app.api.deps import get_current_user
from app.services.location_service import LocationService
from app.services.contract_service import contract_service

router = APIRouter(prefix="/vehicles", tags=["vehicles"])

@router.get("/available", response_model=List[VehicleResponse])
async def get_available_vehicles(
    lat: float = Query(..., description="用戶當前緯度"),
    lng: float = Query(..., description="用戶當前經度"),
    radius_km: float = Query(4.0, description="搜尋半徑（公里）"),
    limit: int = Query(20, description="最大返回數量"),
    session: AsyncSession = Depends(get_async_session)
):
    """
    取得附近可用車輛（複用隊友的隨機位置邏輯）
    在用戶附近隨機生成可用車的位置，並回傳車→用戶距離
    """
    # 查詢可用車輛
    result = await session.execute(
        select(Vehicle).where(
            and_(
                Vehicle.status == "available",
                Vehicle.is_active == True
            )
        ).limit(limit)
    )
    vehicles = result.scalars().all()
    
    # 以分鐘為單位的 seed，1 分鐘內保持穩定（複用隊友邏輯）
    minute_bucket = int(time.time() // 60)
    
    vehicle_list = []
    for vehicle in vehicles:
        # 在用戶附近隨機生成車輛位置
        rand_lat, rand_lng = LocationService.random_point_near(
            lat, lng, radius_km=radius_km,
            seed=f"{vehicle.vehicle_id}-{minute_bucket}"
        )
        
        # 計算距離
        distance_km = LocationService.haversine_km(lat, lng, rand_lat, rand_lng)
        
        # 創建 VehicleResponse 對象，包含所有必要欄位
        vehicle_response = VehicleResponse(
            vehicle_id=vehicle.vehicle_id,
            owner_id=vehicle.owner_id,
            plate_number=vehicle.plate_number,
            model=vehicle.model,
            vehicle_type=vehicle.vehicle_type,
            battery_capacity_kwh=vehicle.battery_capacity_kwh,
            current_charge_percent=vehicle.current_charge_percent,
            current_lat=vehicle.current_lat,
            current_lng=vehicle.current_lng,
            status=vehicle.status,
            is_active=vehicle.is_active,
            blockchain_object_id=vehicle.blockchain_object_id,
            hourly_rate=vehicle.hourly_rate,
            total_trips=vehicle.total_trips,
            total_distance_km=vehicle.total_distance_km,
            total_earnings_micro_iota=vehicle.total_earnings_micro_iota,
            created_at=vehicle.created_at,
            updated_at=vehicle.updated_at,
            last_active_at=vehicle.last_active_at,
            # 計算欄位
            location_lat=rand_lat,  # 隨機生成的位置
            location_lng=rand_lng,
            distance_km=round(distance_km, 2),
            estimated_arrival_minutes=max(3, int(distance_km * 2))  # 估算到達時間
        )
        vehicle_list.append(vehicle_response)
    
    # 按距離排序
    vehicle_list.sort(key=lambda x: x.distance_km)
    
    return vehicle_list

@router.post("/", response_model=VehicleResponse)
async def register_vehicle(
    vehicle_data: VehicleCreate,
    session: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """註冊新車輛（司機端）"""
    
    # 檢查車牌是否已存在
    result = await session.execute(
        select(Vehicle).where(Vehicle.plate_number == vehicle_data.plate_number)
    )
    if result.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="車牌號碼已存在")
    
    # 檢查車輛ID是否已存在
    result = await session.execute(
        select(Vehicle).where(Vehicle.vehicle_id == vehicle_data.vehicle_id)
    )
    if result.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="車輛ID已存在")
    
    # 創建車輛
    vehicle = Vehicle(
        vehicle_id=vehicle_data.vehicle_id,
        owner_id=current_user.id,
        plate_number=vehicle_data.plate_number,
        model=vehicle_data.model,
        vehicle_type=vehicle_data.vehicle_type,
        battery_capacity_kwh=vehicle_data.battery_capacity_kwh,
        current_charge_percent=vehicle_data.current_charge_percent,
        current_lat=vehicle_data.current_lat,
        current_lng=vehicle_data.current_lng,
        hourly_rate=vehicle_data.hourly_rate,
        blockchain_object_id=vehicle_data.blockchain_object_id
    )
    
    session.add(vehicle)
    await session.commit()
    await session.refresh(vehicle)
    
    # 在智能合約中註冊車輛
    try:
        contract_result = await contract_service.register_vehicle_on_chain(
            owner_address=current_user.wallet_address,
            vehicle_data={
                "vehicle_id": vehicle.vehicle_id,
                "vehicle_type": vehicle.vehicle_type,
                "hourly_rate": vehicle.hourly_rate
            }
        )
        
        if contract_result.get("success"):
            # 更新車輛的區塊鏈對象ID
            vehicle.blockchain_object_id = contract_result.get("object_id")
            await session.commit()
            logger.info(f"✅ Vehicle registered on blockchain: {contract_result['transaction_hash']}")
        else:
            logger.warning(f"⚠️ Vehicle blockchain registration failed: {contract_result.get('error')}")
            
    except Exception as e:
        logger.error(f"❌ Vehicle blockchain registration error: {e}")
        # 不影響車輛創建
    
    return vehicle

@router.put("/{vehicle_id}/location")
async def update_vehicle_location(
    vehicle_id: str,
    location_data: VehicleLocationUpdate,
    session: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """更新車輛位置（司機端實時更新）"""
    
    # 查找車輛
    result = await session.execute(
        select(Vehicle).where(
            and_(
                Vehicle.vehicle_id == vehicle_id,
                Vehicle.owner_id == current_user.id
            )
        )
    )
    vehicle = result.scalar_one_or_none()
    if not vehicle:
        raise HTTPException(status_code=404, detail="車輛不存在或無權限")
    
    # 更新位置
    vehicle.current_lat = location_data.lat
    vehicle.current_lng = location_data.lng
    vehicle.last_active_at = func.now()
    
    if location_data.status:
        vehicle.status = location_data.status
    
    await session.commit()
    
    return {"success": True, "message": "位置更新成功"}

@router.put("/{vehicle_id}/status")
async def update_vehicle_status(
    vehicle_id: str,
    status: str,
    session: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """更新車輛狀態"""
    
    result = await session.execute(
        select(Vehicle).where(
            and_(
                Vehicle.vehicle_id == vehicle_id,
                Vehicle.owner_id == current_user.id
            )
        )
    )
    vehicle = result.scalar_one_or_none()
    if not vehicle:
        raise HTTPException(status_code=404, detail="車輛不存在或無權限")
    
    if status not in ["available", "on_trip", "offline", "maintenance"]:
        raise HTTPException(status_code=400, detail="無效的車輛狀態")
    
    vehicle.status = status
    await session.commit()
    
    return {"success": True, "status": status}

@router.get("/my", response_model=List[VehicleResponse])
async def get_my_vehicles(
    session: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """取得我的車輛列表"""
    
    result = await session.execute(
        select(Vehicle).where(Vehicle.owner_id == current_user.id)
    )
    vehicles = result.scalars().all()
    
    return vehicles

@router.get("/{vehicle_id}", response_model=VehicleResponse)
async def get_vehicle_details(
    vehicle_id: str,
    session: AsyncSession = Depends(get_async_session)
):
    """取得車輛詳細資訊"""
    
    result = await session.execute(
        select(Vehicle).where(Vehicle.vehicle_id == vehicle_id)
    )
    vehicle = result.scalar_one_or_none()
    if not vehicle:
        raise HTTPException(status_code=404, detail="車輛不存在")
    
    return vehicle
