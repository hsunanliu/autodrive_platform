# backend/app/services/rating_service.py

"""
車輛評價服務
處理評價的建立、查詢、Hash 計算與區塊鏈存證
"""

import hashlib
import json
import logging
from datetime import datetime
from typing import List, Optional, Tuple
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, text, desc

from app.models.rating import VehicleRating, RatingTag
from app.models.vehicle import Vehicle
from app.models.ride import Trip
from app.schemas.rating import VehicleRatingCreate, VehicleRatingSummary

logger = logging.getLogger(__name__)


class RatingService:
    """車輛評價服務"""

    # 評價對信譽分數的影響
    RATING_SCORE_IMPACT = {
        5: 5,   # 5星 +5分
        4: 3,   # 4星 +3分
        3: 0,   # 3星 +0分
        2: -3,  # 2星 -3分
        1: -5,  # 1星 -5分
    }

    def __init__(self, db: AsyncSession):
        self.db = db

    @staticmethod
    def calculate_rating_hash(
        trip_id: int,
        vehicle_id: str,
        user_id: int,
        rating: int,
        comment: Optional[str],
        tags: List[str],
        timestamp: datetime
    ) -> str:
        """
        計算評價的 SHA256 hash
        用於區塊鏈存證，確保評價內容不可篡改
        """
        # 構建標準化的評價數據
        rating_data = {
            "trip_id": trip_id,
            "vehicle_id": vehicle_id,
            "user_id": user_id,
            "rating": rating,
            "comment": comment or "",
            "tags": sorted(tags) if tags else [],
            "timestamp": timestamp.isoformat()
        }

        # 序列化並計算 hash
        data_str = json.dumps(rating_data, sort_keys=True, ensure_ascii=False)
        hash_bytes = hashlib.sha256(data_str.encode('utf-8')).digest()

        return "0x" + hash_bytes.hex()

    async def create_rating(
        self,
        user_id: int,
        rating_data: VehicleRatingCreate
    ) -> Tuple[Optional[VehicleRating], Optional[str]]:
        """
        建立車輛評價

        Returns:
            Tuple[VehicleRating, str]: (評價對象, 錯誤訊息)
        """
        try:
            # 驗證行程是否存在且已完成
            result = await self.db.execute(
                select(Trip).where(Trip.trip_id == rating_data.trip_id)
            )
            trip = result.scalar_one_or_none()
            if not trip:
                return None, "行程不存在"

            if trip.status != "completed":
                return None, "只能對已完成的行程進行評價"

            # 驗證用戶是否為該行程的乘客
            if trip.user_id != user_id:
                return None, "只有行程乘客可以評價"

            # 檢查是否已經評價過
            result = await self.db.execute(
                select(VehicleRating).where(
                    VehicleRating.trip_id == rating_data.trip_id,
                    VehicleRating.user_id == user_id
                )
            )
            existing = result.scalar_one_or_none()
            if existing:
                return None, "您已經對此行程評價過了"

            # 驗證車輛是否存在
            result = await self.db.execute(
                select(Vehicle).where(Vehicle.vehicle_id == rating_data.vehicle_id)
            )
            vehicle = result.scalar_one_or_none()
            if not vehicle:
                return None, "車輛不存在"

            # 計算評價 hash
            now = datetime.utcnow()
            rating_hash = self.calculate_rating_hash(
                trip_id=rating_data.trip_id,
                vehicle_id=rating_data.vehicle_id,
                user_id=user_id,
                rating=rating_data.rating,
                comment=rating_data.comment,
                tags=rating_data.tags or [],
                timestamp=now
            )

            # 上傳完整評論內容到 Walrus（best-effort）。上傳的是與 rating_hash 完全相同的
            # 標準化內容，因此 Walrus 內容的 SHA256 == rating_hash，鏈上以 blob_id + hash 錨定。
            content_blob_id = None
            try:
                from app.services.walrus_service import walrus_service
                content_bytes = json.dumps({
                    "trip_id": rating_data.trip_id,
                    "vehicle_id": rating_data.vehicle_id,
                    "user_id": user_id,
                    "rating": rating_data.rating,
                    "comment": rating_data.comment or "",
                    "tags": sorted(rating_data.tags) if rating_data.tags else [],
                    "timestamp": now.isoformat(),
                }, sort_keys=True, ensure_ascii=False).encode("utf-8")
                walrus_result = await walrus_service.store(content_bytes)
                content_blob_id = walrus_result["blob_id"]
                logger.info(f"評論已上傳 Walrus: blob={content_blob_id}")
            except Exception as e:
                logger.warning(f"評論上傳 Walrus 失敗 (不影響評價): {e}")

            # 建立評價
            new_rating = VehicleRating(
                trip_id=rating_data.trip_id,
                vehicle_id=rating_data.vehicle_id,
                user_id=user_id,
                rating=rating_data.rating,
                comment=rating_data.comment,
                tags=rating_data.tags or [],
                rating_hash=rating_hash,
                content_blob_id=content_blob_id,
                created_at=now
            )

            self.db.add(new_rating)

            # 更新車輛評價統計
            await self._update_vehicle_rating_stats(vehicle, rating_data.rating)

            await self.db.commit()
            await self.db.refresh(new_rating)

            logger.info(f"Created rating {new_rating.id} for vehicle {rating_data.vehicle_id}")
            return new_rating, None

        except Exception as e:
            await self.db.rollback()
            logger.error(f"Error creating rating: {e}")
            return None, f"建立評價失敗: {str(e)}"

    async def _update_vehicle_rating_stats(
        self,
        vehicle: Vehicle,
        new_rating: int
    ) -> None:
        """更新車輛評價統計"""
        # 計算新的平均評分
        total_ratings = getattr(vehicle, 'total_ratings', 0) or 0
        avg_rating = float(getattr(vehicle, 'avg_rating', 0) or 0)

        new_total = total_ratings + 1
        new_avg = ((avg_rating * total_ratings) + new_rating) / new_total

        # 更新評分分布
        distribution = getattr(vehicle, 'rating_distribution', None)
        if distribution is None:
            distribution = {"1": 0, "2": 0, "3": 0, "4": 0, "5": 0}
        distribution[str(new_rating)] = distribution.get(str(new_rating), 0) + 1

        # 使用原始 SQL 更新（避免 ORM 屬性問題）
        await self.db.execute(
            text("""
            UPDATE vehicles
            SET avg_rating = :avg_rating,
                total_ratings = :total_ratings,
                rating_distribution = :distribution
            WHERE vehicle_id = :vehicle_id
            """),
            {
                "avg_rating": round(new_avg, 1),
                "total_ratings": new_total,
                "distribution": json.dumps(distribution),
                "vehicle_id": vehicle.vehicle_id
            }
        )

    async def get_rating_by_id(self, rating_id: int) -> Optional[VehicleRating]:
        """根據 ID 獲取評價"""
        result = await self.db.execute(
            select(VehicleRating).where(VehicleRating.id == rating_id)
        )
        return result.scalar_one_or_none()

    async def get_rating_by_trip(
        self,
        trip_id: int,
        user_id: int
    ) -> Optional[VehicleRating]:
        """獲取特定行程的評價"""
        result = await self.db.execute(
            select(VehicleRating).where(
                VehicleRating.trip_id == trip_id,
                VehicleRating.user_id == user_id
            )
        )
        return result.scalar_one_or_none()

    async def get_vehicle_ratings(
        self,
        vehicle_id: str,
        skip: int = 0,
        limit: int = 20
    ) -> List[VehicleRating]:
        """獲取車輛的所有評價"""
        result = await self.db.execute(
            select(VehicleRating)
            .where(VehicleRating.vehicle_id == vehicle_id)
            .order_by(desc(VehicleRating.created_at))
            .offset(skip)
            .limit(limit)
        )
        return list(result.scalars().all())

    async def get_user_ratings(
        self,
        user_id: int,
        skip: int = 0,
        limit: int = 20
    ) -> List[VehicleRating]:
        """獲取用戶給出的所有評價"""
        result = await self.db.execute(
            select(VehicleRating)
            .where(VehicleRating.user_id == user_id)
            .order_by(desc(VehicleRating.created_at))
            .offset(skip)
            .limit(limit)
        )
        return list(result.scalars().all())

    async def get_vehicle_rating_summary(self, vehicle_id: str) -> VehicleRatingSummary:
        """獲取車輛評價摘要"""
        result = await self.db.execute(
            select(VehicleRating).where(VehicleRating.vehicle_id == vehicle_id)
        )
        ratings = list(result.scalars().all())

        if not ratings:
            return VehicleRatingSummary(
                vehicle_id=vehicle_id,
                avg_rating=0.0,
                total_ratings=0,
                rating_distribution={"1": 0, "2": 0, "3": 0, "4": 0, "5": 0},
                recent_tags=[]
            )

        # 計算平均分
        total = len(ratings)
        avg = sum(r.rating for r in ratings) / total

        # 計算分布
        distribution = {"1": 0, "2": 0, "3": 0, "4": 0, "5": 0}
        for r in ratings:
            distribution[str(r.rating)] += 1

        # 統計最近常用標籤
        tag_counts = {}
        for r in ratings[-50:]:  # 最近 50 條評價
            if r.tags:
                for tag in r.tags:
                    tag_counts[tag] = tag_counts.get(tag, 0) + 1

        recent_tags = sorted(tag_counts.keys(), key=lambda t: tag_counts[t], reverse=True)[:5]

        return VehicleRatingSummary(
            vehicle_id=vehicle_id,
            avg_rating=round(avg, 1),
            total_ratings=total,
            rating_distribution=distribution,
            recent_tags=recent_tags
        )

    async def get_available_tags(self, tag_type: Optional[str] = None) -> List[RatingTag]:
        """獲取可用的評價標籤"""
        stmt = select(RatingTag).where(RatingTag.is_active == True)
        if tag_type:
            stmt = stmt.where(RatingTag.tag_type == tag_type)
        stmt = stmt.order_by(RatingTag.sort_order)
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def update_rating_blockchain_proof(
        self,
        rating_id: int,
        tx_id: str,
        proof_object_id: str
    ) -> bool:
        """更新評價的區塊鏈存證資訊"""
        try:
            result = await self.db.execute(
                select(VehicleRating).where(VehicleRating.id == rating_id)
            )
            rating = result.scalar_one_or_none()
            if not rating:
                return False

            rating.blockchain_tx_id = tx_id
            rating.proof_object_id = proof_object_id
            await self.db.commit()

            logger.info(f"Updated blockchain proof for rating {rating_id}")
            return True

        except Exception as e:
            await self.db.rollback()
            logger.error(f"Error updating blockchain proof: {e}")
            return False

    async def get_pending_on_chain_ratings(self, limit: int = 100) -> List[VehicleRating]:
        """獲取待上鏈的評價"""
        result = await self.db.execute(
            select(VehicleRating)
            .where(
                VehicleRating.rating_hash.isnot(None),
                VehicleRating.proof_object_id.is_(None)
            )
            .order_by(VehicleRating.created_at)
            .limit(limit)
        )
        return list(result.scalars().all())

    async def check_can_rate_trip(self, trip_id: int, user_id: int) -> Tuple[bool, str]:
        """檢查用戶是否可以評價該行程"""
        result = await self.db.execute(
            select(Trip).where(Trip.trip_id == trip_id)
        )
        trip = result.scalar_one_or_none()
        if not trip:
            return False, "行程不存在"

        if trip.user_id != user_id:
            return False, "只有行程乘客可以評價"

        if trip.status != "completed":
            return False, "只能對已完成的行程進行評價"

        result = await self.db.execute(
            select(VehicleRating).where(
                VehicleRating.trip_id == trip_id,
                VehicleRating.user_id == user_id
            )
        )
        existing = result.scalar_one_or_none()
        if existing:
            return False, "您已經對此行程評價過了"

        return True, "可以評價"
