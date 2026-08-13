# backend/app/services/reputation_service.py

"""
信譽分數服務
處理用戶信譽分數計算、等級判定、封禁管理
"""

import logging
from datetime import datetime, timedelta, timezone
from typing import List, Optional, Tuple
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc, or_

from app.models.reputation import ReputationScore, ReputationHistory, UserBan
from app.models.user import User
from app.schemas.rating import (
    ReputationEventType,
    BanType,
    AppealStatus,
    MatchingPriority
)

logger = logging.getLogger(__name__)


class ReputationService:
    """信譽分數服務"""

    # 事件對信譽分數的影響
    EVENT_SCORE_IMPACT = {
        # 正面事件
        ReputationEventType.RATING_5_STAR.value: 5,
        ReputationEventType.RATING_4_STAR.value: 3,
        ReputationEventType.COMPLETE_TRIP.value: 2,
        ReputationEventType.LONG_TRIP_BONUS.value: 1,

        # 中性事件
        ReputationEventType.RATING_3_STAR.value: 0,

        # 負面事件
        ReputationEventType.RATING_2_STAR.value: -3,
        ReputationEventType.RATING_1_STAR.value: -5,
        ReputationEventType.CANCEL_TRIP.value: -5,
        ReputationEventType.NO_SHOW.value: -10,
        ReputationEventType.TIMEOUT.value: -3,
    }

    # 等級對應的封禁規則
    LEVEL_BAN_RULES = {
        "banned": {
            "ban_type": BanType.PERMANENT.value,
            "duration_hours": None,
            "reason": "信譽分數過低，帳號已被永久封禁"
        },
        "probation": {
            "ban_type": BanType.TEMPORARY.value,
            "duration_hours": 168,  # 7天
            "reason": "信譽分數過低，帳號暫時封禁7天"
        },
        "restricted": {
            "ban_type": BanType.WARNING.value,
            "duration_hours": 24,  # 1天警告
            "reason": "信譽分數較低，帳號受到限制"
        }
    }

    def __init__(self, db: AsyncSession):
        self.db = db

    # ============================================================
    # 信譽分數管理
    # ============================================================

    async def get_or_create_reputation(self, user_id: int) -> ReputationScore:
        """獲取或創建用戶信譽分數記錄"""
        result = await self.db.execute(
            select(ReputationScore).where(ReputationScore.user_id == user_id)
        )
        reputation = result.scalar_one_or_none()

        if not reputation:
            reputation = ReputationScore(
                user_id=user_id,
                current_score=100,
                level="normal"
            )
            self.db.add(reputation)
            await self.db.commit()
            await self.db.refresh(reputation)
            logger.info(f"Created reputation record for user {user_id}")

        return reputation

    async def record_event(
        self,
        user_id: int,
        event_type: str,
        reason: Optional[str] = None,
        trip_id: Optional[int] = None,
        rating_id: Optional[int] = None,
        custom_score_change: Optional[int] = None
    ) -> Tuple[ReputationScore, ReputationHistory]:
        """
        記錄信譽事件並更新分數

        Args:
            user_id: 用戶 ID
            event_type: 事件類型
            reason: 原因說明
            trip_id: 關聯行程 ID
            rating_id: 關聯評價 ID
            custom_score_change: 自定義分數變動（用於管理員調整）

        Returns:
            Tuple[ReputationScore, ReputationHistory]: 更新後的信譽分數和歷史記錄
        """
        try:
            reputation = await self.get_or_create_reputation(user_id)

            # 計算分數變動
            if custom_score_change is not None:
                score_change = custom_score_change
            else:
                score_change = self.EVENT_SCORE_IMPACT.get(event_type, 0)

            score_before = reputation.current_score
            score_after = max(0, min(200, score_before + score_change))

            # 更新信譽分數
            reputation.current_score = score_after
            reputation.level = ReputationScore.calculate_level(score_after)

            if score_change > 0:
                reputation.total_positive += 1
            elif score_change < 0:
                reputation.total_negative += 1

            # 記錄歷史
            history = ReputationHistory(
                user_id=user_id,
                event_type=event_type,
                score_change=score_change,
                score_before=score_before,
                score_after=score_after,
                reason=reason,
                trip_id=trip_id,
                rating_id=rating_id
            )
            self.db.add(history)

            # 檢查是否需要觸發封禁
            await self._check_and_apply_ban(user_id, reputation.level)

            await self.db.commit()
            await self.db.refresh(reputation)
            await self.db.refresh(history)

            logger.info(
                f"Recorded event {event_type} for user {user_id}: "
                f"{score_before} -> {score_after} ({score_change:+d})"
            )

            return reputation, history

        except Exception as e:
            await self.db.rollback()
            logger.error(f"Error recording reputation event: {e}")
            raise

    async def _check_and_apply_ban(self, user_id: int, level: str) -> Optional[UserBan]:
        """檢查並應用封禁規則"""
        if level not in self.LEVEL_BAN_RULES:
            return None

        # 檢查是否已有活躍的封禁
        result = await self.db.execute(
            select(UserBan).where(
                UserBan.user_id == user_id,
                UserBan.appeal_status != AppealStatus.APPROVED.value,
                or_(
                    UserBan.end_at.is_(None),
                    UserBan.end_at > datetime.now(timezone.utc)
                )
            )
        )
        active_ban = result.scalar_one_or_none()

        if active_ban:
            return None  # 已有封禁，不重複處理

        # 應用封禁
        rule = self.LEVEL_BAN_RULES[level]

        end_at = None
        if rule["duration_hours"]:
            end_at = datetime.now(timezone.utc) + timedelta(hours=rule["duration_hours"])

        ban = UserBan(
            user_id=user_id,
            ban_type=rule["ban_type"],
            reason=rule["reason"],
            triggered_by="low_score",
            end_at=end_at
        )
        self.db.add(ban)

        # 更新用戶封禁狀態
        result = await self.db.execute(
            select(User).where(User.id == user_id)
        )
        user = result.scalar_one_or_none()
        if user:
            user.is_active = False

        logger.warning(f"Applied {rule['ban_type']} ban to user {user_id} due to low score")
        return ban

    # ============================================================
    # 評價對信譽的影響
    # ============================================================

    async def apply_rating_impact(
        self,
        user_id: int,
        rating: int,
        trip_id: int,
        rating_id: int
    ) -> ReputationScore:
        """
        根據評價更新信譽分數
        這是評價系統調用的入口
        """
        event_type_map = {
            5: ReputationEventType.RATING_5_STAR.value,
            4: ReputationEventType.RATING_4_STAR.value,
            3: ReputationEventType.RATING_3_STAR.value,
            2: ReputationEventType.RATING_2_STAR.value,
            1: ReputationEventType.RATING_1_STAR.value,
        }

        event_type = event_type_map.get(rating, ReputationEventType.RATING_3_STAR.value)

        reputation, _ = await self.record_event(
            user_id=user_id,
            event_type=event_type,
            reason=f"收到 {rating} 星評價",
            trip_id=trip_id,
            rating_id=rating_id
        )

        return reputation

    # ============================================================
    # 配對優先順序
    # ============================================================

    async def get_matching_priority(self, user_id: int) -> MatchingPriority:
        """獲取用戶的配對優先權資訊"""
        reputation = await self.get_or_create_reputation(user_id)

        restrictions = []

        # 檢查活躍封禁
        active_ban = await self.get_active_ban(user_id)
        if active_ban:
            restrictions.append(f"封禁中: {active_ban.reason}")

        # 檢查等級限制
        if reputation.level in ("warning", "restricted", "probation"):
            restrictions.append(f"信譽等級較低: {reputation.level}")

        return MatchingPriority(
            user_id=user_id,
            reputation_score=reputation.current_score,
            reputation_level=reputation.level,
            priority_weight=reputation.matching_priority,
            can_request_ride=reputation.can_request_ride and not active_ban,
            restrictions=restrictions
        )

    async def sort_by_reputation(
        self,
        user_ids: List[int]
    ) -> List[Tuple[int, float]]:
        """
        根據信譽分數排序用戶列表

        Returns:
            List[Tuple[int, float]]: [(user_id, priority_weight), ...]
        """
        priorities = []
        for user_id in user_ids:
            result = await self.db.execute(
                select(ReputationScore).where(ReputationScore.user_id == user_id)
            )
            reputation = result.scalar_one_or_none()

            if reputation:
                weight = reputation.matching_priority
            else:
                weight = 1.0  # 新用戶預設權重

            priorities.append((user_id, weight))

        # 按權重降序排序
        priorities.sort(key=lambda x: x[1], reverse=True)
        return priorities

    # ============================================================
    # 封禁管理
    # ============================================================

    async def get_active_ban(self, user_id: int) -> Optional[UserBan]:
        """獲取用戶的活躍封禁"""
        result = await self.db.execute(
            select(UserBan).where(
                UserBan.user_id == user_id,
                UserBan.appeal_status != AppealStatus.APPROVED.value,
                or_(
                    UserBan.end_at.is_(None),
                    UserBan.end_at > datetime.now(timezone.utc)
                )
            ).order_by(desc(UserBan.created_at))
        )
        return result.scalars().first()

    async def create_ban(
        self,
        user_id: int,
        ban_type: str,
        reason: str,
        triggered_by: str = "admin",
        duration_hours: Optional[int] = None
    ) -> UserBan:
        """管理員建立封禁"""
        end_at = None
        if duration_hours and ban_type != BanType.PERMANENT.value:
            end_at = datetime.now(timezone.utc) + timedelta(hours=duration_hours)

        ban = UserBan(
            user_id=user_id,
            ban_type=ban_type,
            reason=reason,
            triggered_by=triggered_by,
            end_at=end_at
        )
        self.db.add(ban)

        # 更新用戶狀態
        result = await self.db.execute(
            select(User).where(User.id == user_id)
        )
        user = result.scalar_one_or_none()
        if user:
            user.is_active = False

        await self.db.commit()
        await self.db.refresh(ban)

        logger.info(f"Admin created {ban_type} ban for user {user_id}")
        return ban

    async def submit_appeal(
        self,
        ban_id: int,
        user_id: int,
        reason: str
    ) -> Tuple[bool, str]:
        """提交封禁申訴"""
        result = await self.db.execute(
            select(UserBan).where(
                UserBan.id == ban_id,
                UserBan.user_id == user_id
            )
        )
        ban = result.scalar_one_or_none()

        if not ban:
            return False, "封禁記錄不存在"

        if not ban.can_appeal:
            return False, "此封禁不可申訴或已申訴過"

        ban.appeal_status = AppealStatus.PENDING.value
        ban.appeal_reason = reason
        ban.appeal_at = datetime.now(timezone.utc)

        await self.db.commit()

        logger.info(f"User {user_id} submitted appeal for ban {ban_id}")
        return True, "申訴已提交，請等待審核"

    async def review_appeal(
        self,
        ban_id: int,
        reviewer_id: int,
        approved: bool,
        comment: Optional[str] = None
    ) -> Tuple[bool, str]:
        """審核封禁申訴"""
        result = await self.db.execute(
            select(UserBan).where(UserBan.id == ban_id)
        )
        ban = result.scalar_one_or_none()

        if not ban:
            return False, "封禁記錄不存在"

        if ban.appeal_status != AppealStatus.PENDING.value:
            return False, "此申訴不在待審核狀態"

        ban.appeal_status = AppealStatus.APPROVED.value if approved else AppealStatus.REJECTED.value
        ban.reviewed_by = reviewer_id
        ban.reviewed_at = datetime.now(timezone.utc)

        if approved:
            # 解除封禁
            result = await self.db.execute(
                select(User).where(User.id == ban.user_id)
            )
            user = result.scalar_one_or_none()
            if user:
                user.is_active = True

            # 記錄信譽恢復事件
            await self.record_event(
                user_id=ban.user_id,
                event_type=ReputationEventType.APPEAL_APPROVED.value,
                reason=f"申訴通過: {comment}" if comment else "申訴通過",
                custom_score_change=10  # 申訴通過加回一些分數
            )

        await self.db.commit()

        status = "通過" if approved else "拒絕"
        logger.info(f"Appeal for ban {ban_id} was {status} by admin {reviewer_id}")
        return True, f"申訴已{status}"

    async def check_and_release_expired_bans(self) -> int:
        """檢查並解除過期的臨時封禁"""
        now = datetime.now(timezone.utc)

        result = await self.db.execute(
            select(UserBan).where(
                UserBan.end_at.isnot(None),
                UserBan.end_at <= now,
                UserBan.appeal_status != AppealStatus.APPROVED.value
            )
        )
        expired_bans = list(result.scalars().all())

        count = 0
        for ban in expired_bans:
            # 解除用戶封禁狀態
            result = await self.db.execute(
                select(User).where(User.id == ban.user_id)
            )
            user = result.scalar_one_or_none()
            if user:
                # 檢查是否還有其他活躍封禁
                result = await self.db.execute(
                    select(UserBan).where(
                        UserBan.user_id == ban.user_id,
                        UserBan.id != ban.id,
                        UserBan.appeal_status != AppealStatus.APPROVED.value,
                        or_(
                            UserBan.end_at.is_(None),
                            UserBan.end_at > now
                        )
                    )
                )
                other_ban = result.scalar_one_or_none()

                if not other_ban:
                    user.is_active = True
                    count += 1

        await self.db.commit()
        logger.info(f"Released {count} expired bans")
        return count

    # ============================================================
    # 查詢方法
    # ============================================================

    async def get_user_reputation_history(
        self,
        user_id: int,
        skip: int = 0,
        limit: int = 50
    ) -> List[ReputationHistory]:
        """獲取用戶信譽歷史"""
        result = await self.db.execute(
            select(ReputationHistory)
            .where(ReputationHistory.user_id == user_id)
            .order_by(desc(ReputationHistory.created_at))
            .offset(skip)
            .limit(limit)
        )
        return list(result.scalars().all())

    async def get_user_bans(
        self,
        user_id: int,
        include_inactive: bool = False
    ) -> List[UserBan]:
        """獲取用戶封禁記錄"""
        stmt = select(UserBan).where(UserBan.user_id == user_id)

        if not include_inactive:
            now = datetime.now(timezone.utc)
            stmt = stmt.where(
                UserBan.appeal_status != AppealStatus.APPROVED.value,
                or_(
                    UserBan.end_at.is_(None),
                    UserBan.end_at > now
                )
            )

        stmt = stmt.order_by(desc(UserBan.created_at))
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def get_pending_appeals(self, skip: int = 0, limit: int = 50) -> List[UserBan]:
        """獲取待審核的申訴"""
        result = await self.db.execute(
            select(UserBan)
            .where(UserBan.appeal_status == AppealStatus.PENDING.value)
            .order_by(UserBan.appeal_at)
            .offset(skip)
            .limit(limit)
        )
        return list(result.scalars().all())
