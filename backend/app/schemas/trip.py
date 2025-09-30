# backend/app/schemas/trip.py
"""
Trip Pydantic 模型
行程管理相關的數據結構
"""

from pydantic import BaseModel, Field, field_validator
from typing import Optional, Dict, Any
from datetime import datetime
from enum import Enum

class TripStatus(str, Enum):
    """行程狀態枚舉"""
    REQUESTED = "requested"
    MATCHED = "matched"
    ACCEPTED = "accepted"
    PICKED_UP = "picked_up"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    CANCELLED = "cancelled"

class TripCreate(BaseModel):
    """創建行程請求"""
    pickup_lat: float = Field(..., ge=-90, le=90, description="上車點緯度")
    pickup_lng: float = Field(..., ge=-180, le=180, description="上車點經度")
    pickup_address: Optional[str] = Field(None, max_length=500, description="上車點地址")
    dropoff_lat: float = Field(..., ge=-90, le=90, description="下車點緯度")
    dropoff_lng: float = Field(..., ge=-180, le=180, description="下車點經度")
    dropoff_address: Optional[str] = Field(None, max_length=500, description="下車點地址")
    passenger_count: int = Field(..., ge=1, le=8, description="乘客人數")
    preferred_vehicle_type: Optional[str] = Field(None, description="偏好車輛類型")
    notes: Optional[str] = Field(None, max_length=500, description="備註")
    
    @field_validator('preferred_vehicle_type')
    @classmethod
    def validate_vehicle_type(cls, v):
        if v is not None:
            valid_types = ['sedan', 'suv', 'minivan', 'luxury']
            if v not in valid_types:
                raise ValueError(f'車輛類型必須是: {", ".join(valid_types)}')
        return v

class TripMatchRequest(BaseModel):
    """配對請求"""
    max_wait_time_minutes: int = Field(10, ge=1, le=30, description="最大等待時間")
    max_pickup_distance_km: float = Field(5.0, ge=0.5, le=20.0, description="最大接送距離")

class TripAcceptRequest(BaseModel):
    """司機接單請求"""
    estimated_arrival_minutes: int = Field(..., ge=1, le=60, description="預估到達時間")
    driver_notes: Optional[str] = Field(None, max_length=200, description="司機備註")

class TripLocationUpdate(BaseModel):
    """行程位置更新"""
    current_lat: float = Field(..., ge=-90, le=90, description="當前緯度")
    current_lng: float = Field(..., ge=-180, le=180, description="當前經度")
    
class TripCancelRequest(BaseModel):
    """取消行程請求"""
    reason: str = Field(..., max_length=500, description="取消原因")
    cancelled_by: str = Field(..., description="取消者角色")
    
    @field_validator('cancelled_by')
    @classmethod
    def validate_cancelled_by(cls, v):
        if v not in ['passenger', 'driver', 'system']:
            raise ValueError('取消者必須是: passenger, driver, system')
        return v

class TripFareBreakdown(BaseModel):
    """行程費用分解"""
    base_fare: int = Field(..., description="起跳價 (micro IOTA)")
    distance_fare: int = Field(..., description="距離費用 (micro IOTA)")
    time_fare: int = Field(..., description="時間費用 (micro IOTA)")
    platform_fee: int = Field(..., description="平台費用 (micro IOTA)")
    total_amount: int = Field(..., description="總金額 (micro IOTA)")
    driver_amount: int = Field(..., description="司機收入 (micro IOTA)")
    
    # 計算基礎數據
    distance_km: float = Field(..., description="行程距離 (公里)")
    duration_minutes: int = Field(..., description="行程時間 (分鐘)")
    
    # 費率信息
    per_km_rate: int = Field(..., description="每公里費率 (micro IOTA)")
    per_minute_rate: int = Field(..., description="每分鐘費率 (micro IOTA)")
    platform_fee_rate: float = Field(..., description="平台費率 (百分比)")

class TripResponse(BaseModel):
    """行程響應模型"""
    trip_id: int
    user_id: int  # 乘客ID
    driver_id: Optional[int] = None
    vehicle_id: Optional[str] = None
    
    # 位置信息
    pickup_lat: float
    pickup_lng: float
    pickup_address: Optional[str] = None
    dropoff_lat: float
    dropoff_lng: float
    dropoff_address: Optional[str] = None
    
    # 行程信息
    passenger_count: int
    status: TripStatus
    distance_km: Optional[float] = None
    estimated_duration_minutes: Optional[int] = None
    actual_duration_minutes: Optional[int] = None
    
    # 費用信息
    fare_breakdown: Optional[TripFareBreakdown] = None
    payment_amount_micro_iota: Optional[str] = None
    blockchain_tx_id: Optional[str] = None
    
    # 時間戳
    requested_at: datetime
    matched_at: Optional[datetime] = None
    picked_up_at: Optional[datetime] = None
    dropped_off_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    cancelled_at: Optional[datetime] = None
    
    # 取消信息
    cancellation_reason: Optional[str] = None
    
    # 備註
    notes: Optional[str] = None
    driver_notes: Optional[str] = None
    
    class Config:
        from_attributes = True

class TripSummary(BaseModel):
    """行程摘要 (用於列表顯示)"""
    trip_id: int
    status: TripStatus
    pickup_address: Optional[str]
    dropoff_address: Optional[str]
    distance_km: Optional[float]
    total_amount: Optional[int]  # micro IOTA
    requested_at: datetime
    completed_at: Optional[datetime]
    
    # 關聯信息
    driver_name: Optional[str] = None
    vehicle_model: Optional[str] = None
    vehicle_plate: Optional[str] = None

class TripEstimate(BaseModel):
    """行程預估"""
    estimated_distance_km: float
    estimated_duration_minutes: int
    estimated_fare: TripFareBreakdown
    available_vehicles_count: int
    estimated_wait_time_minutes: int

class DriverTripInfo(BaseModel):
    """司機端行程信息"""
    trip_id: int
    passenger_name: str
    passenger_phone: Optional[str]
    pickup_location: Dict[str, Any]
    dropoff_location: Dict[str, Any]
    passenger_count: int
    estimated_fare: int  # micro IOTA
    distance_to_pickup_km: float
    notes: Optional[str]