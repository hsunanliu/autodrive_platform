# backend/app/models/rating.py

"""
Vehicle Rating 資料庫模型
乘客對自駕車的評價系統，支援區塊鏈存證
"""

from sqlalchemy import Column, Integer, String, DateTime, CheckConstraint, ForeignKey, Text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base


class VehicleRating(Base):
    """
    車輛評價模型 - 乘客對自駕車的評價

    主要特色：
    1. 單向評價：乘客評價車輛
    2. 評分系統：1-5星評分
    3. 標籤系統：預定義標籤選擇
    4. 區塊鏈存證：評價 hash 上鏈存儲
    """

    __tablename__ = "vehicle_ratings"

    # === 主鍵 ===
    id = Column(Integer, primary_key=True, comment="評價ID（自動遞增）")

    # === 關聯資訊 ===
    trip_id = Column(
        Integer,
        ForeignKey("trips.trip_id", ondelete="CASCADE"),
        nullable=False,
        comment="行程ID"
    )

    vehicle_id = Column(
        String(100),
        ForeignKey("vehicles.vehicle_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="車輛ID"
    )

    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="評價者用戶ID"
    )

    # === 評分內容 ===
    rating = Column(
        Integer,
        nullable=False,
        comment="評分（1-5星）"
    )

    comment = Column(
        Text,
        nullable=True,
        comment="評論內容"
    )

    tags = Column(
        JSONB,
        default=list,
        comment="評價標籤（JSON數組）：['乾淨', '準時', '平穩']"
    )

    # === 區塊鏈存證 ===
    rating_hash = Column(
        String(66),
        nullable=True,
        comment="評價內容 SHA256 hash（0x + 64位十六進制）"
    )

    blockchain_tx_id = Column(
        String(100),
        nullable=True,
        comment="上鏈交易 hash"
    )

    proof_object_id = Column(
        String(100),
        nullable=True,
        comment="Sui 上的 RatingProof 對象 ID"
    )

    content_blob_id = Column(
        String(120),
        nullable=True,
        comment="評論完整內容在 Walrus 的 blob_id（鏈上以此 + rating_hash 錨定）"
    )

    # === 時間戳記 ===
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        index=True,
        comment="評價時間"
    )

    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        comment="最後修改時間"
    )

    # === 關聯關係 ===
    trip = relationship("Trip")
    vehicle = relationship("Vehicle")
    user = relationship("User")

    # === 約束條件 ===
    __table_args__ = (
        CheckConstraint(
            'rating >= 1 AND rating <= 5',
            name='valid_vehicle_rating_range'
        ),
    )

    def __repr__(self):
        return f"<VehicleRating {self.id} ({self.rating}★) vehicle={self.vehicle_id}>"

    def __str__(self):
        return f"VehicleRating {self.id} - {self.rating}★ for {self.vehicle_id}"

    # === 業務邏輯方法 ===
    @property
    def is_positive(self) -> bool:
        """是否為正面評價（4-5星）"""
        return self.rating >= 4

    @property
    def is_negative(self) -> bool:
        """是否為負面評價（1-2星）"""
        return self.rating <= 2

    @property
    def is_on_chain(self) -> bool:
        """是否已上鏈存證"""
        return self.proof_object_id is not None


class RatingTag(Base):
    """
    評價標籤預設值
    """

    __tablename__ = "rating_tags"

    id = Column(Integer, primary_key=True, comment="標籤ID")

    tag_key = Column(
        String(50),
        unique=True,
        nullable=False,
        comment="標籤鍵值（英文）"
    )

    tag_label = Column(
        String(100),
        nullable=False,
        comment="標籤顯示名稱"
    )

    tag_type = Column(
        String(20),
        nullable=False,
        comment="標籤類型：positive, negative"
    )

    icon = Column(
        String(50),
        nullable=True,
        comment="圖標名稱"
    )

    sort_order = Column(
        Integer,
        default=0,
        comment="排序順序"
    )

    is_active = Column(
        Integer,
        default=1,
        comment="是否啟用"
    )

    __table_args__ = (
        CheckConstraint(
            "tag_type IN ('positive', 'negative')",
            name='valid_tag_type'
        ),
    )

    def __repr__(self):
        return f"<RatingTag {self.tag_key}: {self.tag_label}>"
