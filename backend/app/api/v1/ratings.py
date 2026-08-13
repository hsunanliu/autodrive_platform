# backend/app/api/v1/ratings.py

"""
車輛評價與信譽系統 API
"""

from fastapi import APIRouter, HTTPException, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Optional

from app.core.database import get_async_session
from app.models.user import User
from app.api.deps import get_current_user
from app.schemas.rating import (
    VehicleRatingCreate,
    VehicleRatingResponse,
    VehicleRatingSummary,
    RatingTagResponse,
    ReputationScoreResponse,
    ReputationHistoryResponse,
    MatchingPriority,
    UserBanResponse,
    AppealCreate
)
from app.services.rating_service import RatingService
from app.services.reputation_service import ReputationService

router = APIRouter(prefix="/ratings", tags=["ratings"])


# ============================================================
# 車輛評價 API
# ============================================================

@router.post("/vehicle", response_model=VehicleRatingResponse)
async def create_vehicle_rating(
    rating_data: VehicleRatingCreate,
    db: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """
    對車輛進行評價
    - 需要登入
    - 只能對已完成的行程評價
    - 每個行程只能評價一次
    """
    rating_service = RatingService(db)
    rating, error = await rating_service.create_rating(
        user_id=current_user.id,
        rating_data=rating_data
    )

    if error:
        raise HTTPException(status_code=400, detail=error)

    # 更新用戶信譽分數（根據給出的評價）
    reputation_service = ReputationService(db)
    await reputation_service.apply_rating_impact(
        user_id=current_user.id,
        rating=rating_data.rating,
        trip_id=rating_data.trip_id,
        rating_id=rating.id
    )

    return rating


@router.get("/vehicle/{vehicle_id}", response_model=List[VehicleRatingResponse])
async def get_vehicle_ratings(
    vehicle_id: str,
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_async_session)
):
    """獲取車輛的評價列表（公開）"""
    rating_service = RatingService(db)
    ratings = await rating_service.get_vehicle_ratings(
        vehicle_id=vehicle_id,
        skip=skip,
        limit=limit
    )
    return ratings


@router.get("/vehicle/{vehicle_id}/summary", response_model=VehicleRatingSummary)
async def get_vehicle_rating_summary(
    vehicle_id: str,
    db: AsyncSession = Depends(get_async_session)
):
    """獲取車輛的評價摘要（公開）"""
    rating_service = RatingService(db)
    return await rating_service.get_vehicle_rating_summary(vehicle_id)


@router.get("/my", response_model=List[VehicleRatingResponse])
async def get_my_ratings(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """獲取我給出的評價"""
    rating_service = RatingService(db)
    return await rating_service.get_user_ratings(
        user_id=current_user.id,
        skip=skip,
        limit=limit
    )


@router.get("/trip/{trip_id}/can-rate")
async def check_can_rate(
    trip_id: int,
    db: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """檢查是否可以對行程評價"""
    rating_service = RatingService(db)
    can_rate, message = await rating_service.check_can_rate_trip(
        trip_id=trip_id,
        user_id=current_user.id
    )
    return {
        "can_rate": can_rate,
        "message": message
    }


@router.get("/trip/{trip_id}", response_model=Optional[VehicleRatingResponse])
async def get_trip_rating(
    trip_id: int,
    db: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """獲取行程的評價"""
    rating_service = RatingService(db)
    rating = await rating_service.get_rating_by_trip(
        trip_id=trip_id,
        user_id=current_user.id
    )
    return rating


@router.get("/tags", response_model=List[RatingTagResponse])
async def get_rating_tags(
    tag_type: Optional[str] = Query(None, description="positive 或 negative"),
    db: AsyncSession = Depends(get_async_session)
):
    """獲取可用的評價標籤"""
    rating_service = RatingService(db)
    return await rating_service.get_available_tags(tag_type)


# ============================================================
# 信譽分數 API
# ============================================================

@router.get("/reputation/me", response_model=ReputationScoreResponse)
async def get_my_reputation(
    db: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """獲取我的信譽分數"""
    reputation_service = ReputationService(db)
    reputation = await reputation_service.get_or_create_reputation(current_user.id)

    return ReputationScoreResponse(
        id=reputation.id,
        user_id=reputation.user_id,
        current_score=reputation.current_score,
        level=reputation.level,
        total_positive=reputation.total_positive,
        total_negative=reputation.total_negative,
        total_trips=reputation.total_trips,
        total_ratings_given=reputation.total_ratings_given,
        avg_rating_given=reputation.avg_rating_given,
        matching_priority=reputation.matching_priority,
        can_request_ride=reputation.can_request_ride,
        created_at=reputation.created_at,
        last_updated=reputation.last_updated
    )


@router.get("/reputation/history", response_model=List[ReputationHistoryResponse])
async def get_my_reputation_history(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    db: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """獲取我的信譽歷史"""
    reputation_service = ReputationService(db)
    return await reputation_service.get_user_reputation_history(
        user_id=current_user.id,
        skip=skip,
        limit=limit
    )


@router.get("/reputation/priority", response_model=MatchingPriority)
async def get_my_matching_priority(
    db: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """獲取我的配對優先權資訊"""
    reputation_service = ReputationService(db)
    return await reputation_service.get_matching_priority(current_user.id)


# ============================================================
# 封禁與申訴 API
# ============================================================

@router.get("/bans/active", response_model=Optional[UserBanResponse])
async def get_my_active_ban(
    db: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """獲取我的活躍封禁"""
    reputation_service = ReputationService(db)
    ban = await reputation_service.get_active_ban(current_user.id)

    if not ban:
        return None

    return UserBanResponse(
        id=ban.id,
        user_id=ban.user_id,
        ban_type=ban.ban_type,
        reason=ban.reason,
        triggered_by=ban.triggered_by,
        start_at=ban.start_at,
        end_at=ban.end_at,
        appeal_status=ban.appeal_status,
        appeal_reason=ban.appeal_reason,
        appeal_at=ban.appeal_at,
        reviewed_by=ban.reviewed_by,
        reviewed_at=ban.reviewed_at,
        is_active=ban.is_active,
        is_permanent=ban.is_permanent,
        can_appeal=ban.can_appeal,
        created_at=ban.created_at
    )


@router.get("/bans/history", response_model=List[UserBanResponse])
async def get_my_ban_history(
    db: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """獲取我的封禁歷史"""
    reputation_service = ReputationService(db)
    bans = await reputation_service.get_user_bans(
        user_id=current_user.id,
        include_inactive=True
    )

    return [
        UserBanResponse(
            id=ban.id,
            user_id=ban.user_id,
            ban_type=ban.ban_type,
            reason=ban.reason,
            triggered_by=ban.triggered_by,
            start_at=ban.start_at,
            end_at=ban.end_at,
            appeal_status=ban.appeal_status,
            appeal_reason=ban.appeal_reason,
            appeal_at=ban.appeal_at,
            reviewed_by=ban.reviewed_by,
            reviewed_at=ban.reviewed_at,
            is_active=ban.is_active,
            is_permanent=ban.is_permanent,
            can_appeal=ban.can_appeal,
            created_at=ban.created_at
        )
        for ban in bans
    ]


@router.post("/bans/{ban_id}/appeal")
async def submit_appeal(
    ban_id: int,
    appeal_data: AppealCreate,
    db: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """提交封禁申訴"""
    reputation_service = ReputationService(db)
    success, message = await reputation_service.submit_appeal(
        ban_id=ban_id,
        user_id=current_user.id,
        reason=appeal_data.reason
    )

    if not success:
        raise HTTPException(status_code=400, detail=message)

    return {"success": True, "message": message}
