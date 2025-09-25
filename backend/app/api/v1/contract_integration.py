# backend/app/api/v1/contract_integration.py

"""
智能合約整合 API
與您的 Move 合約深度整合
"""

from fastapi import APIRouter, HTTPException, Depends, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_

from app.core.database import get_async_session
from app.models.user import User
from app.models.vehicle import Vehicle
from app.models.trip import Trip
from app.schemas.contract import ContractUserRegister, ContractVehicleRegister, ContractRideRequest, TransactionConfirmation
from app.api.deps import get_current_user
from app.services.iota_contract_service import get_iota_contract_service, ContractStatus

router = APIRouter(prefix="/api/contract", tags=["smart-contract"])

# === 用戶合約整合 ===

@router.post("/register-user")
async def register_user_with_contract(
    user_data: ContractUserRegister,
    session: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """用戶註冊到智能合約"""
    
    # 檢查用戶是否已有區塊鏈對象
    if current_user.blockchain_object_id:
        return {
            "status": "already_registered",
            "blockchain_object_id": current_user.blockchain_object_id,
            "message": "用戶已在區塊鏈上註冊"
        }
    
    # 準備智能合約調用
    contract_service = get_iota_contract_service()
    result = await contract_service.register_user_on_blockchain(
        signer_address=current_user.wallet_address,
        name=user_data.name,
        did_identifier=user_data.did_identifier
    )
    
    if result["status"] == "error":
        raise HTTPException(status_code=400, detail=result["error"])
    
    return {
        "status": "contract_prepared",
        "blockchain_transaction": result,
        "instructions": [
            "1. 使用錢包簽署交易",
            "2. 獲得交易摘要後，調用 /confirm-user-registration",
            "3. 等待區塊鏈確認"
        ]
    }

@router.post("/confirm-user-registration")
async def confirm_user_registration(
    confirmation: TransactionConfirmation,
    background_tasks: BackgroundTasks,
    session: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """確認用戶註冊交易"""
    
    contract_service = get_iota_contract_service()
    
    # 解析交易事件
    events_result = await contract_service.parse_contract_events(confirmation.tx_digest)
    
    if events_result["status"] == "events_parsed":
        for event in events_result["events"]:
            if event["event_type"] == "user_registered" and event["owner"] == current_user.wallet_address:
                # 更新用戶的區塊鏈對象ID
                current_user.blockchain_object_id = event["user_id"]
                current_user.display_name = event["name"]
                await session.commit()
                
                return {
                    "status": "registration_confirmed",
                    "user_id": event["user_id"],
                    "tx_digest": confirmation.tx_digest,
                    "message": "用戶已成功註冊到區塊鏈"
                }
    
    return {
        "status": "confirmation_pending",
        "tx_digest": confirmation.tx_digest,
        "message": "交易確認中，請稍後再試"
    }

# === 車輛合約整合 ===

@router.post("/register-vehicle")
async def register_vehicle_with_contract(
    vehicle_data: ContractVehicleRegister,
    session: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """車輛註冊到智能合約"""
    
    # 檢查車牌號是否已存在
    result = await session.execute(
        select(Vehicle).where(Vehicle.plate_number == vehicle_data.license_plate)
    )
    if result.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="車牌號已存在")
    
    # 準備智能合約調用
    contract_service = get_iota_contract_service()
    result = await contract_service.register_vehicle_on_blockchain(
        signer_address=current_user.wallet_address,
        license_plate=vehicle_data.license_plate,
        model=vehicle_data.model,
        is_autonomous=vehicle_data.is_autonomous,
        hourly_rate=vehicle_data.hourly_rate
    )
    
    if result["status"] == "error":
        raise HTTPException(status_code=400, detail=result["error"])
    
    return {
        "status": "contract_prepared",
        "blockchain_transaction": result,
        "vehicle_data": vehicle_data.dict()
    }

@router.post("/update-vehicle-status/{vehicle_id}")
async def update_vehicle_status_on_contract(
    vehicle_id: str,
    new_status: str,
    session: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """更新車輛狀態到智能合約"""
    
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
    if not vehicle or not vehicle.blockchain_object_id:
        raise HTTPException(status_code=404, detail="車輛不存在或未在區塊鏈註冊")
    
    # 準備狀態更新交易
    contract_service = get_iota_contract_service()
    result = await contract_service.update_vehicle_status_on_blockchain(
        signer_address=current_user.wallet_address,
        vehicle_object_id=vehicle.blockchain_object_id,
        new_status=new_status
    )
    
    if result["status"] == "error":
        raise HTTPException(status_code=400, detail=result["error"])
    
    return {
        "status": "status_update_prepared",
        "vehicle_id": vehicle_id,
        "status_change": result["status_change"],
        "blockchain_transaction": result["transaction_data"]
    }

# === 叫車合約整合 ===

@router.post("/create-ride-request")
async def create_ride_request_on_contract(
    ride_data: ContractRideRequest,
    session: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """創建叫車請求到智能合約"""
    
    # 準備智能合約調用
    contract_service = get_iota_contract_service()
    result = await contract_service.create_ride_request_on_blockchain(
        signer_address=current_user.wallet_address,
        pickup_lat=ride_data.pickup_lat,
        pickup_lng=ride_data.pickup_lng,
        dest_lat=ride_data.dest_lat,
        dest_lng=ride_data.dest_lng,
        max_price=ride_data.max_price,
        passenger_count=ride_data.passenger_count
    )
    
    if result["status"] == "error":
        raise HTTPException(status_code=400, detail=result["error"])
    
    # 創建本地行程記錄（待確認狀態）
    trip = Trip(
        user_id=current_user.id,
        pickup_lat=ride_data.pickup_lat,
        pickup_lng=ride_data.pickup_lng,
        dropoff_lat=ride_data.dest_lat,
        dropoff_lng=ride_data.dest_lng,
        passenger_count=ride_data.passenger_count,
        payment_amount_micro_iota=str(ride_data.max_price),
        status="blockchain_pending"
    )
    
    session.add(trip)
    await session.commit()
    
    return {
        "status": "ride_request_prepared",
        "local_trip_id": trip.trip_id,
        "blockchain_transaction": result,
        "ride_details": result["ride_details"]
    }

# === 狀態同步工具 ===

@router.get("/sync-status/{object_type}/{object_id}")
async def sync_blockchain_status(
    object_type: str,  # "user", "vehicle", "trip"
    object_id: str,
    session: AsyncSession = Depends(get_async_session)
):
    """同步區塊鏈對象狀態"""
    
    contract_service = get_iota_contract_service()
    
    try:
        # 從區塊鏈查詢對象
        blockchain_object = await contract_service.get_object(object_id)
        
        if not blockchain_object:
            return {
                "status": "object_not_found",
                "object_id": object_id,
                "object_type": object_type
            }
        
        # 解析對象數據
        object_data = blockchain_object.get("data", {}).get("content", {}).get("fields", {})
        
        if object_type == "vehicle":
            # 同步車輛狀態
            move_status = object_data.get("status")
            if move_status is not None:
                backend_status = ContractStatus.VEHICLE_STATUS_MOVE_TO_BACKEND.get(int(move_status))
                
                # 更新本地車輛狀態
                result = await session.execute(
                    select(Vehicle).where(Vehicle.blockchain_object_id == object_id)
                )
                vehicle = result.scalar_one_or_none()
                if vehicle:
                    vehicle.status = backend_status
                    await session.commit()
                
                return {
                    "status": "synced",
                    "object_type": "vehicle",
                    "blockchain_status": move_status,
                    "backend_status": backend_status,
                    "updated": True
                }
        
        return {
            "status": "sync_completed",
            "object_type": object_type,
            "blockchain_data": object_data
        }
        
    except Exception as e:
        return {
            "status": "sync_failed",
            "error": str(e),
            "object_id": object_id
        }
