# Placeholder for vehicle schema
# backend/app/schemas/vehicle.py

from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class VehicleBase(BaseModel):
    plate_number: str = Field(..., description="車牌號碼")
    model: str = Field(..., description="車輛型號")
    vehicle_type: Optional[str] = Field("sedan", description="車輛類型")
    battery_capacity_kwh: Optional[float] = None
    current_charge_percent: Optional[float] = 100.0
    hourly_rate: Optional[int] = 100

class VehicleCreate(VehicleBase):
    vehicle_id: str = Field(..., description="車輛ID")
    current_lat: Optional[float] = None
    current_lng: Optional[float] = None
    blockchain_object_id: Optional[str] = None

class VehicleUpdate(BaseModel):
    plate_number: Optional[str] = None
    model: Optional[str] = None
    vehicle_type: Optional[str] = None
    battery_capacity_kwh: Optional[float] = None
    current_charge_percent: Optional[float] = None
    hourly_rate: Optional[int] = None
    status: Optional[str] = None

class VehicleLocationUpdate(BaseModel):
    lat: float
    lng: float
    status: Optional[str] = None

class VehicleResponse(VehicleBase):
    vehicle_id: str
    owner_id: int
    current_lat: Optional[float]
    current_lng: Optional[float]
    status: str
    is_active: bool
    total_trips: int
    total_distance_km: float
    created_at: datetime
    updated_at: Optional[datetime]
    
    # 額外的計算字段（用於附近車輛查詢）
    location_lat: Optional[float] = None
    location_lng: Optional[float] = None
    distance_km: Optional[float] = None
    estimated_arrival_minutes: Optional[int] = None
    
    class Config:
        from_attributes = True
