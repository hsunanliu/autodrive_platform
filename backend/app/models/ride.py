# backend/app/models/trip.py

"""
Trip 資料庫模型
管理乘車行程的完整生命週期
"""

from sqlalchemy import Column, Integer, String, Float, DateTime, CheckConstraint, ForeignKey, Text
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base

class Trip(Base):
    """
    行程模型 - 管理完整的乘車流程
    主要特色：
    1. 行程生命週期：requested → picked_up → dropped_off → completed
    2. 位置追蹤：起點、終點座標
    3. 費用計算：距離自動計算、動態定價
    4. 區塊鏈整合：智能合約執行
    """
    
    __tablename__ = "trips"
    
    # === 主鍵 ===
    trip_id = Column(Integer, primary_key=True, comment="行程ID（自動遞增）")
    
    # === 關聯用戶和車輛 ===
    user_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=False,
        comment="乘客用戶ID"
    )
    
    vehicle_id = Column(
        String(20),
        ForeignKey("vehicles.vehicle_id"),
        nullable=True,
        comment="車輛ID（配對後填入）"
    )
    
    driver_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=True,
        comment="司機用戶ID（若不同於vehicle owner）"
    )
    
    # === 位置資訊 ===
    pickup_lat = Column(
        Float,
        nullable=False,
        comment="上車點緯度"
    )
    
    pickup_lng = Column(
        Float,
        nullable=False,
        comment="上車點經度"
    )
    
    pickup_address = Column(
        String(500),
        nullable=True,
        comment="上車點地址"
    )
    
    dropoff_lat = Column(
        Float,
        nullable=False,
        comment="下車點緯度"
    )
    
    dropoff_lng = Column(
        Float,
        nullable=False,
        comment="下車點經度"
    )
    
    dropoff_address = Column(
        String(500),
        nullable=True,
        comment="下車點地址"
    )
    
    # === 行程資訊 ===
    distance_km = Column(
        Float,
        nullable=True,
        comment="行程距離（公里）"
    )
    
    estimated_duration_minutes = Column(
        Integer,
        nullable=True,
        comment="預估時間（分鐘）"
    )
    
    actual_duration_minutes = Column(
        Integer,
        nullable=True,
        comment="實際時間（分鐘）"
    )
    
    passenger_count = Column(
        Integer,
        default=1,
        nullable=False,
        comment="乘客人數"
    )
    
    # === 費用資訊 ===
    fare = Column(
        Float,
        nullable=True,
        comment="車費（台幣）"
    )
    
    base_fare = Column(
        Float,
        default=50.0,
        nullable=False,
        comment="起跳價"
    )
    
    per_km_rate = Column(
        Float,
        default=10.0,
        nullable=False,
        comment="每公里費率"
    )
    
    service_fee = Column(
        Float,
        default=0.0,
        nullable=False,
        comment="服務費"
    )
    
    total_amount = Column(
        Float,
        nullable=True,
        comment="總金額"
    )
    
    # === 區塊鏈支付 ===
    payment_amount_micro_iota = Column(
        String(50),
        nullable=True,
        comment="IOTA支付金額（micro IOTA）"
    )
    
    blockchain_tx_id = Column(
        String(66),
        nullable=True,
        comment="區塊鏈交易ID"
    )
    
    # === 狀態管理 ===
    status = Column(
        String(20),
        default="requested",
        nullable=False,
        comment="行程狀態：requested, matched, picked_up, in_progress, completed, cancelled"
    )
    
    cancellation_reason = Column(
        String(500),
        nullable=True,
        comment="取消原因"
    )
    
    # === 時間戳記 ===
    requested_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        comment="叫車時間"
    )
    
    matched_at = Column(
        DateTime(timezone=True),
        nullable=True,
        comment="配對成功時間"
    )
    
    picked_up_at = Column(
        DateTime(timezone=True),
        nullable=True,
        comment="上車時間"
    )
    
    dropped_off_at = Column(
        DateTime(timezone=True),
        nullable=True,
        comment="下車時間"
    )
    
    completed_at = Column(
        DateTime(timezone=True),
        nullable=True,
        comment="完成時間"
    )
    
    cancelled_at = Column(
        DateTime(timezone=True),
        nullable=True,
        comment="取消時間"
    )
    
    # === 關聯關係 ===
    passenger = relationship("User", foreign_keys=[user_id])
    driver = relationship("User", foreign_keys=[driver_id])
    vehicle = relationship("Vehicle")
    reviews = relationship("Review")
    
    # === 約束條件 ===
    __table_args__ = (
        CheckConstraint(
            "status IN ('requested', 'matched', 'accepted', 'picked_up', 'in_progress', 'completed', 'cancelled')",
            name='valid_trip_status'
        ),
        CheckConstraint(
            'passenger_count > 0 AND passenger_count <= 8',
            name='valid_passenger_count'
        ),
        CheckConstraint(
            'distance_km >= 0',
            name='valid_distance'
        ),
        CheckConstraint(
            'fare >= 0',
            name='valid_fare'
        ),
    )
    
    def __repr__(self):
        return f"<Trip {self.trip_id} ({self.status})>"
    
    def __str__(self):
        return f"Trip {self.trip_id} - {self.status}"
    
    # === 業務邏輯方法 ===
    @property
    def is_active(self) -> bool:
        """是否為進行中的行程"""
        return self.status in ('requested', 'matched', 'picked_up', 'in_progress')
    
    @property
    def is_completed(self) -> bool:
        """是否已完成"""
        return self.status in ('completed', 'cancelled')
    
    def calculate_fare(self) -> float:
        """計算車費"""
        if not self.distance_km:
            return self.base_fare
        
        fare = self.base_fare + (self.per_km_rate * self.distance_km)
        return round(fare, 2)
    
    def calculate_total_amount(self) -> float:
        """計算總金額（包含服務費）"""
        if not self.fare:
            self.fare = self.calculate_fare()
        
        total = self.fare + self.service_fee
        return round(total, 2)
    
    def update_status(self, new_status: str):
        """更新狀態並記錄時間"""
        self.status = new_status
        now = func.now()
        
        if new_status == "matched":
            self.matched_at = now
        elif new_status == "picked_up":
            self.picked_up_at = now
        elif new_status == "completed":
            self.completed_at = now
            self.dropped_off_at = now
        elif new_status == "cancelled":
            self.cancelled_at = now
