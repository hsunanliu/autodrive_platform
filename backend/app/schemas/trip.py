# backend/app/schemas/trip.py
"""
Trip Pydantic 模型
行程管理相關的數據結構
"""

from pydantic import BaseModel, Field, field_validator
from typing import Optional, Dict, Any, List
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


class WaypointCreate(BaseModel):
    """中繼點/停靠點"""
    lat: float = Field(..., ge=-90, le=90, description="緯度")
    lng: float = Field(..., ge=-180, le=180, description="經度")
    address: Optional[str] = Field(None, max_length=500, description="地址")


class WaypointResponse(BaseModel):
    """中繼點響應"""
    id: int
    sequence: int
    lat: float
    lng: float
    address: Optional[str] = None
    arrival_time: Optional[datetime] = None

    class Config:
        from_attributes = True


class TripCreate(BaseModel):
    """創建行程請求"""
    pickup_lat: float = Field(..., ge=-90, le=90, description="上車點緯度")
    pickup_lng: float = Field(..., ge=-180, le=180, description="上車點經度")
    pickup_address: Optional[str] = Field(None, max_length=500, description="上車點地址")
    dropoff_lat: float = Field(..., ge=-90, le=90, description="下車點緯度")
    dropoff_lng: float = Field(..., ge=-180, le=180, description="下車點經度")
    dropoff_address: Optional[str] = Field(None, max_length=500, description="下車點地址")
    waypoints: Optional[List[WaypointCreate]] = Field(default=[], description="中繼點列表（最多5個）")
    passenger_count: int = Field(..., ge=1, le=8, description="乘客人數")
    preferred_vehicle_type: Optional[str] = Field(None, description="偏好車輛類型")
    notes: Optional[str] = Field(None, max_length=500, description="備註")

    # 動態定價選擇
    use_dynamic_pricing: bool = Field(False, description="是否使用動態定價（快速叫車）")

    @field_validator('waypoints')
    @classmethod
    def validate_waypoints_count(cls, v):
        if v and len(v) > 5:
            raise ValueError("最多只能設置5個中繼點")
        return v
    
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
    base_fare: int = Field(..., description="起跳價 (micro SUI)")
    distance_fare: int = Field(..., description="距離費用 (micro SUI)")
    time_fare: int = Field(..., description="時間費用 (micro SUI)")
    platform_fee: int = Field(..., description="平台費用 (micro SUI)")
    total_amount: int = Field(..., description="總金額 (micro SUI)")
    driver_amount: int = Field(..., description="司機收入 (micro SUI)")

    # 計算基礎數據
    distance_km: float = Field(..., description="行程距離 (公里)")
    duration_minutes: int = Field(..., description="行程時間 (分鐘)")

    # 費率信息
    per_km_rate: int = Field(..., description="每公里費率 (micro SUI)")
    per_minute_rate: int = Field(..., description="每分鐘費率 (micro SUI)")
    platform_fee_rate: float = Field(..., description="平台費率 (百分比)")

    # 動態定價信息
    surge_multiplier: float = Field(1.0, description="動態加價係數")
    surge_breakdown: Optional[Dict[str, float]] = Field(None, description="加價因素分解")
    surge_reason: Optional[str] = Field(None, description="加價原因說明")

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
    waypoints: Optional[List[WaypointResponse]] = []  # 中繼點列表

    # 行程信息
    passenger_count: int
    status: TripStatus
    distance_km: Optional[float] = None
    estimated_duration_minutes: Optional[int] = None
    actual_duration_minutes: Optional[int] = None
    
    # 費用信息
    fare_breakdown: Optional[TripFareBreakdown] = None
    payment_amount_micro_sui: Optional[str] = None
    blockchain_tx_id: Optional[str] = None
    escrow_object_id: Optional[str] = None  # 託管對象ID（支付鎖定憑證）

    # 動態定價信息
    price_type: str = "standard"  # dynamic 或 standard
    priority: int = 2  # 1=快速, 2=標準
    surge_multiplier: float = 1.0
    surge_reason: Optional[str] = None
    estimated_wait_minutes: Optional[int] = None
    actual_wait_minutes: Optional[int] = None

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
    total_amount: Optional[int]  # micro SUI
    passenger_count: Optional[int] = 1
    requested_at: datetime
    completed_at: Optional[datetime]

    # 動態定價資訊
    priority: int = 2
    price_type: str = 'standard'
    surge_multiplier: float = 1.0
    surge_reason: Optional[str] = None

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

    # 動態定價選項（給用戶選擇）
    surge_info: Optional[Dict[str, Any]] = None  # 包含 surge_multiplier, reason, breakdown
    standard_fare: Optional[TripFareBreakdown] = None  # 標準價格（無加價）
    dynamic_fare: Optional[TripFareBreakdown] = None  # 動態價格（含加價）
    has_surge: bool = False  # 是否有加價

class DriverTripInfo(BaseModel):
    """司機端行程信息"""
    trip_id: int
    passenger_name: str
    passenger_phone: Optional[str]
    pickup_location: Dict[str, Any]
    dropoff_location: Dict[str, Any]
    passenger_count: int
    estimated_fare: int  # micro SUI
    distance_to_pickup_km: float
    notes: Optional[str]

class PaymentConfirmation(BaseModel):
    """支付確認請求（用戶提供 tx_hash）"""
    tx_hash: str = Field(
        ...,
        min_length=40,
        description="交易哈希（從錢包獲得）"
    )

    @field_validator('tx_hash')
    @classmethod
    def validate_tx_hash(cls, v):
        """驗證 tx_hash 格式"""
        if not v or len(v) < 40:
            raise ValueError('交易哈希格式不正確')
        return v.strip()