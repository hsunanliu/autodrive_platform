from datetime import datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.core.database import get_async_session
from app.dependencies.admin import get_current_admin
from app.models import User, Vehicle
from app.schemas.admin import VehicleStatusUpdate

router = APIRouter(prefix="/admin/vehicles", tags=["admin-vehicles"])

VALID_VEHICLE_STATUSES = {"available", "on_trip", "offline", "maintenance"}


@router.get("")
async def list_vehicles(
    status: str | None = Query(default=None),
    search_type: str | None = Query(default=None),
    search_value: str | None = Query(default=None),
    _=Depends(get_current_admin),
    session: AsyncSession = Depends(get_async_session),
):
    stmt = select(Vehicle).options(joinedload(Vehicle.owner)).order_by(Vehicle.vehicle_id.desc())

    if status:
        stmt = stmt.where(Vehicle.status == status)

    if search_type and search_value:
        if search_type == "plate_number":
            stmt = stmt.where(Vehicle.plate_number.ilike(f"%{search_value}%"))
        elif search_type == "model":
            stmt = stmt.where(Vehicle.model.ilike(f"%{search_value}%"))
        elif search_type == "owner_name":
            stmt = stmt.join(Vehicle.owner).where(
                or_(
                    User.display_name.ilike(f"%{search_value}%"),
                    User.username.ilike(f"%{search_value}%"),
                )
            )
        elif search_type == "owner_id":
            try:
                owner_id = int(search_value)
            except ValueError as exc:
                raise HTTPException(status_code=400, detail="車主 ID 必須為數字") from exc
            stmt = stmt.where(Vehicle.owner_id == owner_id)

    vehicles = (await session.execute(stmt)).scalars().all()

    data: List[dict] = []
    for vehicle in vehicles:
        owner = vehicle.owner
        owner_name = None
        if owner:
            owner_name = owner.display_name or owner.username
        data.append(
            {
                "vehicle_id": vehicle.vehicle_id,
                "plate_number": vehicle.plate_number,
                "model": vehicle.model,
                "owner_id": vehicle.owner_id,
                "owner_name": owner_name,
                "owner_phone": owner.phone_number if owner else None,
                "owner_email": owner.email if owner else None,
                "battery_capacity_kWh": vehicle.battery_capacity_kwh,
                "current_charge_percent": vehicle.current_charge_percent,
                "location_lat": vehicle.current_lat,
                "location_lng": vehicle.current_lng,
                "status": vehicle.status,
                "updated_at": vehicle.updated_at.isoformat() if vehicle.updated_at else None,
            }
        )

    return data


@router.get("/{vehicle_id}")
async def get_vehicle(
    vehicle_id: str,
    _=Depends(get_current_admin),
    session: AsyncSession = Depends(get_async_session),
):
    vehicle = await session.get(Vehicle, vehicle_id)
    if not vehicle:
        raise HTTPException(status_code=404, detail="車輛不存在")

    owner = await session.get(User, vehicle.owner_id)
    owner_name = None
    if owner:
        owner_name = owner.display_name or owner.username

    return {
        "vehicle_id": vehicle.vehicle_id,
        "plate_number": vehicle.plate_number,
        "model": vehicle.model,
        "vehicle_type": vehicle.vehicle_type,
        "owner_id": vehicle.owner_id,
        "owner_name": owner_name,
        "owner_phone": owner.phone_number if owner else None,
        "owner_email": owner.email if owner else None,
        "battery_capacity_kWh": vehicle.battery_capacity_kwh,
        "current_charge_percent": vehicle.current_charge_percent,
        "location_lat": vehicle.current_lat,
        "location_lng": vehicle.current_lng,
        "status": vehicle.status,
        "is_active": vehicle.is_active,
        "created_at": vehicle.created_at.isoformat() if vehicle.created_at else None,
        "updated_at": vehicle.updated_at.isoformat() if vehicle.updated_at else None,
    }


@router.put("/{vehicle_id}/status")
async def update_vehicle_status(
    vehicle_id: str,
    payload: VehicleStatusUpdate,
    _=Depends(get_current_admin),
    session: AsyncSession = Depends(get_async_session),
):
    if payload.status not in VALID_VEHICLE_STATUSES:
        raise HTTPException(status_code=400, detail="無效的狀態值")

    vehicle = await session.get(Vehicle, vehicle_id)
    if not vehicle:
        raise HTTPException(status_code=404, detail="車輛不存在")

    vehicle.status = payload.status
    vehicle.updated_at = datetime.utcnow()
    await session.commit()

    return {"message": "車輛狀態已更新"}
