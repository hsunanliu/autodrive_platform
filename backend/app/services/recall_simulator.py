"""
車輛召回模擬器
模擬車輛從當前位置自動駕駛到目標位置的過程
"""
import asyncio
import logging
from datetime import datetime
from typing import List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.models.vehicle import Vehicle
from app.services.location_service import LocationService
from app.services.directions_service import directions_service, RoutePoint

logger = logging.getLogger(__name__)


class RecallSimulator:
    """召回模擬器 - 模擬車輛自動駕駛到目標位置"""

    def __init__(self):
        self.location_service = LocationService()
        self.active_recalls = {}  # vehicle_id -> {'task': task, 'route': route_points, 'current_idx': idx}

    async def simulate_recall(
        self,
        vehicle_id: str,
        session: AsyncSession,
        route_points: List[RoutePoint]
    ):
        """
        模擬車輛召回過程
        沿著 Google Maps 路線點移動，每5秒更新一次位置

        Args:
            vehicle_id: 車輛ID
            session: 數據庫會話
            route_points: Google Maps 路線點列表
        """
        logger.info(f"🚗 開始模擬車輛 {vehicle_id} 的召回過程，共 {len(route_points)} 個路線點")

        try:
            current_point_idx = 0

            while True:
                # 查詢車輛當前狀態
                result = await session.execute(
                    select(Vehicle).where(Vehicle.vehicle_id == vehicle_id)
                )
                vehicle = result.scalar_one_or_none()

                if not vehicle:
                    logger.error(f"❌ 車輛 {vehicle_id} 不存在")
                    break

                # 檢查召回是否已被取消
                if vehicle.recall_started_at is None:
                    logger.info(f"✅ 車輛 {vehicle_id} 的召回已被取消或完成")
                    break

                # 如果已經到達最後一個路線點
                if current_point_idx >= len(route_points) - 1:
                    logger.info(f"🎯 車輛 {vehicle_id} 已到達目標位置")

                    # 更新車輛位置為最終目標位置
                    final_point = route_points[-1]
                    vehicle.current_lat = final_point.lat
                    vehicle.current_lng = final_point.lng

                    # 清除召回狀態
                    vehicle.status = 'available'
                    vehicle.recall_target_lat = None
                    vehicle.recall_target_lng = None
                    vehicle.recall_started_at = None

                    await session.commit()
                    logger.info(f"✅ 車輛 {vehicle_id} 召回完成")
                    break

                # 獲取當前目標點（下一個路線點）
                target_point = route_points[current_point_idx + 1]

                # 計算到下一個路線點的距離
                distance_to_next = self.location_service.haversine_km(
                    vehicle.current_lat,
                    vehicle.current_lng,
                    target_point.lat,
                    target_point.lng
                )

                # 計算到最終目標的總距離
                distance_to_final = self.location_service.haversine_km(
                    vehicle.current_lat,
                    vehicle.current_lng,
                    vehicle.recall_target_lat,
                    vehicle.recall_target_lng
                )

                logger.info(
                    f"📍 車輛 {vehicle_id} | 路線點 {current_point_idx + 1}/{len(route_points)} | "
                    f"距下一點 {distance_to_next:.3f} km | 距終點 {distance_to_final:.2f} km"
                )

                # 如果已經很接近下一個路線點（小於20米），移動到下一個點
                if distance_to_next < 0.02:
                    current_point_idx += 1
                    vehicle.current_lat = target_point.lat
                    vehicle.current_lng = target_point.lng

                    await session.commit()
                    await session.refresh(vehicle)

                    logger.info(f"✅ 到達路線點 {current_point_idx}/{len(route_points)}")

                    # 繼續下一個循環，不等待
                    continue

                # 計算下一個位置（假設速度30 km/h，每5秒移動約41.67米 = 0.04167 km）
                move_distance_km = min(0.04167, distance_to_next)

                # 計算移動方向（向下一個路線點移動）
                lat_diff = target_point.lat - vehicle.current_lat
                lng_diff = target_point.lng - vehicle.current_lng

                if distance_to_next > 0:
                    # 按比例移動
                    ratio = move_distance_km / distance_to_next
                    vehicle.current_lat += lat_diff * ratio
                    vehicle.current_lng += lng_diff * ratio

                    await session.commit()
                    await session.refresh(vehicle)

                    logger.info(
                        f"🚗 車輛 {vehicle_id} 移動到 "
                        f"({vehicle.current_lat:.6f}, {vehicle.current_lng:.6f})"
                    )

                # 等待5秒再更新位置
                await asyncio.sleep(5)

        except asyncio.CancelledError:
            logger.info(f"⚠️ 車輛 {vehicle_id} 的召回模擬被中斷")
            raise
        except Exception as e:
            logger.error(f"❌ 車輛 {vehicle_id} 召回模擬錯誤: {e}")
        finally:
            # 清理active_recalls
            if vehicle_id in self.active_recalls:
                del self.active_recalls[vehicle_id]

    async def start_simulation(
        self,
        vehicle_id: str,
        session: AsyncSession,
        origin_lat: float,
        origin_lng: float,
        dest_lat: float,
        dest_lng: float
    ):
        """
        啟動召回模擬（異步任務）

        Args:
            vehicle_id: 車輛ID
            session: 數據庫會話
            origin_lat: 起點緯度
            origin_lng: 起點經度
            dest_lat: 終點緯度
            dest_lng: 終點經度
        """
        # 如果已有該車輛的模擬任務，先取消
        if vehicle_id in self.active_recalls:
            self.active_recalls[vehicle_id]['task'].cancel()

        # 獲取路線
        logger.info(f"🗺️ 獲取車輛 {vehicle_id} 的召回路線")
        route_points = await directions_service.get_route(
            origin_lat, origin_lng, dest_lat, dest_lng
        )

        # 創建新的模擬任務
        task = asyncio.create_task(
            self.simulate_recall(vehicle_id, session, route_points)
        )
        self.active_recalls[vehicle_id] = {
            'task': task,
            'route': route_points
        }

        logger.info(f"✅ 車輛 {vehicle_id} 的召回模擬任務已啟動，共 {len(route_points)} 個路線點")

    def stop_simulation(self, vehicle_id: str):
        """
        停止召回模擬

        Args:
            vehicle_id: 車輛ID
        """
        if vehicle_id in self.active_recalls:
            self.active_recalls[vehicle_id]['task'].cancel()
            del self.active_recalls[vehicle_id]
            logger.info(f"⚠️ 車輛 {vehicle_id} 的召回模擬已停止")


# 全局單例
recall_simulator = RecallSimulator()
