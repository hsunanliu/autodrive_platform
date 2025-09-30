# backend/app/services/location_service.py
"""
地理位置相關服務
包含距離計算、隨機位置生成等功能
"""

import math
import random
import hashlib
from typing import Tuple

class LocationService:
    """地理位置服務類"""
    
    @staticmethod
    def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
        """
        使用 Haversine 公式計算兩點間的球面距離 (公里)
        
        Args:
            lat1, lng1: 第一個點的緯度、經度
            lat2, lng2: 第二個點的緯度、經度
            
        Returns:
            距離 (公里)
        """
        # 轉換為弧度
        lat1, lng1, lat2, lng2 = map(math.radians, [lat1, lng1, lat2, lng2])
        
        # Haversine 公式
        dlat = lat2 - lat1
        dlng = lng2 - lng1
        a = math.sin(dlat/2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlng/2)**2
        c = 2 * math.asin(math.sqrt(a))
        
        # 地球半徑 (公里)
        earth_radius_km = 6371
        
        return earth_radius_km * c
    
    @staticmethod
    def random_point_near(
        center_lat: float, 
        center_lng: float, 
        radius_km: float = 5.0,
        seed: str = None
    ) -> Tuple[float, float]:
        """
        在指定中心點附近生成隨機座標點
        
        Args:
            center_lat: 中心點緯度
            center_lng: 中心點經度
            radius_km: 半徑 (公里)
            seed: 隨機種子 (用於確保相同輸入產生相同結果)
            
        Returns:
            (緯度, 經度) 元組
        """
        # 如果提供 seed，使用確定性隨機
        if seed:
            # 使用 MD5 hash 作為種子，確保分佈均勻
            hash_obj = hashlib.md5(seed.encode())
            seed_int = int(hash_obj.hexdigest()[:8], 16)
            rng = random.Random(seed_int)
        else:
            rng = random
        
        # 生成隨機距離和角度
        # 使用平方根確保均勻分佈 (避免中心聚集)
        distance_km = radius_km * math.sqrt(rng.random())
        angle_rad = 2 * math.pi * rng.random()
        
        # 轉換為緯度經度偏移
        # 1度緯度 ≈ 111 公里
        lat_offset = (distance_km / 111.0) * math.cos(angle_rad)
        
        # 經度偏移需要考慮緯度的影響
        lng_offset = (distance_km / 111.0) * math.sin(angle_rad) / math.cos(math.radians(center_lat))
        
        new_lat = center_lat + lat_offset
        new_lng = center_lng + lng_offset
        
        return new_lat, new_lng
    
    @staticmethod
    def is_within_radius(
        center_lat: float,
        center_lng: float,
        point_lat: float,
        point_lng: float,
        radius_km: float
    ) -> bool:
        """
        檢查點是否在指定半徑內
        
        Args:
            center_lat, center_lng: 中心點座標
            point_lat, point_lng: 檢查點座標
            radius_km: 半徑 (公里)
            
        Returns:
            是否在半徑內
        """
        distance = LocationService.haversine_km(center_lat, center_lng, point_lat, point_lng)
        return distance <= radius_km
    
    @staticmethod
    def estimate_travel_time_minutes(distance_km: float, speed_kmh: float = 30.0) -> int:
        """
        估算行駛時間
        
        Args:
            distance_km: 距離 (公里)
            speed_kmh: 平均速度 (公里/小時)，預設 30 km/h (城市道路)
            
        Returns:
            預估時間 (分鐘)
        """
        if distance_km <= 0:
            return 0
        
        time_hours = distance_km / speed_kmh
        time_minutes = time_hours * 60
        
        # 最少 1 分鐘，四捨五入
        return max(1, round(time_minutes))
    
    @staticmethod
    def format_distance(distance_km: float) -> str:
        """
        格式化距離顯示
        
        Args:
            distance_km: 距離 (公里)
            
        Returns:
            格式化的距離字串
        """
        if distance_km < 1:
            return f"{int(distance_km * 1000)}m"
        else:
            return f"{distance_km:.1f}km"
    
    @staticmethod
    def validate_coordinates(lat: float, lng: float) -> bool:
        """
        驗證座標有效性
        
        Args:
            lat: 緯度
            lng: 經度
            
        Returns:
            座標是否有效
        """
        return -90 <= lat <= 90 and -180 <= lng <= 180