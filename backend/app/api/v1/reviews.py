# backend/app/api/v1/reviews.py

"""
評論系統 API
行程評價與評論管理
"""

from fastapi import APIRouter, HTTPException, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, desc, func
from typing import List, Optional

from app.core.database import get_async_session
from app.models.review import Review
from app.models.trip import Trip
from app.models.user import User
from app.schemas.review import ReviewResponse, ReviewCreate, ReviewUpdate
from app.api.deps import get_current_user

router = APIRouter(prefix="/api/reviews", tags=["reviews"])

@router.post("/", response_model=ReviewResponse)
async def add_review(
    review_data: ReviewCreate,
    session: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """新增行程評論"""
    
    # 檢查行程存在性和權限
    result = await session.execute(
        select(Trip).where(Trip.trip_id == review_data.trip_id)
    )
    trip = result.scalar_one_or_none()
    if not trip:
        raise HTTPException(status_code=404, detail="行程不存在")
    
    # 檢查是否為此行程的參與者
    if trip.user_id != current_user.id and trip.driver_id != current_user.id:
        raise HTTPException(status_code=403, detail="只能評論自己參與的行程")
    
    # 檢查行程是否已完成
    if trip.status != "completed":
        raise HTTPException(status_code=400, detail="只能評論已完成的行程")
    
    # 確定被評論者
    if trip.user_id == current_user.id:
        # 乘客評論司機
        reviewee_id = trip.driver_id
        review_type = "passenger_to_driver"
    else:
        # 司機評論乘客
        reviewee_id = trip.user_id
        review_type = "driver_to_passenger"
    
    if not reviewee_id:
        raise HTTPException(status_code=400, detail="無法確定被評論者")
    
    # 檢查是否已經評論過
    existing_review = await session.execute(
        select(Review).where(
            and_(
                Review.trip_id == review_data.trip_id,
                Review.reviewer_id == current_user.id,
                Review.reviewee_id == reviewee_id
            )
        )
    )
    if existing_review.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="已經評論過此行程")
    
    # 創建評論
    review = Review(
        trip_id=review_data.trip_id,
        reviewer_id=current_user.id,
        reviewee_id=reviewee_id,
        rating=review_data.rating,
        comment=review_data.comment,
        review_type=review_type,
        is_anonymous=review_data.is_anonymous,
        tags=review_data.tags
    )
    
    session.add(review)
    await session.commit()
    await session.refresh(review)
    
    return review

@router.get("/", response_model=List[ReviewResponse])
async def get_reviews(
    user_id: Optional[int] = Query(None, description="查看特定用戶的評論"),
    limit: int = Query(20, description="最大返回數量"),
    offset: int = Query(0, description="偏移量"),
    session: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """取得評論列表"""
    
    # 如果沒指定用戶，返回當前用戶的評論
    target_user_id = user_id or current_user.id
    
    result = await session.execute(
        select(Review)
        .where(Review.reviewee_id == target_user_id)
        .order_by(desc(Review.created_at))
        .limit(limit)
        .offset(offset)
    )
    reviews = result.scalars().all()
    
    return reviews

@router.get("/my", response_model=List[ReviewResponse])
async def get_my_reviews(
    session: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """取得我給出的評論"""
    
    result = await session.execute(
        select(Review)
        .where(Review.reviewer_id == current_user.id)
        .order_by(desc(Review.created_at))
    )
    reviews = result.scalars().all()
    
    return reviews

@router.get("/stats/{user_id}")
async def get_review_stats(
    user_id: int,
    session: AsyncSession = Depends(get_async_session)
):
    """取得用戶評論統計"""
    
    # 總評論數
    total_count = await session.execute(
        select(func.count(Review.review_id))
        .where(Review.reviewee_id == user_id)
    )
    total = total_count.scalar() or 0
    
    # 平均評分
    avg_rating = await session.execute(
        select(func.avg(Review.rating))
        .where(Review.reviewee_id == user_id)
    )
    average = round(avg_rating.scalar() or 0, 1)
    
    # 評分分布
    rating_distribution = {}
    for rating in range(1, 6):
        count = await session.execute(
            select(func.count(Review.review_id))
            .where(
                and_(
                    Review.reviewee_id == user_id,
                    Review.rating == rating
                )
            )
        )
        rating_distribution[f"{rating}_star"] = count.scalar() or 0
    
    # 有評論文字的比例
    with_comment_count = await session.execute(
        select(func.count(Review.review_id))
        .where(
            and_(
                Review.reviewee_id == user_id,
                Review.comment.isnot(None),
                Review.comment != ""
            )
        )
    )
    with_comment = with_comment_count.scalar() or 0
    comment_ratio = round((with_comment / total * 100) if total > 0 else 0, 1)
    
    return {
        "total_reviews": total,
        "average_rating": average,
        "rating_distribution": rating_distribution,
        "comment_ratio": comment_ratio
    }

@router.put("/{review_id}", response_model=ReviewResponse)
async def update_review(
    review_id: int,
    review_update: ReviewUpdate,
    session: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """編輯評論"""
    
    result = await session.execute(
        select(Review).where(Review.review_id == review_id)
    )
    review = result.scalar_one_or_none()
    if not review:
        raise HTTPException(status_code=404, detail="評論不存在")
    
    # 檢查權限
    if review.reviewer_id != current_user.id:
        raise HTTPException(status_code=403, detail="只能編輯自己的評論")
    
    # 更新評論
    if review_update.rating is not None:
        review.rating = review_update.rating
    if review_update.comment is not None:
        review.comment = review_update.comment
    if review_update.tags is not None:
        review.tags = review_update.tags
    if review_update.is_anonymous is not None:
        review.is_anonymous = review_update.is_anonymous
    
    await session.commit()
    await session.refresh(review)
    
    return review

@router.delete("/{review_id}")
async def delete_review(
    review_id: int,
    session: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """刪除評論"""
    
    result = await session.execute(
        select(Review).where(Review.review_id == review_id)
    )
    review = result.scalar_one_or_none()
    if not review:
        raise HTTPException(status_code=404, detail="評論不存在")
    
    # 檢查權限
    if review.reviewer_id != current_user.id:
        raise HTTPException(status_code=403, detail="只能刪除自己的評論")
    
    await session.delete(review)
    await session.commit()
    
    return {"success": True}
