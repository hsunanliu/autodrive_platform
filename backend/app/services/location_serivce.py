# backend/app/services/location_service.py

"""
位置計算服務
複用隊友的地理計算邏輯
"""

import math
import random

class LocationService:
    """位置相關服務"""
    
    @staticmethod
    def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
        """
        地球大圓距離計算（公里）
        完全複用隊友的邏輯
        """
        R = 6371.0088
        dlat = math.radians(lat2 - lat1)
        dlng = math.radians(lng2 - lng1)
        a = (math.sin(dlat/2)**2 + 
             math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * 
             math.sin(dlng/2)**2)
        return 2 * R * math.asin(math.sqrt(a))
    
    @staticmethod
    def random_point_near(lat: float, lng: float, radius_km: float = 4.0, seed=None):
        """
        在指定位置附近生成隨機點
        完全複用隊友的邏輯，確保一段時間內結果穩定
        """
        rnd = random.Random(seed)
        dist_km = rnd.uniform(0, radius_km)
        brng = rnd.uniform(0, 2*math.pi)
        
        lat1 = math.radians(lat)
        lng1 = math.radians(lng)
        ang_dist = dist_km / 6371.0088
        
        lat2 = math.asin(
            math.sin(lat1) * math.cos(ang_dist) + 
            math.cos(lat1) * math.sin(ang_dist) * math.cos(brng)
        )
        
        lng2 = lng1 + math.atan2(
            math.sin(brng) * math.sin(ang_dist) * math.cos(lat1),
            math.cos(ang_dist) - math.sin(lat1) * math.sin(lat2)
        )
        
        return math.degrees(lat2), math.degrees(lng2)
