# backend/app/services/pricing_service.py

"""
費用計算服務
複用隊友的定價邏輯
"""

class PricingService:
    """費用計算服務"""
    
    # 複用隊友的費率設定
    BASE_FARE = 50  # 起跳價
    PER_KM = 10     # 每公里單價
    
    @classmethod
    def calculate_fare(cls, distance_km: float) -> float:
        """
        計算車費
        完全複用隊友的邏輯
        """
        if distance_km is None or distance_km <= 0:
            return cls.BASE_FARE
        
        fare = cls.BASE_FARE + (cls.PER_KM * distance_km)
        return round(fare, 0)  # 四捨五入到整數
    
    @classmethod
    def calculate_service_fee(cls, fare: float, rate: float = 0.05) -> float:
        """計算服務費（5%）"""
        return round(fare * rate, 2)
    
    @classmethod
    def calculate_total_amount(cls, distance_km: float, service_fee_rate: float = 0.05) -> dict:
        """計算總金額"""
        fare = cls.calculate_fare(distance_km)
        service_fee = cls.calculate_service_fee(fare, service_fee_rate)
        total = fare + service_fee
        
        return {
            "distance_km": distance_km,
            "base_fare": cls.BASE_FARE,
            "per_km_rate": cls.PER_KM,
            "fare": fare,
            "service_fee": service_fee,
            "total_amount": total
        }
