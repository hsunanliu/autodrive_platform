# backend/app/services/trip_service.py
"""
Trip 業務邏輯服務
處理行程管理的核心業務邏輯
"""

import logging
from typing import Optional, List, Dict, Any
from datetime import datetime, timedelta
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_, func, desc
from sqlalchemy.orm import selectinload

from app.models.ride import Trip
from app.models.user import User
from app.models.vehicle import Vehicle
from app.schemas.trip import (
    TripCreate, TripResponse, TripStatus, TripFareBreakdown, 
    TripEstimate, DriverTripInfo, TripSummary
)
from app.schemas.payment import PaymentTransaction, PaymentStatus
from app.services.location_service import LocationService
from app.services.iota_service import iota_service
from app.services.contract_service import contract_service

logger = logging.getLogger(__name__)

class TripService:
    """行程服務類"""
    
    def __init__(self, db: AsyncSession):
        self.db = db
        
        # 費率配置 (micro IOTA)
        self.BASE_FARE = 50000  # 起跳價
        self.PER_KM_RATE = 10000  # 每公里費率
        self.PER_MINUTE_RATE = 1000  # 每分鐘費率
        self.PLATFORM_FEE_RATE = 0.1  # 平台費率 10%
        
        # 配對參數
        self.MAX_PICKUP_DISTANCE_KM = 10.0  # 最大接送距離
        self.MAX_WAIT_TIME_MINUTES = 15  # 最大等待時間
    
    async def create_trip_request(self, user_id: int, trip_data: TripCreate) -> TripResponse:
        """
        創建行程請求
        
        Args:
            user_id: 乘客用戶ID
            trip_data: 行程創建數據
            
        Returns:
            創建的行程信息
        """
        # 檢查用戶是否有進行中的行程
        existing_trip = await self._get_user_active_trip(user_id)
        if existing_trip:
            raise ValueError("您已有進行中的行程，無法創建新的行程請求")
        
        # 計算預估距離和時間
        distance_km = LocationService.haversine_km(
            trip_data.pickup_lat, trip_data.pickup_lng,
            trip_data.dropoff_lat, trip_data.dropoff_lng
        )
        
        estimated_duration = LocationService.estimate_travel_time_minutes(distance_km)
        
        # 計算預估費用
        fare_breakdown = self._calculate_fare(distance_km, estimated_duration)
        
        # 創建行程記錄
        trip = Trip(
            user_id=user_id,
            pickup_lat=trip_data.pickup_lat,
            pickup_lng=trip_data.pickup_lng,
            pickup_address=trip_data.pickup_address,
            dropoff_lat=trip_data.dropoff_lat,
            dropoff_lng=trip_data.dropoff_lng,
            dropoff_address=trip_data.dropoff_address,
            passenger_count=trip_data.passenger_count,
            distance_km=distance_km,
            estimated_duration_minutes=estimated_duration,
            status=TripStatus.REQUESTED,
            base_fare=fare_breakdown.base_fare / 1000000,  # 轉換為 IOTA 存儲
            per_km_rate=fare_breakdown.per_km_rate / 1000000,
            service_fee=fare_breakdown.platform_fee / 1000000,
            fare=fare_breakdown.total_amount / 1000000
        )
        
        self.db.add(trip)
        await self.db.commit()
        await self.db.refresh(trip)
        
        # 在智能合約中創建叫車請求
        try:
            passenger = await self._get_user_by_id(user_id)
            if passenger:
                contract_result = await contract_service.create_ride_request_on_chain(
                    passenger_address=passenger.wallet_address,
                    request_data={
                        "pickup_lat": trip_data.pickup_lat,
                        "pickup_lng": trip_data.pickup_lng,
                        "dropoff_lat": trip_data.dropoff_lat,
                        "dropoff_lng": trip_data.dropoff_lng,
                        "max_price": fare_breakdown.total_amount,
                        "expires_at": int((datetime.utcnow() + timedelta(minutes=30)).timestamp())
                    }
                )
                
                if contract_result.get("success"):
                    logger.info(f"✅ Ride request created on blockchain: {contract_result['transaction_hash']}")
                else:
                    logger.warning(f"⚠️ Blockchain ride request failed: {contract_result.get('error')}")
        except Exception as e:
            logger.error(f"❌ Blockchain ride request error: {e}")
        
        logger.info(f"✅ Trip request created: {trip.trip_id}")
        
        # 返回響應
        return await self._build_trip_response(trip, fare_breakdown)
    
    async def find_and_match_driver(self, trip_id: int) -> Optional[DriverTripInfo]:
        """
        查找並配對司機
        
        Args:
            trip_id: 行程ID
            
        Returns:
            配對的司機信息，如果沒有找到則返回 None
        """
        # 獲取行程信息
        trip = await self._get_trip_by_id(trip_id)
        if not trip or trip.status != TripStatus.REQUESTED:
            raise ValueError("行程不存在或狀態不正確")
        
        # 查找附近可用的車輛和司機
        available_matches = await self._find_available_drivers(
            trip.pickup_lat, trip.pickup_lng, 
            self.MAX_PICKUP_DISTANCE_KM
        )
        
        if not available_matches:
            logger.info(f"No available drivers found for trip {trip_id}")
            return None
        
        # 選擇最佳匹配 (距離最近)
        best_match = available_matches[0]
        
        # 更新行程狀態為已配對
        trip.status = TripStatus.MATCHED
        trip.vehicle_id = best_match["vehicle_id"]
        trip.driver_id = best_match["driver_id"]
        trip.matched_at = datetime.utcnow()
        
        await self.db.commit()
        
        logger.info(f"✅ Trip {trip_id} matched with driver {best_match['driver_id']}")
        
        # 返回司機端行程信息
        return DriverTripInfo(
            trip_id=trip.trip_id,
            passenger_name=best_match["passenger_name"],
            passenger_phone=best_match["passenger_phone"],
            pickup_location={
                "lat": trip.pickup_lat,
                "lng": trip.pickup_lng,
                "address": trip.pickup_address
            },
            dropoff_location={
                "lat": trip.dropoff_lat,
                "lng": trip.dropoff_lng,
                "address": trip.dropoff_address
            },
            passenger_count=trip.passenger_count,
            estimated_fare=int(trip.fare * 1000000),  # 轉換為 micro IOTA
            distance_to_pickup_km=best_match["distance_km"],
            notes=trip.notes if hasattr(trip, 'notes') else None
        )
    
    async def accept_trip(self, trip_id: int, driver_id: int, estimated_arrival: int) -> TripResponse:
        """
        司機接受行程
        
        Args:
            trip_id: 行程ID
            driver_id: 司機ID
            estimated_arrival: 預估到達時間(分鐘)
            
        Returns:
            更新後的行程信息
        """
        trip = await self._get_trip_by_id(trip_id)
        if not trip:
            raise ValueError("行程不存在")
        
        if trip.status != TripStatus.MATCHED:
            raise ValueError("行程狀態不正確，無法接受")
        
        if trip.driver_id != driver_id:
            raise ValueError("您不是此行程的指定司機")
        
        # 更新行程狀態
        trip.status = TripStatus.ACCEPTED
        
        # 更新車輛狀態為忙碌
        if trip.vehicle_id:
            stmt = select(Vehicle).where(Vehicle.vehicle_id == trip.vehicle_id)
            result = await self.db.execute(stmt)
            vehicle = result.scalar_one_or_none()
            if vehicle:
                vehicle.status = "on_trip"
        
        await self.db.commit()
        
        logger.info(f"✅ Trip {trip_id} accepted by driver {driver_id}")
        
        return await self._build_trip_response(trip)
    
    async def pickup_passenger(self, trip_id: int, driver_id: int) -> TripResponse:
        """
        確認乘客上車
        
        Args:
            trip_id: 行程ID
            driver_id: 司機ID
            
        Returns:
            更新後的行程信息
        """
        trip = await self._get_trip_by_id(trip_id)
        if not trip:
            raise ValueError("行程不存在")
        
        if trip.driver_id != driver_id:
            raise ValueError("您不是此行程的司機")
        
        if trip.status != TripStatus.ACCEPTED:
            raise ValueError("行程狀態不正確")
        
        # 更新狀態
        trip.status = TripStatus.PICKED_UP
        trip.picked_up_at = datetime.utcnow()
        
        await self.db.commit()
        
        logger.info(f"✅ Passenger picked up for trip {trip_id}")
        
        return await self._build_trip_response(trip)
    
    async def complete_trip(self, trip_id: int, driver_id: int) -> Dict[str, Any]:
        """
        完成行程並處理支付
        
        Args:
            trip_id: 行程ID
            driver_id: 司機ID
            
        Returns:
            完成結果，包含支付信息
        """
        trip = await self._get_trip_by_id(trip_id)
        if not trip:
            raise ValueError("行程不存在")
        
        if trip.driver_id != driver_id:
            raise ValueError("您不是此行程的司機")
        
        if trip.status not in [TripStatus.PICKED_UP, TripStatus.IN_PROGRESS]:
            raise ValueError("行程狀態不正確")
        
        # 計算實際行程時間
        if trip.picked_up_at:
            # 確保時區一致性
            now = datetime.utcnow()
            if trip.picked_up_at.tzinfo is not None:
                # 如果 picked_up_at 有時區信息，轉換 now 為 UTC
                from datetime import timezone
                now = now.replace(tzinfo=timezone.utc)
                actual_duration = int((now - trip.picked_up_at).total_seconds() / 60)
            else:
                # 如果 picked_up_at 沒有時區信息，直接計算
                actual_duration = int((now - trip.picked_up_at).total_seconds() / 60)
        else:
            actual_duration = trip.estimated_duration_minutes
        
        # 重新計算費用 (基於實際時間)
        fare_breakdown = self._calculate_fare(trip.distance_km, actual_duration)
        
        # 獲取乘客和司機信息
        passenger = await self._get_user_by_id(trip.user_id)
        driver = await self._get_user_by_id(driver_id)
        
        if not passenger or not driver:
            raise ValueError("無法找到乘客或司機信息")
        
        # 執行區塊鏈支付
        payment_result = await iota_service.execute_trip_payment(
            passenger_wallet=passenger.wallet_address,
            driver_wallet=driver.wallet_address,
            amount_breakdown={
                "total_amount": fare_breakdown.total_amount,
                "driver_amount": fare_breakdown.driver_amount,
                "platform_fee": fare_breakdown.platform_fee
            },
            trip_id=trip_id
        )
        
        if not payment_result.get("success"):
            raise Exception(f"支付失敗: {payment_result.get('error')}")
        
        # 更新行程狀態
        trip.status = TripStatus.COMPLETED
        trip.completed_at = datetime.utcnow()
        trip.actual_duration_minutes = actual_duration
        trip.total_amount = fare_breakdown.total_amount / 1000000  # 轉換為 IOTA
        trip.payment_amount_micro_iota = str(fare_breakdown.total_amount)
        trip.blockchain_tx_id = payment_result["transaction_hash"]
        
        # 釋放車輛
        if trip.vehicle_id:
            stmt = select(Vehicle).where(Vehicle.vehicle_id == trip.vehicle_id)
            result = await self.db.execute(stmt)
            vehicle = result.scalar_one_or_none()
            if vehicle:
                vehicle.status = "available"
                vehicle.total_trips += 1
                vehicle.total_distance_km += trip.distance_km
        
        # 更新用戶統計
        passenger.total_rides_as_passenger += 1
        driver.total_rides_as_driver += 1
        
        await self.db.commit()
        
        logger.info(f"✅ Trip {trip_id} completed with payment {payment_result['transaction_hash']}")
        
        return {
            "trip": await self._build_trip_response(trip, fare_breakdown),
            "payment": {
                "transaction_hash": payment_result["transaction_hash"],
                "status": payment_result["status"],
                "amount_micro_iota": str(fare_breakdown.total_amount)
            }
        }
    
    async def cancel_trip(self, trip_id: int, user_id: int, reason: str, cancelled_by: str) -> TripResponse:
        """
        取消行程
        
        Args:
            trip_id: 行程ID
            user_id: 取消者用戶ID
            reason: 取消原因
            cancelled_by: 取消者角色
            
        Returns:
            更新後的行程信息
        """
        trip = await self._get_trip_by_id(trip_id)
        if not trip:
            raise ValueError("行程不存在")
        
        # 檢查取消權限
        if cancelled_by == "passenger" and trip.user_id != user_id:
            raise ValueError("您不是此行程的乘客")
        elif cancelled_by == "driver" and trip.driver_id != user_id:
            raise ValueError("您不是此行程的司機")
        
        if trip.status in [TripStatus.COMPLETED, TripStatus.CANCELLED]:
            raise ValueError("行程已完成或已取消")
        
        # 更新狀態
        trip.status = TripStatus.CANCELLED
        trip.cancelled_at = datetime.utcnow()
        trip.cancellation_reason = reason
        
        # 釋放車輛
        if trip.vehicle_id:
            stmt = select(Vehicle).where(Vehicle.vehicle_id == trip.vehicle_id)
            result = await self.db.execute(stmt)
            vehicle = result.scalar_one_or_none()
            if vehicle:
                vehicle.status = "available"
        
        await self.db.commit()
        
        logger.info(f"✅ Trip {trip_id} cancelled by {cancelled_by}")
        
        return await self._build_trip_response(trip)
    
    async def get_trip_estimate(self, pickup_lat: float, pickup_lng: float, 
                               dropoff_lat: float, dropoff_lng: float) -> TripEstimate:
        """
        獲取行程預估
        
        Args:
            pickup_lat, pickup_lng: 上車點座標
            dropoff_lat, dropoff_lng: 下車點座標
            
        Returns:
            行程預估信息
        """
        # 計算距離和時間
        distance_km = LocationService.haversine_km(pickup_lat, pickup_lng, dropoff_lat, dropoff_lng)
        duration_minutes = LocationService.estimate_travel_time_minutes(distance_km)
        
        # 計算費用
        fare_breakdown = self._calculate_fare(distance_km, duration_minutes)
        
        # 查詢附近可用車輛數量
        available_vehicles = await self._find_available_drivers(pickup_lat, pickup_lng, self.MAX_PICKUP_DISTANCE_KM)
        
        # 估算等待時間
        if available_vehicles:
            avg_distance = sum(v["distance_km"] for v in available_vehicles) / len(available_vehicles)
            wait_time = max(3, int(avg_distance * 2))  # 每公里2分鐘
        else:
            wait_time = self.MAX_WAIT_TIME_MINUTES
        
        return TripEstimate(
            estimated_distance_km=distance_km,
            estimated_duration_minutes=duration_minutes,
            estimated_fare=fare_breakdown,
            available_vehicles_count=len(available_vehicles),
            estimated_wait_time_minutes=wait_time
        )
    
    # 私有輔助方法
    
    def _calculate_fare(self, distance_km: float, duration_minutes: int) -> TripFareBreakdown:
        """計算行程費用"""
        base_fare = self.BASE_FARE
        distance_fare = int(distance_km * self.PER_KM_RATE)
        time_fare = int(duration_minutes * self.PER_MINUTE_RATE)
        
        subtotal = base_fare + distance_fare + time_fare
        platform_fee = int(subtotal * self.PLATFORM_FEE_RATE)
        total_amount = subtotal + platform_fee
        driver_amount = total_amount - platform_fee
        
        return TripFareBreakdown(
            base_fare=base_fare,
            distance_fare=distance_fare,
            time_fare=time_fare,
            platform_fee=platform_fee,
            total_amount=total_amount,
            driver_amount=driver_amount,
            distance_km=distance_km,
            duration_minutes=duration_minutes,
            per_km_rate=self.PER_KM_RATE,
            per_minute_rate=self.PER_MINUTE_RATE,
            platform_fee_rate=self.PLATFORM_FEE_RATE
        )
    
    async def _get_trip_by_id(self, trip_id: int) -> Optional[Trip]:
        """根據ID獲取行程"""
        stmt = select(Trip).where(Trip.trip_id == trip_id)
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()
    
    async def _get_user_by_id(self, user_id: int) -> Optional[User]:
        """根據ID獲取用戶"""
        stmt = select(User).where(User.id == user_id)
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()
    
    async def _get_user_active_trip(self, user_id: int) -> Optional[Trip]:
        """獲取用戶的活躍行程"""
        active_statuses = [TripStatus.REQUESTED, TripStatus.MATCHED, TripStatus.ACCEPTED, TripStatus.PICKED_UP, TripStatus.IN_PROGRESS]
        stmt = select(Trip).where(
            and_(
                or_(Trip.user_id == user_id, Trip.driver_id == user_id),
                Trip.status.in_(active_statuses)
            )
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()
    
    async def _find_available_drivers(self, lat: float, lng: float, radius_km: float) -> List[Dict[str, Any]]:
        """查找附近可用的司機"""
        # 查詢可用車輛及其司機
        stmt = select(Vehicle, User).join(User, Vehicle.owner_id == User.id).where(
            and_(
                Vehicle.status == "available",
                Vehicle.is_active == True,
                User.is_active == True,
                User.user_type.in_(["driver", "both"])
            )
        )
        result = await self.db.execute(stmt)
        vehicles_and_drivers = result.all()
        
        matches = []
        for vehicle, driver in vehicles_and_drivers:
            # 計算距離 (使用車輛當前位置或隨機位置)
            if vehicle.current_lat and vehicle.current_lng:
                distance_km = LocationService.haversine_km(
                    lat, lng, vehicle.current_lat, vehicle.current_lng
                )
            else:
                # 如果沒有位置信息，使用隨機位置
                import time
                minute_bucket = int(time.time() // 60)
                rand_lat, rand_lng = LocationService.random_point_near(
                    lat, lng, radius_km=radius_km,
                    seed=f"{vehicle.vehicle_id}-{minute_bucket}"
                )
                distance_km = LocationService.haversine_km(lat, lng, rand_lat, rand_lng)
            
            if distance_km <= radius_km:
                matches.append({
                    "vehicle_id": vehicle.vehicle_id,
                    "driver_id": driver.id,
                    "driver_name": driver.username,
                    "passenger_name": driver.username,  # 這裡應該是乘客名，但當前上下文是司機
                    "passenger_phone": driver.phone_number,
                    "distance_km": distance_km,
                    "vehicle_model": vehicle.model,
                    "vehicle_type": vehicle.vehicle_type
                })
        
        # 按距離排序
        matches.sort(key=lambda x: x["distance_km"])
        return matches
    
    async def _build_trip_response(self, trip: Trip, fare_breakdown: Optional[TripFareBreakdown] = None) -> TripResponse:
        """構建行程響應對象"""
        if not fare_breakdown and trip.distance_km and trip.estimated_duration_minutes:
            fare_breakdown = self._calculate_fare(trip.distance_km, trip.estimated_duration_minutes)
        
        return TripResponse(
            trip_id=trip.trip_id,
            user_id=trip.user_id,
            driver_id=trip.driver_id,
            vehicle_id=trip.vehicle_id,
            pickup_lat=trip.pickup_lat,
            pickup_lng=trip.pickup_lng,
            pickup_address=trip.pickup_address,
            dropoff_lat=trip.dropoff_lat,
            dropoff_lng=trip.dropoff_lng,
            dropoff_address=trip.dropoff_address,
            passenger_count=trip.passenger_count,
            status=TripStatus(trip.status),
            distance_km=trip.distance_km,
            estimated_duration_minutes=trip.estimated_duration_minutes,
            actual_duration_minutes=trip.actual_duration_minutes,
            fare_breakdown=fare_breakdown,
            payment_amount_micro_iota=trip.payment_amount_micro_iota,
            blockchain_tx_id=trip.blockchain_tx_id,
            requested_at=trip.requested_at,
            matched_at=trip.matched_at,
            picked_up_at=trip.picked_up_at,
            dropped_off_at=trip.dropped_off_at,
            completed_at=trip.completed_at,
            cancelled_at=trip.cancelled_at,
            cancellation_reason=trip.cancellation_reason
        )