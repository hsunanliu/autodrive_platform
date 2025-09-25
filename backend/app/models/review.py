# backend/app/models/review.py

"""
Review 資料庫模型
管理行程評價與評論系統
"""

from sqlalchemy import Column, Integer, String, DateTime, CheckConstraint, ForeignKey, Text
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from .base import Base

class Review(Base):
    """
    評論模型 - 行程評價系統
    主要特色：
    1. 雙向評價：乘客評價司機、司機評價乘客
    2. 評分系統：1-5星評分
    3. 文字評論：詳細反饋
    4. 匿名選項：保護隱私
    """
    
    __tablename__ = "reviews"
    
    # === 主鍵 ===
    review_id = Column(Integer, primary_key=True, comment="評論ID（自動遞增）")
    
    # === 關聯資訊 ===
    trip_id = Column(
        Integer,
        ForeignKey("trips.trip_id"),
        nullable=False,
        comment="行程ID"
    )
    
    reviewer_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=False,
        comment="評論者用戶ID"
    )
    
    reviewee_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=False,
        comment="被評論者用戶ID"
    )
    
    # === 評分資訊 ===
    rating = Column(
        Integer,
        nullable=False,
        comment="評分（1-5星）"
    )
    
    # === 詳細評價 ===
    comment = Column(
        Text,
        nullable=True,
        comment="評論內容"
    )
    
    # === 評價類型 ===
    review_type = Column(
        String(20),
        nullable=False,
        comment="評價類型：passenger_to_driver, driver_to_passenger"
    )
    
    # === 匿名設定 ===
    is_anonymous = Column(
        Boolean,
        default=False,
        nullable=False,
        comment="是否匿名評論"
    )
    
    # === 評價標籤 ===
    tags = Column(
        String(500),
        nullable=True,
        comment="評價標籤（JSON格式）：['準時', '友善', '駕駛平穩']"
    )
    
    # === 時間戳記 ===
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        comment="評論時間"
    )
    
    updated_at = Column(
        DateTime(timezone=True),
        onupdate=func.now(),
        comment="最後修改時間"
    )
    
    # === 關聯關係 ===
    trip = relationship("Trip", back_populates="reviews")
    reviewer = relationship("User", foreign_keys=[reviewer_id], back_populates="reviews_given")
    reviewee = relationship("User", foreign_keys=[reviewee_id], back_populates="reviews_received")
    
    # === 約束條件 ===
    __table_args__ = (
        CheckConstraint(
            'rating >= 1 AND rating <= 5',
            name='valid_rating_range'
        ),
        CheckConstraint(
            "review_type IN ('passenger_to_driver', 'driver_to_passenger')",
            name='valid_review_type'
        ),
    )
    
    def __repr__(self):
        return f"<Review {self.review_id} ({self.rating}★)>"
    
    def __str__(self):
        return f"Review {self.review_id} - {self.rating}★"
