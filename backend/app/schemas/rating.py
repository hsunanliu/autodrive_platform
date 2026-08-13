# backend/app/schemas/rating.py

"""
車輛評價與信譽系統 Pydantic Schemas
"""

from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from enum import Enum


# ============================================================
# 評價相關 Schemas
# ============================================================

class VehicleRatingBase(BaseModel):
    """車輛評價基礎 Schema"""
    rating: int = Field(..., ge=1, le=5, description="評分1-5星")
    comment: Optional[str] = Field(None, max_length=500, description="評論內容")
    tags: Optional[List[str]] = Field(default=[], description="評價標籤")


class VehicleRatingCreate(VehicleRatingBase):
    """建立車輛評價請求"""
    trip_id: int = Field(..., description="行程ID")
    vehicle_id: str = Field(..., description="車輛ID")


class VehicleRatingResponse(VehicleRatingBase):
    """車輛評價回應"""
    id: int
    trip_id: int
    vehicle_id: str
    user_id: int
    rating_hash: Optional[str] = None
    blockchain_tx_id: Optional[str] = None
    proof_object_id: Optional[str] = None
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class VehicleRatingSummary(BaseModel):
    """車輛評價摘要"""
    vehicle_id: str
    avg_rating: float = Field(..., description="平均評分")
    total_ratings: int = Field(..., description="評價總數")
    rating_distribution: dict = Field(..., description="評分分布 {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}")
    recent_tags: List[str] = Field(default=[], description="最近常用標籤")


class RatingTagResponse(BaseModel):
    """評價標籤回應"""
    id: int
    tag_key: str
    tag_label: str
    tag_type: str
    icon: Optional[str] = None

    class Config:
        from_attributes = True


# ============================================================
# 信譽相關 Schemas
# ============================================================

class ReputationLevel(str, Enum):
    """信譽等級"""
    GOLD = "gold"
    GOOD = "good"
    NORMAL = "normal"
    WARNING = "warning"
    RESTRICTED = "restricted"
    PROBATION = "probation"
    BANNED = "banned"


class ReputationScoreResponse(BaseModel):
    """信譽分數回應"""
    id: int
    user_id: int
    current_score: int = Field(..., ge=0, le=200)
    level: str
    total_positive: int
    total_negative: int
    total_trips: int
    total_ratings_given: int
    avg_rating_given: str
    matching_priority: float = Field(..., description="配對優先權重")
    can_request_ride: bool
    created_at: datetime
    last_updated: datetime

    class Config:
        from_attributes = True


class ReputationHistoryResponse(BaseModel):
    """信譽歷史回應"""
    id: int
    user_id: int
    event_type: str
    score_change: int
    score_before: int
    score_after: int
    reason: Optional[str] = None
    trip_id: Optional[int] = None
    rating_id: Optional[int] = None
    created_at: datetime

    class Config:
        from_attributes = True


class ReputationEventType(str, Enum):
    """信譽事件類型"""
    # 正面事件
    RATING_5_STAR = "rating_5_star"          # +5
    RATING_4_STAR = "rating_4_star"          # +3
    COMPLETE_TRIP = "complete_trip"          # +2
    LONG_TRIP_BONUS = "long_trip_bonus"      # +1 (行程 > 30分鐘)

    # 中性事件
    RATING_3_STAR = "rating_3_star"          # +0

    # 負面事件
    RATING_2_STAR = "rating_2_star"          # -3
    RATING_1_STAR = "rating_1_star"          # -5
    CANCEL_TRIP = "cancel_trip"              # -5
    NO_SHOW = "no_show"                      # -10
    TIMEOUT = "timeout"                      # -3
    COMPLAINT = "complaint"                  # -10 ~ -30

    # 管理員操作
    ADMIN_ADJUST = "admin_adjust"
    BAN_PENALTY = "ban_penalty"
    APPEAL_APPROVED = "appeal_approved"


# ============================================================
# 封禁相關 Schemas
# ============================================================

class BanType(str, Enum):
    """封禁類型"""
    WARNING = "warning"        # 警告
    TEMPORARY = "temporary"    # 臨時封禁
    PERMANENT = "permanent"    # 永久封禁


class AppealStatus(str, Enum):
    """申訴狀態"""
    NONE = "none"
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"


class UserBanCreate(BaseModel):
    """建立封禁請求"""
    user_id: int
    ban_type: BanType
    reason: str
    triggered_by: Optional[str] = None
    duration_hours: Optional[int] = Field(None, description="封禁時長（小時），NULL為永久")


class UserBanResponse(BaseModel):
    """封禁記錄回應"""
    id: int
    user_id: int
    ban_type: str
    reason: str
    triggered_by: Optional[str] = None
    start_at: datetime
    end_at: Optional[datetime] = None
    appeal_status: str
    appeal_reason: Optional[str] = None
    appeal_at: Optional[datetime] = None
    reviewed_by: Optional[int] = None
    reviewed_at: Optional[datetime] = None
    is_active: bool
    is_permanent: bool
    can_appeal: bool
    created_at: datetime

    class Config:
        from_attributes = True


class AppealCreate(BaseModel):
    """申訴請求"""
    reason: str = Field(..., min_length=10, max_length=1000, description="申訴理由")


class AppealReview(BaseModel):
    """審核申訴"""
    approved: bool
    review_comment: Optional[str] = None


# ============================================================
# 區塊鏈存證相關 Schemas
# ============================================================

class RatingProofCreate(BaseModel):
    """評價存證請求"""
    rating_id: int
    rating_hash: str = Field(..., pattern=r"^0x[a-fA-F0-9]{64}$", description="SHA256 hash")


class RatingProofResponse(BaseModel):
    """評價存證回應"""
    rating_id: int
    rating_hash: str
    blockchain_tx_id: str
    proof_object_id: str
    created_at: datetime


# ============================================================
# 配對優先順序相關
# ============================================================

class MatchingPriority(BaseModel):
    """配對優先權資訊"""
    user_id: int
    reputation_score: int
    reputation_level: str
    priority_weight: float = Field(..., ge=0, le=2.0)
    can_request_ride: bool
    restrictions: List[str] = Field(default=[], description="限制列表")


# ============================================================
# 統計相關 Schemas
# ============================================================

class ReputationStats(BaseModel):
    """信譽統計資訊"""
    total_users: int
    level_distribution: dict = Field(..., description="各等級用戶數")
    average_score: float
    active_bans: int
    pending_appeals: int


class VehicleRatingStats(BaseModel):
    """車輛評價統計"""
    total_ratings: int
    avg_rating: float
    ratings_today: int
    on_chain_ratings: int
    pending_on_chain: int
