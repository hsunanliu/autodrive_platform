# backend/app/models/vehicle.py

"""
Vehicle 資料庫模型
管理自動駕駛車輛資訊與狀態
"""

from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, CheckConstraint, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base

class Vehicle(Base):
    """
    車輛模型 - 管理自動駕駛車輛
    主要特色：
    1. 車輛基本資訊：車牌、型號、電池狀態
    2. 位置追蹤：實時位置更新
    3. 狀態管理：可用、使用中、離線
    4. 區塊鏈整合：智能合約對象ID
    """
    
    __tablename__ = "vehicles"
    
    # === 主鍵 ===
    vehicle_id = Column(String(20), primary_key=True, comment="車輛ID（V001, V002...）")
    
    # === 車主資訊 ===
    owner_id = Column(
        Integer, 
        ForeignKey("users.id"),
        nullable=False,
        comment="車主用戶ID"
    )
    
    # === 車輛基本資訊 ===
    plate_number = Column(
        String(20),
        unique=True,
        nullable=False,
        comment="車牌號碼"
    )
    
    model = Column(
        String(50),
        nullable=False,
        comment="車輛型號（Tesla Model Y, Tesla Model X等）"
    )
    
    vehicle_type = Column(
        String(20),
        default="sedan",
        nullable=False,
        comment="車輛類型：sedan, suv, minivan"
    )
    
    # === 電動車資訊 ===
    battery_capacity_kwh = Column(
        Float,
        nullable=True,
        comment="電池容量（kWh）"
    )
    
    current_charge_percent = Column(
        Float,
        default=100.0,
        nullable=False,
        comment="當前電量百分比（0-100）"
    )
    
    # === 位置資訊 ===
    current_lat = Column(
        Float,
        nullable=True,
        comment="當前緯度"
    )
    
    current_lng = Column(
        Float,
        nullable=True,
        comment="當前經度"
    )
    
    # === 狀態管理 ===
    status = Column(
        String(20),
        default="available",
        nullable=False,
        comment="車輛狀態：available, on_trip, offline, maintenance"
    )
    
    is_active = Column(
        Boolean,
        default=True,
        nullable=False,
        comment="是否啟用"
    )
    
    # === 區塊鏈整合 ===
    blockchain_object_id = Column(
        String(66),
        unique=True,
        nullable=True,
        comment="IOTA智能合約中的車輛對象ID"
    )
    
    # === 費率設定 ===
    hourly_rate = Column(
        Integer,
        default=100,
        nullable=False,
        comment="每小時費率（micro IOTA）"
    )
    
    # === 統計資料 ===
    total_trips = Column(
        Integer,
        default=0,
        nullable=False,
        comment="總服務次數"
    )
    
    total_distance_km = Column(
        Float,
        default=0.0,
        nullable=False,
        comment="總行駛距離（公里）"
    )
    
    total_earnings_micro_iota = Column(
        String(50),
        default="0",
        nullable=False,
        comment="總收入（micro IOTA）"
    )
    
    # === 時間戳記 ===
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        comment="註冊時間"
    )
    
    updated_at = Column(
        DateTime(timezone=True),
        onupdate=func.now(),
        comment="最後更新時間"
    )
    
    last_active_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        comment="最後活躍時間"
    )
    
    # === 關聯關係 ===
    owner = relationship("User")
    trips_as_vehicle = relationship("Trip")
    
    # === 約束條件 ===
    __table_args__ = (
        CheckConstraint(
            "status IN ('available', 'on_trip', 'offline', 'maintenance')",
            name='valid_vehicle_status'
        ),
        CheckConstraint(
            "vehicle_type IN ('sedan', 'suv', 'minivan', 'luxury')",
            name='valid_vehicle_type'
        ),
        CheckConstraint(
            'current_charge_percent >= 0 AND current_charge_percent <= 100',
            name='valid_charge_percent'
        ),
        CheckConstraint(
            'total_trips >= 0',
            name='valid_total_trips'
        ),
        CheckConstraint(
            'total_distance_km >= 0',
            name='valid_total_distance'
        ),
    )
    
    def __repr__(self):
        return f"<Vehicle {self.vehicle_id} ({self.plate_number})>"
    
    def __str__(self):
        return f"Vehicle {self.vehicle_id} - {self.model} ({self.plate_number})"
    
    # === 業務邏輯方法 ===
    @property
    def is_available(self) -> bool:
        """是否可用於叫車"""
        return (
            self.status == "available" and 
            self.is_active and 
            self.current_charge_percent > 20  # 至少20%電量
        )
    
    @property
    def short_vehicle_id(self) -> str:
        """車輛ID縮寫顯示"""
        return self.vehicle_id
    
    def can_accept_trip(self) -> bool:
        """是否可以接受行程"""
        return self.is_available
    
    def update_location(self, lat: float, lng: float):
        """更新位置"""
        self.current_lat = lat
        self.current_lng = lng
        self.last_active_at = func.now()
