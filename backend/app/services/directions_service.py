"""
Google Maps Directions API Service
用於獲取真實道路路線
"""
import os
import logging
import aiohttp
from typing import List, Tuple, Optional
from dataclasses import dataclass

logger = logging.getLogger(__name__)


@dataclass
class RoutePoint:
    """路線點"""
    lat: float
    lng: float


class DirectionsService:
    """Google Maps Directions API 服務"""

    def __init__(self):
        # 後端由伺服器 IP 呼叫，不帶 iOS bundle header；若前端那把 key 是「iOS App 限制」，
        # 後端會被 REQUEST_DENIED。可另設 BACKEND_GOOGLE_MAPS_API_KEY（以伺服器 IP 限制）供後端專用；
        # 未設則沿用 GOOGLE_MAPS_API_KEY。
        self.api_key = os.getenv('BACKEND_GOOGLE_MAPS_API_KEY') or os.getenv('GOOGLE_MAPS_API_KEY', '')
        if not self.api_key:
            logger.warning("⚠️ 未設置 Google Maps API key，將使用直線路線")
        self.base_url = "https://maps.googleapis.com/maps/api/directions/json"
        # 避免每次請求都噴同一則錯誤：REQUEST_DENIED 只提醒一次
        self._denied_warned = False

    async def get_route(
        self,
        origin_lat: float,
        origin_lng: float,
        dest_lat: float,
        dest_lng: float,
        waypoints: Optional[List[Tuple[float, float]]] = None
    ) -> List[RoutePoint]:
        """
        獲取從起點到終點的路線（支持中繼點）

        Args:
            origin_lat: 起點緯度
            origin_lng: 起點經度
            dest_lat: 終點緯度
            dest_lng: 終點經度
            waypoints: 中繼點列表 [(lat1, lng1), (lat2, lng2), ...]

        Returns:
            路線點列表
        """
        # 如果沒有 API key，返回直線路線
        if not self.api_key:
            logger.info("📍 未配置 Google Maps API，使用直線路線")
            points = [RoutePoint(lat=origin_lat, lng=origin_lng)]
            if waypoints:
                points.extend([RoutePoint(lat=lat, lng=lng) for lat, lng in waypoints])
            points.append(RoutePoint(lat=dest_lat, lng=dest_lng))
            return points

        try:
            params = {
                'origin': f"{origin_lat},{origin_lng}",
                'destination': f"{dest_lat},{dest_lng}",
                'mode': 'driving',
                'language': 'zh-TW',  # 繁體中文
                'key': self.api_key
            }

            # 添加中繼點（如果有）
            if waypoints and len(waypoints) > 0:
                # 格式: "optimize:true|lat1,lng1|lat2,lng2"
                # optimize:true 會自動優化停靠順序
                waypoint_str = "optimize:true|" + "|".join([f"{lat},{lng}" for lat, lng in waypoints])
                params['waypoints'] = waypoint_str
                logger.info(f"🗺️  包含 {len(waypoints)} 個中繼點")

            logger.info(f"🗺️ 調用 Google Directions API: {params['origin']} -> {params['destination']}")

            async with aiohttp.ClientSession() as session:
                async with session.get(self.base_url, params=params) as response:
                    if response.status != 200:
                        logger.error(f"❌ Google Directions API 錯誤: {response.status}")
                        return self._fallback_route(origin_lat, origin_lng, dest_lat, dest_lng, waypoints)

                    data = await response.json()

                    status = data.get('status')
                    if status != 'OK':
                        if status == 'REQUEST_DENIED':
                            # 多半是 key 被限制成 iOS App，後端（伺服器 IP）無法使用。
                            # 這是可預期的設定情境，直線 fallback 可承接；只提醒一次避免洗版。
                            if not self._denied_warned:
                                logger.warning(
                                    "⚠️ Directions REQUEST_DENIED：後端這把 key 可能被限制為 iOS App。"
                                    "後端改用直線路線；如需真實路線，請設 BACKEND_GOOGLE_MAPS_API_KEY（伺服器 IP 限制）。"
                                    f" 訊息：{data.get('error_message', '')}"
                                )
                                self._denied_warned = True
                        else:
                            logger.error(f"❌ Google Directions API 狀態: {status}")
                        return self._fallback_route(origin_lat, origin_lng, dest_lat, dest_lng, waypoints)

                    # 解析路線
                    route_points = self._parse_route(data)
                    logger.info(f"✅ 獲取到 {len(route_points)} 個路線點")
                    return route_points

        except Exception as e:
            logger.error(f"❌ 獲取路線失敗: {e}")
            return self._fallback_route(origin_lat, origin_lng, dest_lat, dest_lng)

    def _parse_route(self, data: dict) -> List[RoutePoint]:
        """
        解析 Google Directions API 響應

        Args:
            data: API 響應數據

        Returns:
            路線點列表
        """
        route_points = []

        try:
            routes = data.get('routes', [])
            if not routes:
                return route_points

            # 獲取第一條路線的所有步驟
            legs = routes[0].get('legs', [])
            for leg in legs:
                steps = leg.get('steps', [])
                for step in steps:
                    # 獲取起點
                    start_location = step.get('start_location', {})
                    if start_location:
                        route_points.append(RoutePoint(
                            lat=start_location['lat'],
                            lng=start_location['lng']
                        ))

                    # 獲取終點（最後一個步驟的終點）
                    if step == steps[-1]:
                        end_location = step.get('end_location', {})
                        if end_location:
                            route_points.append(RoutePoint(
                                lat=end_location['lat'],
                                lng=end_location['lng']
                            ))

        except Exception as e:
            logger.error(f"❌ 解析路線失敗: {e}")

        return route_points

    def _fallback_route(
        self,
        origin_lat: float,
        origin_lng: float,
        dest_lat: float,
        dest_lng: float,
        waypoints: Optional[List[Tuple[float, float]]] = None
    ) -> List[RoutePoint]:
        """
        備用路線（直線）

        Returns:
            包含起點、中繼點和終點的列表
        """
        logger.info("📍 使用備用直線路線")
        points = [RoutePoint(lat=origin_lat, lng=origin_lng)]
        if waypoints:
            points.extend([RoutePoint(lat=lat, lng=lng) for lat, lng in waypoints])
        points.append(RoutePoint(lat=dest_lat, lng=dest_lng))
        return points


# 全局單例
directions_service = DirectionsService()
