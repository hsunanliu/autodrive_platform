"""
車輛召回服務
處理司機召回空閒車輛的業務邏輯
"""
import logging
from datetime import datetime
from typing import Optional, Dict, Any
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from app.models import Vehicle, User
from app.services.location_service import LocationService

logger = logging.getLogger(__name__)


class VehicleRecallService:
    """車輛召回服務"""

    def __init__(self, db: AsyncSession):
        self.db = db
        self.location_service = LocationService()

    async def start_recall(
        self,
        driver_id: int,
        vehicle_id: str,
        target_lat: float,
        target_lng: float
    ) -> Dict[str, Any]:
        """
        開始召回車輛

        Args:
            driver_id: 司機 ID
            vehicle_id: 車輛 ID
            target_lat: 目標位置緯度
            target_lng: 目標位置經度

        Returns:
            召回信息字典

        Raises:
            ValueError: 驗證失敗時
        """
        logger.info(f"🚗 司機 {driver_id} 請求召回車輛 {vehicle_id} 到 ({target_lat}, {target_lng})")

        # 1. 驗證司機存在
        driver_result = await self.db.execute(
            select(User).where(User.id == driver_id)
        )
        driver = driver_result.scalar_one_or_none()
        if not driver:
            raise ValueError(f"司機 {driver_id} 不存在")

        # 檢查是否為司機角色
        if not driver.is_driver:
            raise ValueError(f"用戶 {driver_id} 不是司機")

        # 2. 驗證車輛存在且屬於該司機
        vehicle_result = await self.db.execute(
            select(Vehicle).where(
                and_(
                    Vehicle.vehicle_id == vehicle_id,
                    Vehicle.owner_id == driver_id
                )
            )
        )
        vehicle = vehicle_result.scalar_one_or_none()
        if not vehicle:
            raise ValueError(f"車輛 {vehicle_id} 不存在或不屬於司機 {driver_id}")

        # 3. 檢查車輛狀態（可召回 offline 或 available 狀態的車輛）
        if vehicle.status not in ['available', 'offline']:
            raise ValueError(f"車輛當前狀態為 {vehicle.status}，無法召回（僅可召回空閒或離線車輛）")

        # 4. 檢查是否已在召回中
        if vehicle.recall_started_at is not None:
            raise ValueError(f"車輛已在召回中（開始時間: {vehicle.recall_started_at}）")

        # 5. 計算距離和預估時間
        distance_km = self.location_service.haversine_km(
            vehicle.current_lat,
            vehicle.current_lng,
            target_lat,
            target_lng
        )

        # 假設平均速度 30 km/h
        eta_minutes = int((distance_km / 30.0) * 60)

        # 6. 更新車輛狀態（使用 on_trip 表示召回中）
        vehicle.status = 'on_trip'
        vehicle.recall_target_lat = target_lat
        vehicle.recall_target_lng = target_lng
        vehicle.recall_started_at = datetime.utcnow()

        await self.db.commit()
        await self.db.refresh(vehicle)

        logger.info(
            f"✅ 召回已開始: 車輛 {vehicle_id} 將移動 {distance_km:.1f} km "
            f"(預估 {eta_minutes} 分鐘)"
        )

        return {
            'vehicle_id': vehicle_id,
            'driver_id': driver_id,
            'status': 'recall_in_progress',
            'current_lat': vehicle.current_lat,
            'current_lng': vehicle.current_lng,
            'target_lat': target_lat,
            'target_lng': target_lng,
            'distance_km': round(distance_km, 2),
            'eta_minutes': eta_minutes,
            'started_at': vehicle.recall_started_at.isoformat(),
            'message': f'召回已開始，車輛將在約 {eta_minutes} 分鐘後到達'
        }

    async def complete_recall(
        self,
        vehicle_id: str,
        final_lat: Optional[float] = None,
        final_lng: Optional[float] = None
    ) -> Dict[str, Any]:
        """
        完成召回

        Args:
            vehicle_id: 車輛 ID
            final_lat: 最終位置緯度（可選，默認使用目標位置）
            final_lng: 最終位置經度（可選，默認使用目標位置）

        Returns:
            完成信息字典

        Raises:
            ValueError: 驗證失敗時
        """
        logger.info(f"🏁 完成車輛 {vehicle_id} 的召回")

        # 1. 查詢車輛
        vehicle_result = await self.db.execute(
            select(Vehicle).where(Vehicle.vehicle_id == vehicle_id)
        )
        vehicle = vehicle_result.scalar_one_or_none()
        if not vehicle:
            raise ValueError(f"車輛 {vehicle_id} 不存在")

        # 2. 檢查是否在召回中
        if vehicle.recall_started_at is None:
            raise ValueError(f"車輛 {vehicle_id} 未在召回中")

        # 3. 更新車輛位置和狀態
        if final_lat is not None and final_lng is not None:
            vehicle.current_lat = final_lat
            vehicle.current_lng = final_lng
        elif vehicle.recall_target_lat is not None and vehicle.recall_target_lng is not None:
            # 使用目標位置作為最終位置
            vehicle.current_lat = vehicle.recall_target_lat
            vehicle.current_lng = vehicle.recall_target_lng

        # 4. 清除召回狀態，恢復為可用
        recall_duration = (datetime.utcnow() - vehicle.recall_started_at).total_seconds()
        vehicle.status = 'available'
        vehicle.recall_target_lat = None
        vehicle.recall_target_lng = None
        vehicle.recall_started_at = None

        await self.db.commit()
        await self.db.refresh(vehicle)

        logger.info(
            f"✅ 召回完成: 車輛 {vehicle_id} 已到達目標位置 "
            f"({vehicle.current_lat}, {vehicle.current_lng})，"
            f"耗時 {int(recall_duration)} 秒"
        )

        return {
            'vehicle_id': vehicle_id,
            'status': 'available',
            'current_lat': vehicle.current_lat,
            'current_lng': vehicle.current_lng,
            'duration_seconds': int(recall_duration),
            'message': '召回已完成，車輛現已空閒'
        }

    async def cancel_recall(self, vehicle_id: str) -> Dict[str, Any]:
        """
        取消召回

        Args:
            vehicle_id: 車輛 ID

        Returns:
            取消信息字典

        Raises:
            ValueError: 驗證失敗時
        """
        logger.info(f"❌ 取消車輛 {vehicle_id} 的召回")

        # 1. 查詢車輛
        vehicle_result = await self.db.execute(
            select(Vehicle).where(Vehicle.vehicle_id == vehicle_id)
        )
        vehicle = vehicle_result.scalar_one_or_none()
        if not vehicle:
            raise ValueError(f"車輛 {vehicle_id} 不存在")

        # 2. 檢查是否在召回中
        if vehicle.recall_started_at is None:
            raise ValueError(f"車輛 {vehicle_id} 未在召回中")

        # 3. 清除召回狀態，恢復為可用
        vehicle.status = 'available'
        vehicle.recall_target_lat = None
        vehicle.recall_target_lng = None
        vehicle.recall_started_at = None

        await self.db.commit()
        await self.db.refresh(vehicle)

        logger.info(f"✅ 召回已取消: 車輛 {vehicle_id} 恢復空閒狀態")

        return {
            'vehicle_id': vehicle_id,
            'status': 'available',
            'current_lat': vehicle.current_lat,
            'current_lng': vehicle.current_lng,
            'message': '召回已取消，車輛保持在當前位置'
        }

    async def get_recall_status(self, vehicle_id: str) -> Dict[str, Any]:
        """
        獲取召回狀態

        Args:
            vehicle_id: 車輛 ID

        Returns:
            召回狀態字典

        Raises:
            ValueError: 車輛不存在時
        """
        vehicle_result = await self.db.execute(
            select(Vehicle).where(Vehicle.vehicle_id == vehicle_id)
        )
        vehicle = vehicle_result.scalar_one_or_none()
        if not vehicle:
            raise ValueError(f"車輛 {vehicle_id} 不存在")

        if vehicle.recall_started_at is None:
            return {
                'vehicle_id': vehicle_id,
                'is_recalling': False,
                'status': vehicle.status,
                'current_lat': vehicle.current_lat,
                'current_lng': vehicle.current_lng
            }

        # 計算剩餘距離
        remaining_distance = self.location_service.haversine_km(
            vehicle.current_lat,
            vehicle.current_lng,
            vehicle.recall_target_lat,
            vehicle.recall_target_lng
        )

        # 計算已耗時
        elapsed_seconds = (datetime.utcnow() - vehicle.recall_started_at).total_seconds()

        return {
            'vehicle_id': vehicle_id,
            'is_recalling': True,
            'status': vehicle.status,
            'current_lat': vehicle.current_lat,
            'current_lng': vehicle.current_lng,
            'target_lat': vehicle.recall_target_lat,
            'target_lng': vehicle.recall_target_lng,
            'remaining_distance_km': round(remaining_distance, 2),
            'elapsed_seconds': int(elapsed_seconds),
            'started_at': vehicle.recall_started_at.isoformat()
        }

    async def get_driver_vehicles_for_recall(self, driver_id: int) -> list[Dict[str, Any]]:
        """
        獲取司機可召回的車輛列表

        Args:
            driver_id: 司機 ID

        Returns:
            可召回車輛列表
        """
        logger.info(f"🔍 查詢司機 {driver_id} 的可召回車輛")

        result = await self.db.execute(
            select(Vehicle).where(
                and_(
                    Vehicle.owner_id == driver_id,
                    # 包含：空閒、離線、以及召回中的車輛（狀態為 on_trip 且有 recall_started_at）
                    (
                        Vehicle.status.in_(['available', 'offline']) |
                        (Vehicle.recall_started_at.isnot(None))
                    )
                )
            )
        )
        vehicles = result.scalars().all()

        logger.info(f"📊 找到 {len(vehicles)} 輛可召回車輛")
        for v in vehicles:
            logger.info(f"  - {v.vehicle_id} ({v.plate_number}): status={v.status}, is_active={v.is_active}")

        vehicle_list = [
            {
                'vehicle_id': v.vehicle_id,
                'vehicle_type': v.vehicle_type,
                'license_plate': v.plate_number,  # 修正：使用 plate_number 而非 license_plate
                'current_lat': v.current_lat,
                'current_lng': v.current_lng,
                'status': v.status,
                'is_recalling': v.recall_started_at is not None,
                'recall_target_lat': v.recall_target_lat,
                'recall_target_lng': v.recall_target_lng
            }
            for v in vehicles
        ]

        logger.info(f"✅ 返回 {len(vehicle_list)} 輛車輛到前端")
        return vehicle_list
