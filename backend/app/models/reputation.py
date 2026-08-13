# backend/app/models/reputation.py

"""
Reputation 資料庫模型
用戶信譽分數系統，影響配對優先順序與封禁機制
"""

from sqlalchemy import Column, Integer, String, DateTime, CheckConstraint, ForeignKey, Text, Boolean
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base
from decimal import Decimal


class ReputationScore(Base):
    """
    用戶信譽分數模型

    分數範圍：0-200
    等級劃分：
    - gold (180-200): 金牌用戶，優先配對
    - good (150-179): 良好用戶
    - normal (100-149): 普通用戶（新用戶預設）
    - warning (70-99): 警告用戶
    - restricted (40-69): 受限用戶，降低配對優先
    - probation (20-39): 觀察用戶
    - banned (0-19): 封禁用戶
    """

    __tablename__ = "reputation_scores"

    id = Column(Integer, primary_key=True, comment="信譽分數ID")

    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
        comment="用戶ID"
    )

    # === 分數與等級 ===
    current_score = Column(
        Integer,
        default=100,
        nullable=False,
        comment="當前信譽分數（0-200）"
    )

    level = Column(
        String(20),
        default="normal",
        nullable=False,
        comment="信譽等級：gold, good, normal, warning, restricted, probation, banned"
    )

    # === 統計資料 ===
    total_positive = Column(
        Integer,
        default=0,
        comment="正面事件次數"
    )

    total_negative = Column(
        Integer,
        default=0,
        comment="負面事件次數"
    )

    total_trips = Column(
        Integer,
        default=0,
        comment="總行程次數"
    )

    total_ratings_given = Column(
        Integer,
        default=0,
        comment="給出的評價次數"
    )

    avg_rating_given = Column(
        String(10),
        default="0.0",
        comment="給出的平均評分"
    )

    # === 時間戳記 ===
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        comment="創建時間"
    )

    last_updated = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        comment="最後更新時間"
    )

    # === 關聯關係 ===
    user = relationship("User")

    # === 約束條件 ===
    __table_args__ = (
        CheckConstraint(
            'current_score >= 0 AND current_score <= 200',
            name='valid_reputation_score_range'
        ),
        CheckConstraint(
            "level IN ('gold', 'good', 'normal', 'warning', 'restricted', 'probation', 'banned')",
            name='valid_reputation_level'
        ),
    )

    def __repr__(self):
        return f"<ReputationScore user={self.user_id} score={self.current_score} level={self.level}>"

    # === 業務邏輯方法 ===
    @staticmethod
    def calculate_level(score: int) -> str:
        """根據分數計算等級"""
        if score >= 180:
            return "gold"
        elif score >= 150:
            return "good"
        elif score >= 100:
            return "normal"
        elif score >= 70:
            return "warning"
        elif score >= 40:
            return "restricted"
        elif score >= 20:
            return "probation"
        else:
            return "banned"

    @property
    def matching_priority(self) -> float:
        """配對優先權重（用於排序）"""
        priority_map = {
            "gold": 1.5,
            "good": 1.2,
            "normal": 1.0,
            "warning": 0.8,
            "restricted": 0.5,
            "probation": 0.3,
            "banned": 0.0
        }
        return priority_map.get(self.level, 1.0)

    @property
    def can_request_ride(self) -> bool:
        """是否可以叫車"""
        return self.level not in ("banned",)

    def update_score(self, change: int, reason: str = None) -> int:
        """更新分數並自動調整等級"""
        old_score = self.current_score
        self.current_score = max(0, min(200, self.current_score + change))
        self.level = self.calculate_level(self.current_score)

        if change > 0:
            self.total_positive += 1
        elif change < 0:
            self.total_negative += 1

        return self.current_score - old_score


class ReputationHistory(Base):
    """
    信譽分數變動歷史
    記錄每次分數變動的原因和上下文
    """

    __tablename__ = "reputation_history"

    id = Column(Integer, primary_key=True, comment="歷史記錄ID")

    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="用戶ID"
    )

    # === 事件資訊 ===
    event_type = Column(
        String(50),
        nullable=False,
        index=True,
        comment="事件類型：rating_5_star, rating_4_star, rating_1_star, cancel_trip, timeout, complete_trip, etc."
    )

    score_change = Column(
        Integer,
        nullable=False,
        comment="分數變動（可為正負）"
    )

    score_before = Column(
        Integer,
        nullable=False,
        comment="變動前分數"
    )

    score_after = Column(
        Integer,
        nullable=False,
        comment="變動後分數"
    )

    reason = Column(
        Text,
        nullable=True,
        comment="變動原因說明"
    )

    # === 關聯資訊 ===
    trip_id = Column(
        Integer,
        ForeignKey("trips.trip_id", ondelete="SET NULL"),
        nullable=True,
        comment="關聯行程ID"
    )

    rating_id = Column(
        Integer,
        ForeignKey("vehicle_ratings.id", ondelete="SET NULL"),
        nullable=True,
        comment="關聯評價ID"
    )

    # === 時間戳記 ===
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        index=True,
        comment="記錄時間"
    )

    # === 關聯關係 ===
    user = relationship("User")
    trip = relationship("Trip")

    def __repr__(self):
        return f"<ReputationHistory user={self.user_id} {self.event_type} {self.score_change:+d}>"


class UserBan(Base):
    """
    用戶封禁記錄
    支援臨時封禁和永久封禁，以及申訴機制
    """

    __tablename__ = "user_bans"

    id = Column(Integer, primary_key=True, comment="封禁記錄ID")

    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="用戶ID"
    )

    # === 封禁資訊 ===
    ban_type = Column(
        String(20),
        nullable=False,
        index=True,
        comment="封禁類型：warning, temporary, permanent"
    )

    reason = Column(
        Text,
        nullable=False,
        comment="封禁原因"
    )

    triggered_by = Column(
        String(50),
        nullable=True,
        comment="觸發原因：low_score, complaint, admin"
    )

    # === 時間範圍 ===
    start_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        comment="封禁開始時間"
    )

    end_at = Column(
        DateTime(timezone=True),
        nullable=True,
        index=True,
        comment="封禁結束時間（NULL = 永久）"
    )

    # === 申訴狀態 ===
    appeal_status = Column(
        String(20),
        default="none",
        comment="申訴狀態：none, pending, approved, rejected"
    )

    appeal_reason = Column(
        Text,
        nullable=True,
        comment="申訴理由"
    )

    appeal_at = Column(
        DateTime(timezone=True),
        nullable=True,
        comment="申訴時間"
    )

    reviewed_by = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=True,
        comment="審核者用戶ID"
    )

    reviewed_at = Column(
        DateTime(timezone=True),
        nullable=True,
        comment="審核時間"
    )

    # === 時間戳記 ===
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        comment="記錄創建時間"
    )

    # === 關聯關係 ===
    user = relationship("User", foreign_keys=[user_id])
    reviewer = relationship("User", foreign_keys=[reviewed_by])

    # === 約束條件 ===
    __table_args__ = (
        CheckConstraint(
            "ban_type IN ('warning', 'temporary', 'permanent')",
            name='valid_ban_type'
        ),
        CheckConstraint(
            "appeal_status IN ('none', 'pending', 'approved', 'rejected')",
            name='valid_appeal_status'
        ),
    )

    def __repr__(self):
        return f"<UserBan user={self.user_id} type={self.ban_type}>"

    # === 業務邏輯方法 ===
    @property
    def is_active(self) -> bool:
        """封禁是否仍然有效"""
        from datetime import datetime, timezone
        if self.appeal_status == "approved":
            return False
        if self.end_at is None:
            return True  # 永久封禁
        return datetime.now(timezone.utc) < self.end_at

    @property
    def is_permanent(self) -> bool:
        """是否為永久封禁"""
        return self.end_at is None and self.ban_type == "permanent"

    @property
    def can_appeal(self) -> bool:
        """是否可以申訴"""
        return self.appeal_status in ("none", "rejected")
