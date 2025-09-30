# backend/app/schemas/vehicle.py
"""
Vehicle Pydantic 模型
車輛管理相關的數據結構
"""

from pydantic import BaseModel, Field, field_validator
from typing import Optional
from datetime import datetime

class VehicleBase(BaseModel):
    """車輛基礎模型"""
    plate_number: str = Field(..., min_length=6, max_length=20, description="車牌號碼")
    model: str = Field(..., min_length=1, max_length=50, description="車輛型號")
    vehicle_type: str = Field(..., description="車輛類型")
    battery_capacity_kwh: Optional[float] = Field(None, ge=0, description="電池容量(kWh)")
    hourly_rate: int = Field(..., ge=0, description="每小時費率(micro IOTA)")

class VehicleCreate(VehicleBase):
    """創建車輛模型"""
    vehicle_id: str = Field(..., min_length=3, max_length=20, description="車輛ID")
    current_charge_percent: float = Field(..., ge=0, le=100, description="當前電量百分比")
    current_lat: Optional[float] = Field(None, ge=-90, le=90, description="當前緯度")
    current_lng: Optional[float] = Field(None, ge=-180, le=180, description="當前經度")
    blockchain_object_id: Optional[str] = Field(None, description="智能合約對象ID")
    
    @field_validator('vehicle_type')
    @classmethod
    def validate_vehicle_type(cls, v):
        valid_types = ['sedan', 'suv', 'minivan', 'luxury']
        if v not in valid_types:
            raise ValueError(f'車輛類型必須是: {", ".join(valid_types)}')
        return v
    
    @field_validator('vehicle_id')
    @classmethod
    def validate_vehicle_id(cls, v):
        if not v.startswith('V'):
            raise ValueError('車輛ID必須以V開頭')
        return v.upper()

class VehicleUpdate(BaseModel):
    """更新車輛模型"""
    model: Optional[str] = Field(None, min_length=1, max_length=50)
    vehicle_type: Optional[str] = None
    battery_capacity_kwh: Optional[float] = Field(None, ge=0)
    hourly_rate: Optional[int] = Field(None, ge=0)
    
    @field_validator('vehicle_type')
    @classmethod
    def validate_vehicle_type(cls, v):
        if v is not None:
            valid_types = ['sedan', 'suv', 'minivan', 'luxury']
            if v not in valid_types:
                raise ValueError(f'車輛類型必須是: {", ".join(valid_types)}')
        return v

class VehicleLocationUpdate(BaseModel):
    """車輛位置更新模型"""
    lat: float = Field(..., ge=-90, le=90, description="緯度")
    lng: float = Field(..., ge=-180, le=180, description="經度")
    status: Optional[str] = Field(None, description="車輛狀態")
    
    @field_validator('status')
    @classmethod
    def validate_status(cls, v):
        if v is not None:
            valid_statuses = ['available', 'on_trip', 'offline', 'maintenance']
            if v not in valid_statuses:
                raise ValueError(f'車輛狀態必須是: {", ".join(valid_statuses)}')
        return v

class VehicleResponse(BaseModel):
    """車輛響應模型"""
    vehicle_id: str
    owner_id: int
    plate_number: str
    model: str
    vehicle_type: str
    battery_capacity_kwh: Optional[float] = None
    current_charge_percent: float
    current_lat: Optional[float] = None
    current_lng: Optional[float] = None
    status: str
    is_active: bool
    blockchain_object_id: Optional[str] = None
    hourly_rate: int
    total_trips: int = 0
    total_distance_km: float = 0
    total_earnings_micro_iota: str = "0"
    created_at: datetime
    updated_at: Optional[datetime] = None
    last_active_at: Optional[datetime] = None
    
    # 計算欄位 (用於可用車輛查詢)
    location_lat: Optional[float] = None
    location_lng: Optional[float] = None
    distance_km: Optional[float] = None
    estimated_arrival_minutes: Optional[int] = None
    
    class Config:
        from_attributes = True

class VehicleStatusUpdate(BaseModel):
    """車輛狀態更新模型"""
    status: str = Field(..., description="車輛狀態")
    
    @field_validator('status')
    @classmethod
    def validate_status(cls, v):
        valid_statuses = ['available', 'on_trip', 'offline', 'maintenance']
        if v not in valid_statuses:
            raise ValueError(f'車輛狀態必須是: {", ".join(valid_statuses)}')
        return v