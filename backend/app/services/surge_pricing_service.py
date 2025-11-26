"""
動態定價服務
整合時段、天氣、供需等因素計算最終加價係數
"""

import logging
import random
from datetime import datetime
from typing import Dict, Any, Optional, Tuple
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, func

logger = logging.getLogger(__name__)


class SurgePricingService:
    """動態定價服務 - 統一管理所有定價邏輯"""

    def __init__(self, db: AsyncSession = None):
        self.db = db

        # 動態定價配置
        self.SURGE_ENABLED = True  # 是否啟用動態定價
        self.MAX_SURGE_MULTIPLIER = 3.0  # 最高加價倍數
        self.MIN_SURGE_MULTIPLIER = 1.0  # 最低倍數（無加價）

        # 時段加價配置
        self.PEAK_MORNING_START = 7
        self.PEAK_MORNING_END = 9
        self.PEAK_EVENING_START = 17
        self.PEAK_EVENING_END = 19
        self.LATE_NIGHT_START = 23
        self.LATE_NIGHT_END = 5

        self.PEAK_HOUR_MULTIPLIER = 1.5  # 尖峰時段 +50%
        self.LATE_NIGHT_MULTIPLIER = 1.3  # 深夜時段 +30%
        self.WEEKEND_MULTIPLIER = 1.2    # 週末白天 +20%

        # 供需加價閾值
        self.DEMAND_EXTREME_RATIO = 3.0  # 需求/供給 > 3.0
        self.DEMAND_HIGH_RATIO = 2.0
        self.DEMAND_MEDIUM_RATIO = 1.5
        self.DEMAND_LOW_RATIO = 1.0

        self.DEMAND_EXTREME_MULTIPLIER = 2.5  # +150%
        self.DEMAND_HIGH_MULTIPLIER = 2.0     # +100%
        self.DEMAND_MEDIUM_MULTIPLIER = 1.5   # +50%
        self.DEMAND_LOW_MULTIPLIER = 1.2      # +20%

    async def calculate_surge_pricing(
        self,
        pickup_lat: float,
        pickup_lng: float,
        trip_time: Optional[datetime] = None
    ) -> Dict[str, Any]:
        """
        計算完整的動態定價係數

        Args:
            pickup_lat: 上車點緯度
            pickup_lng: 上車點經度
            trip_time: 行程時間（預設為當前時間）

        Returns:
            包含最終係數和各因素分解的字典
        """
        if not self.SURGE_ENABLED:
            return self._create_no_surge_response()

        trip_time = trip_time or datetime.now()

        # 計算各因素
        time_multiplier = self._calculate_time_surge(trip_time)
        weather_multiplier = await self._calculate_weather_surge(pickup_lat, pickup_lng)
        demand_multiplier = await self._calculate_demand_surge(pickup_lat, pickup_lng)

        # 添加位置波動因素（基於經緯度的偽隨機）
        # 使用經緯度作為種子，確保相同位置得到相同的波動
        location_seed = int((pickup_lat + pickup_lng) * 10000) % 1000
        random.seed(location_seed + int(trip_time.timestamp()) // 300)  # 每5分鐘變化一次
        location_variance = random.uniform(0.95, 1.15)  # ±15% 波動

        # 使用加權平均而不是取最大值，使得價格更有變化
        # 如果任何一個因素有加價，最終結果會受影響
        weights = {
            'time': 0.3,
            'weather': 0.2,
            'demand': 0.5  # 供需影響最大
        }

        base_multiplier = (
            time_multiplier * weights['time'] +
            weather_multiplier * weights['weather'] +
            demand_multiplier * weights['demand']
        )

        # 應用位置波動
        final_multiplier = base_multiplier * location_variance

        # 限制在合理範圍內
        final_multiplier = min(final_multiplier, self.MAX_SURGE_MULTIPLIER)
        final_multiplier = max(final_multiplier, self.MIN_SURGE_MULTIPLIER)

        # 生成加價原因說明
        reason = self._generate_surge_reason(
            final_multiplier,
            time_multiplier,
            weather_multiplier,
            demand_multiplier
        )

        return {
            'surge_multiplier': final_multiplier,
            'breakdown': {
                'time': time_multiplier,
                'weather': weather_multiplier,
                'demand': demand_multiplier
            },
            'reason': reason,
            'has_surge': final_multiplier > 1.0
        }

    def _calculate_time_surge(self, trip_time: datetime) -> float:
        """
        計算時段加價係數

        時段規則：
        - 平日上班尖峰（7-9, 17-19）: 1.5 倍
        - 深夜時段（23-5）: 1.3 倍
        - 週末白天（10-20）: 1.2 倍
        - 其他時段: 1.0 倍
        """
        hour = trip_time.hour
        weekday = trip_time.weekday()  # 0=週一, 6=週日
        is_weekend = weekday >= 5  # 週六日

        # 深夜時段
        if hour >= self.LATE_NIGHT_START or hour <= self.LATE_NIGHT_END:
            return self.LATE_NIGHT_MULTIPLIER

        # 平日尖峰時段
        if not is_weekend:
            if (self.PEAK_MORNING_START <= hour < self.PEAK_MORNING_END or
                self.PEAK_EVENING_START <= hour < self.PEAK_EVENING_END):
                return self.PEAK_HOUR_MULTIPLIER

        # 週末白天
        if is_weekend and 10 <= hour < 20:
            return self.WEEKEND_MULTIPLIER

        # 一般時段
        return 1.0

    async def _calculate_weather_surge(self, lat: float, lng: float) -> float:
        """
        計算天氣加價係數

        目前版本：暫時返回 1.0（無加價）
        Phase 2 會整合天氣 API
        """
        # TODO: Phase 2 整合 OpenWeatherMap API
        return 1.0

    async def _calculate_demand_surge(self, pickup_lat: float, pickup_lng: float) -> float:
        """
        計算供需加價係數

        邏輯：
        1. 計算附近 5 公里內的待接訂單數（需求）
        2. 計算附近 5 公里內的可用司機數（供給）
        3. 根據需求/供給比計算係數
        """
        if not self.db:
            # 如果沒有資料庫連接，返回無加價
            return 1.0

        try:
            radius_km = 5.0

            # 計算需求：pending 狀態的行程數
            demand = await self._count_pending_trips_nearby(pickup_lat, pickup_lng, radius_km)

            # 計算供給：可用司機數
            supply = await self._count_available_drivers_nearby(pickup_lat, pickup_lng, radius_km)

            # 避免除以零
            if supply == 0:
                # 沒有司機，最高加價
                logger.warning(f"附近沒有可用司機: lat={pickup_lat}, lng={pickup_lng}")
                return self.DEMAND_EXTREME_MULTIPLIER

            # 計算供需比
            demand_supply_ratio = demand / supply

            logger.info(f"供需分析: 需求={demand}, 供給={supply}, 比例={demand_supply_ratio:.2f}")

            # 根據比例返回係數
            if demand_supply_ratio >= self.DEMAND_EXTREME_RATIO:
                return self.DEMAND_EXTREME_MULTIPLIER
            elif demand_supply_ratio >= self.DEMAND_HIGH_RATIO:
                return self.DEMAND_HIGH_MULTIPLIER
            elif demand_supply_ratio >= self.DEMAND_MEDIUM_RATIO:
                return self.DEMAND_MEDIUM_MULTIPLIER
            elif demand_supply_ratio >= self.DEMAND_LOW_RATIO:
                return self.DEMAND_LOW_MULTIPLIER
            else:
                return 1.0  # 供給充足

        except Exception as e:
            logger.error(f"計算供需失敗: {e}")
            return 1.0  # 失敗時不加價

    async def _count_pending_trips_nearby(
        self,
        lat: float,
        lng: float,
        radius_km: float
    ) -> int:
        """計算附近待接訂單數"""
        from app.models.ride import Trip
        from app.core.database import async_session_maker

        # 簡單的矩形範圍查詢
        # 1 度緯度 ≈ 111 公里
        lat_range = radius_km / 111.0
        lng_range = radius_km / (111.0 * abs(lat / 90.0))  # 考慮緯度影響

        stmt = select(func.count(Trip.trip_id)).where(
            and_(
                Trip.status == 'requested',
                Trip.pickup_lat.between(lat - lat_range, lat + lat_range),
                Trip.pickup_lng.between(lng - lng_range, lng + lng_range)
            )
        )

        # 使用獨立的數據庫會話避免 greenlet 錯誤
        async with async_session_maker() as session:
            result = await session.execute(stmt)
            count = result.scalar() or 0
            return count

    async def _count_available_drivers_nearby(
        self,
        lat: float,
        lng: float,
        radius_km: float
    ) -> int:
        """計算附近可用司機數"""
        from app.models.vehicle import Vehicle
        from app.models.user import User
        from app.core.database import async_session_maker

        lat_range = radius_km / 111.0
        lng_range = radius_km / (111.0 * abs(lat / 90.0))

        # 查詢可用車輛（狀態為 available）
        stmt = select(func.count(Vehicle.vehicle_id)).where(
            and_(
                Vehicle.status == 'available',
                Vehicle.current_lat.isnot(None),
                Vehicle.current_lng.isnot(None),
                Vehicle.current_lat.between(lat - lat_range, lat + lat_range),
                Vehicle.current_lng.between(lng - lng_range, lng + lng_range)
            )
        )

        # 使用獨立的數據庫會話避免 greenlet 錯誤
        async with async_session_maker() as session:
            result = await session.execute(stmt)
            count = result.scalar() or 0
            return count

    def _generate_surge_reason(
        self,
        final: float,
        time: float,
        weather: float,
        demand: float
    ) -> str:
        """生成加價原因說明"""
        if final <= 1.0:
            return ""

        reasons = []

        # 判斷哪個因素導致加價
        if time == final and time > 1.0:
            if time >= self.PEAK_HOUR_MULTIPLIER:
                reasons.append("尖峰時段")
            elif time >= self.LATE_NIGHT_MULTIPLIER:
                reasons.append("深夜時段")
            elif time >= self.WEEKEND_MULTIPLIER:
                reasons.append("週末白天")

        if weather == final and weather > 1.0:
            reasons.append("天氣因素")

        if demand == final and demand > 1.0:
            if demand >= self.DEMAND_EXTREME_MULTIPLIER:
                reasons.append("需求極高")
            elif demand >= self.DEMAND_HIGH_MULTIPLIER:
                reasons.append("需求較高")
            elif demand >= self.DEMAND_MEDIUM_MULTIPLIER:
                reasons.append("需求增加")
            else:
                reasons.append("車輛較少")

        if not reasons:
            reasons.append("當前需求")

        percentage = int((final - 1.0) * 100)
        reason_text = "、".join(reasons)

        return f"由於{reason_text}，目前價格調整 +{percentage}%"

    def _create_no_surge_response(self) -> Dict[str, Any]:
        """創建無加價響應"""
        return {
            'surge_multiplier': 1.0,
            'breakdown': {
                'time': 1.0,
                'weather': 1.0,
                'demand': 1.0
            },
            'reason': "",
            'has_surge': False
        }
