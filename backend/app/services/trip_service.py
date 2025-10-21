# backend/app/services/trip_service.py
"""
Trip 業務邏輯服務 - 重構版
所有配對和行程管理邏輯都在後端，僅在關鍵點調用鏈上合約
"""

import logging
from typing import Optional, List, Dict, Any
from datetime import datetime, timedelta
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_, func, desc

from app.models.ride import Trip
from app.models.user import User
from app.models.vehicle import Vehicle
from app.schemas.trip import (
    TripCreate, TripResponse, TripStatus, TripFareBreakdown, 
    TripEstimate, DriverTripInfo, TripSummary
)
from app.services.location_service import LocationService
from app.services.escrow_service import EscrowService  # 新的託管服務

logger = logging.getLogger(__name__)

class TripService:
    """行程服務 - 業務邏輯完全在後端"""
    
    def __init__(self, db: AsyncSession):
        self.db = db
        self.escrow_service = EscrowService()
        
        # 費率配置 (micro IOTA)
        self.BASE_FARE = 50000  # 起跳價
        self.PER_KM_RATE = 10000  # 每公里費率
        self.PER_MINUTE_RATE = 1000  # 每分鐘費率
        self.PLATFORM_FEE_RATE = 0.1  # 平台費率 10%
        
        # 配對參數
        self.MAX_PICKUP_DISTANCE_KM = 10.0
        self.MAX_WAIT_TIME_MINUTES = 15
    
    # ========================================================================
    # 行程創建 - 純後端邏輯，不調用合約
    # ========================================================================
    
    async def create_trip_request(self, user_id: int, trip_data: TripCreate) -> TripResponse:
        """
        創建行程請求 - 完全在後端處理
        
        變更:
        - ❌ 不再調用 ride_matching 合約
        - ✅ 直接在資料庫創建記錄
        - ✅ 觸發後端配對算法
        """
        # 檢查用戶是否有進行中的行程
        existing_trip = await self._get_user_active_trip(user_id)
        if existing_trip:
            raise ValueError("您已有進行中的行程")
        
        # 計算距離和預估
        distance_km = LocationService.haversine_km(
            trip_data.pickup_lat, trip_data.pickup_lng,
            trip_data.dropoff_lat, trip_data.dropoff_lng
        )
        
        estimated_duration = LocationService.estimate_travel_time_minutes(distance_km)
        fare_breakdown = self._calculate_fare(distance_km, estimated_duration)
        
        # 創建本地行程記錄
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
            base_fare=fare_breakdown.base_fare / 1000000,
            per_km_rate=fare_breakdown.per_km_rate / 1000000,
            service_fee=fare_breakdown.platform_fee / 1000000,
            fare=fare_breakdown.total_amount / 1000000,
            requested_at=datetime.utcnow()
        )
        
        self.db.add(trip)
        await self.db.commit()
        await self.db.refresh(trip)
        
        # 暫時禁用自動配對，讓司機手動接單
        # # 自動觸發配對 (異步，不阻塞)
        # try:
        #     await self.find_and_match_driver(trip.trip_id)
        # except Exception as e:
        #     logger.warning(f"自動配對失敗: {e}")
        
        logger.info(f"✅ 行程創建成功 (後端): {trip.trip_id}")
        return await self._build_trip_response(trip, fare_breakdown)
    
    # ========================================================================
    # 配對邏輯 - 完全在後端
    # ========================================================================
    
    async def find_and_match_driver(self, trip_id: int) -> Optional[DriverTripInfo]:
        """
        配對司機 - 完全在後端執行
        
        變更:
        - ❌ 不調用 confirm_match 合約
        - ✅ 使用後端算法選擇最佳司機
        - ✅ 直接更新資料庫狀態
        """
        trip = await self._get_trip_by_id(trip_id)
        if not trip or trip.status != TripStatus.REQUESTED:
            raise ValueError("行程不存在或狀態不正確")
        
        # 查找附近可用司機
        available_matches = await self._find_available_drivers(
            trip.pickup_lat, trip.pickup_lng, 
            self.MAX_PICKUP_DISTANCE_KM
        )
        
        if not available_matches:
            logger.info(f"未找到可用司機: trip {trip_id}")
            return None
        
        # 選擇最佳匹配 (距離最近)
        best_match = available_matches[0]
        
        # 直接更新資料庫 - 不調用合約
        trip.status = TripStatus.MATCHED
        trip.vehicle_id = best_match["vehicle_id"]
        trip.driver_id = best_match["driver_id"]
        trip.matched_at = datetime.utcnow()
        
        await self.db.commit()
        
        logger.info(f"✅ 配對成功 (後端): trip {trip_id} <- driver {best_match['driver_id']}")
        
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
            estimated_fare=int(trip.fare * 1000000),
            distance_to_pickup_km=best_match["distance_km"],
            notes=None
        )
    
    # ========================================================================
    # 司機接受行程 - 後端 + 鏈上支付鎖定
    # ========================================================================
    
    async def accept_trip(self, trip_id: int, driver_id: int, estimated_arrival: int) -> Dict[str, Any]:
        """
        司機接受行程 - 關鍵變更點
        
        變更:
        - ✅ 更新後端狀態
        - ✅ 準備鏈上支付鎖定交易
        - ⚠️  需要前端調用錢包簽署
        """
        trip = await self._get_trip_by_id(trip_id)
        if not trip:
            raise ValueError("行程不存在")
        
        # 允許從 REQUESTED 或 MATCHED 狀態接單
        if trip.status not in [TripStatus.REQUESTED, TripStatus.MATCHED]:
            raise ValueError("行程狀態不正確")
        
        # 如果是 REQUESTED 狀態，設置司機
        if trip.status == TripStatus.REQUESTED:
            trip.driver_id = driver_id
            # 獲取司機的車輛
            driver_vehicles = await self._get_driver_vehicles(driver_id)
            if driver_vehicles:
                trip.vehicle_id = driver_vehicles[0].vehicle_id
        elif trip.driver_id != driver_id:
            raise ValueError("您不是此行程的司機")
        
        # 獲取乘客和司機資訊
        passenger = await self._get_user_by_id(trip.user_id)
        driver = await self._get_user_by_id(driver_id)
        
        # 計算支付金額
        total_amount = int(trip.fare * 1000000)  # 轉為 micro IOTA
        platform_fee = int(total_amount * self.PLATFORM_FEE_RATE)
        
        # 準備鏈上支付鎖定
        escrow_result = await self.escrow_service.lock_payment(
            passenger_wallet=passenger.wallet_address,
            driver_wallet=driver.wallet_address,
            trip_id=trip.trip_id,
            amount=total_amount,
            platform_fee=platform_fee
        )
        
        # 更新行程狀態 (等待支付鎖定確認)
        trip.status = TripStatus.ACCEPTED
        
        # 更新車輛狀態
        if trip.vehicle_id:
            vehicle = await self._get_vehicle_by_id(trip.vehicle_id)
            if vehicle:
                vehicle.status = "on_trip"
        
        await self.db.commit()
        
        logger.info(f"✅ 司機接受行程: {trip_id}, 等待支付鎖定")
        
        return {
            "trip": await self._build_trip_response(trip),
            "escrow_transaction": escrow_result,
            "instructions": [
                "1. 乘客需要使用錢包簽署支付鎖定交易",
                "2. 簽署後資金將被託管在智能合約中",
                "3. 司機可以開始前往接送地點"
            ]
        }
    
    # ========================================================================
    # 確認支付鎖定 - 更新託管ID
    # ========================================================================
    
    async def confirm_payment_lock(self, trip_id: int, escrow_object_id: str) -> TripResponse:
        """
        確認支付已鎖定
        
        新增功能:
        - 接收前端提交的 escrow_object_id
        - 更新到行程記錄中
        """
        trip = await self._get_trip_by_id(trip_id)
        if not trip:
            raise ValueError("行程不存在")
        
        # 保存託管對象ID
        trip.escrow_object_id = escrow_object_id
        await self.db.commit()
        
        logger.info(f"✅ 支付鎖定確認: trip {trip_id}, escrow {escrow_object_id}")
        
        return await self._build_trip_response(trip)
    
    # ========================================================================
    # 上車 - 純後端
    # ========================================================================
    
    async def pickup_passenger(self, trip_id: int, driver_id: int) -> TripResponse:
        """
        確認乘客上車 - 純後端操作
        """
        trip = await self._get_trip_by_id(trip_id)
        if not trip:
            raise ValueError("行程不存在")
        
        if trip.driver_id != driver_id:
            raise ValueError("您不是此行程的司機")
        
        if trip.status != TripStatus.ACCEPTED:
            raise ValueError("行程狀態不正確")
        
        trip.status = TripStatus.PICKED_UP
        trip.picked_up_at = datetime.utcnow()
        
        await self.db.commit()
        
        logger.info(f"✅ 乘客已上車: trip {trip_id}")
        
        return await self._build_trip_response(trip)
    
    # ========================================================================
    # 完成行程 - 後端 + 鏈上支付釋放
    # ========================================================================
    
    async def complete_trip(self, trip_id: int, driver_id: int) -> Dict[str, Any]:
        """
        完成行程 - 關鍵變更點
        
        變更:
        - ✅ 更新後端狀態
        - ✅ 調用鏈上支付釋放
        - ✅ 可選: 創建鏈上收據
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
            now = datetime.utcnow()
            if trip.picked_up_at.tzinfo is not None:
                from datetime import timezone
                now = now.replace(tzinfo=timezone.utc)
            actual_duration = int((now - trip.picked_up_at).total_seconds() / 60)
        else:
            actual_duration = trip.estimated_duration_minutes
        
        # 重新計算最終費用
        fare_breakdown = self._calculate_fare(trip.distance_km, actual_duration)
        
        # 檢查是否有託管記錄
        if not trip.escrow_object_id:
            raise ValueError("此行程尚未支付，無法完成。請確保乘客已完成支付。")
        
        # 獲取司機和乘客資訊
        driver = await self._get_user_by_id(driver_id)
        passenger = await self._get_user_by_id(trip.user_id)
        
        logger.info(f"🚗 開始完成行程 {trip_id}，司機: {driver.username}，乘客: {passenger.username}")
        logger.info(f"💰 託管對象ID: {trip.escrow_object_id}")
        
        # 計算司機實際收益（扣除平台費用）
        driver_earnings_mist = fare_breakdown.driver_amount * 1000  # micro SUI -> MIST
        
        # 調用鏈上支付釋放
        release_result = await self.escrow_service.release_payment(
            escrow_object_id=trip.escrow_object_id,
            driver_wallet=driver.wallet_address,
            trip_id=trip.trip_id,
            amount_mist=driver_earnings_mist
        )
        
        if not release_result.get("success"):
            error_msg = release_result.get('error', '未知錯誤')
            logger.error(f"❌ 支付釋放失敗: {error_msg}")
            raise Exception(f"支付釋放失敗: {error_msg}")
        
        blockchain_tx_id = release_result.get("transaction_hash")
        logger.info(f"✅ 支付已成功釋放給司機，交易Hash: {blockchain_tx_id}")
        
        # 更新行程狀態
        trip.status = TripStatus.COMPLETED
        trip.completed_at = datetime.utcnow()
        trip.actual_duration_minutes = actual_duration
        trip.total_amount = fare_breakdown.total_amount / 1000000
        trip.payment_amount_micro_iota = str(fare_breakdown.total_amount)
        trip.blockchain_tx_id = blockchain_tx_id
        
        # 計算司機實際收益（扣除平台費用）
        driver_earnings_micro = fare_breakdown.driver_amount
        
        # 釋放車輛並更新收益
        if trip.vehicle_id:
            vehicle = await self._get_vehicle_by_id(trip.vehicle_id)
            if vehicle:
                vehicle.status = "available"
                vehicle.total_trips += 1
                vehicle.total_distance_km += trip.distance_km
                # 更新車輛收益
                current_earnings = int(vehicle.total_earnings_micro_iota or 0)
                vehicle.total_earnings_micro_iota = str(current_earnings + driver_earnings_micro)
                logger.info(f"💰 車輛收益更新: +{driver_earnings_micro} micro SUI")
        
        # 更新用戶統計和收益
        passenger.total_rides_as_passenger += 1
        driver.total_rides_as_driver += 1
        # 更新司機總收益
        current_driver_earnings = int(driver.total_earnings_micro_iota or 0)
        driver.total_earnings_micro_iota = str(current_driver_earnings + driver_earnings_micro)
        
        await self.db.commit()
        
        logger.info(f"✅ 行程完成: trip {trip_id}, tx {release_result.get('transaction_hash')}")
        
        # 可選: 創建鏈上收據
        receipt_result = None
        try:
            receipt_result = await self.escrow_service.create_trip_receipt(
                trip_id=trip.trip_id,
                passenger_address=passenger.wallet_address,
                driver_address=driver.wallet_address,
                pickup_lat=trip.pickup_lat,
                pickup_lng=trip.pickup_lng,
                dropoff_lat=trip.dropoff_lat,
                dropoff_lng=trip.dropoff_lng,
                distance_km=int(trip.distance_km * 1000),  # 轉為米
                final_amount=fare_breakdown.total_amount
            )
            logger.info(f"✅ 鏈上收據已創建: {receipt_result.get('receipt_id')}")
        except Exception as e:
            logger.warning(f"創建鏈上收據失敗 (不影響行程): {e}")
        
        return {
            "trip": await self._build_trip_response(trip, fare_breakdown),
            "payment": {
                "transaction_hash": release_result["transaction_hash"],
                "status": "released",
                "driver_amount": fare_breakdown.driver_amount,
                "platform_fee": fare_breakdown.platform_fee
            },
            "receipt": receipt_result
        }
    
    # ========================================================================
    # 取消行程 - 後端 + 可能的退款
    # ========================================================================
    
    async def cancel_trip(self, trip_id: int, user_id: int, reason: str, cancelled_by: str) -> TripResponse:
        """
        取消行程
        
        變更:
        - ✅ 如果已鎖定支付，調用退款
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
        
        # 如果已鎖定支付，進行退款
        if trip.escrow_object_id and trip.status in [TripStatus.ACCEPTED, TripStatus.PICKED_UP]:
            try:
                await self.escrow_service.refund_payment(
                    escrow_object_id=trip.escrow_object_id,
                    requester_wallet=await self._get_user_wallet(user_id)
                )
                logger.info(f"✅ 已觸發退款: trip {trip_id}")
            except Exception as e:
                logger.error(f"退款失敗: {e}")
        
        # 更新狀態
        trip.status = TripStatus.CANCELLED
        trip.cancelled_at = datetime.utcnow()
        trip.cancellation_reason = reason
        
        # 釋放車輛
        if trip.vehicle_id:
            vehicle = await self._get_vehicle_by_id(trip.vehicle_id)
            if vehicle:
                vehicle.status = "available"
        
        await self.db.commit()
        
        logger.info(f"✅ 行程已取消: trip {trip_id} by {cancelled_by}")
        
        return await self._build_trip_response(trip)
    
    # ========================================================================
    # 預估行程 - 純後端
    # ========================================================================
    
    async def get_trip_estimate(self, pickup_lat: float, pickup_lng: float, 
                               dropoff_lat: float, dropoff_lng: float) -> TripEstimate:
        """獲取行程預估"""
        distance_km = LocationService.haversine_km(pickup_lat, pickup_lng, dropoff_lat, dropoff_lng)
        duration_minutes = LocationService.estimate_travel_time_minutes(distance_km)
        fare_breakdown = self._calculate_fare(distance_km, duration_minutes)
        
        available_vehicles = await self._find_available_drivers(pickup_lat, pickup_lng, self.MAX_PICKUP_DISTANCE_KM)
        
        if available_vehicles:
            avg_distance = sum(v["distance_km"] for v in available_vehicles) / len(available_vehicles)
            wait_time = max(3, int(avg_distance * 2))
        else:
            wait_time = self.MAX_WAIT_TIME_MINUTES
        
        return TripEstimate(
            estimated_distance_km=distance_km,
            estimated_duration_minutes=duration_minutes,
            estimated_fare=fare_breakdown,
            available_vehicles_count=len(available_vehicles),
            estimated_wait_time_minutes=wait_time
        )
    
    # ========================================================================
    # 私有輔助方法
    # ========================================================================
    
    def _calculate_fare(self, distance_km: float, duration_minutes: int) -> TripFareBreakdown:
        """計算費用"""
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
    
    async def _get_vehicle_by_id(self, vehicle_id: str) -> Optional[Vehicle]:
        """根據ID獲取車輛"""
        stmt = select(Vehicle).where(Vehicle.vehicle_id == vehicle_id)
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()
    
    async def _get_driver_vehicles(self, driver_id: int) -> list:
        """獲取司機的車輛列表"""
        from app.models.vehicle import Vehicle
        stmt = select(Vehicle).where(Vehicle.owner_id == driver_id)
        result = await self.db.execute(stmt)
        return result.scalars().all()
    
    async def _get_user_wallet(self, user_id: int) -> str:
        """獲取用戶錢包地址"""
        user = await self._get_user_by_id(user_id)
        if not user:
            raise ValueError("用戶不存在")
        return user.wallet_address
    
    async def _get_user_active_trip(self, user_id: int) -> Optional[Trip]:
        """獲取用戶的活躍行程"""
        active_statuses = [
            TripStatus.REQUESTED, TripStatus.MATCHED, TripStatus.ACCEPTED, 
            TripStatus.PICKED_UP, TripStatus.IN_PROGRESS
        ]
        stmt = select(Trip).where(
            and_(
                or_(Trip.user_id == user_id, Trip.driver_id == user_id),
                Trip.status.in_(active_statuses)
            )
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()
    
    async def _find_available_drivers(self, lat: float, lng: float, radius_km: float) -> List[Dict[str, Any]]:
        """查找附近可用司機"""
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
            if vehicle.current_lat and vehicle.current_lng:
                distance_km = LocationService.haversine_km(
                    lat, lng, vehicle.current_lat, vehicle.current_lng
                )
            else:
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
                    "passenger_name": driver.username,
                    "passenger_phone": driver.phone_number,
                    "distance_km": distance_km,
                    "vehicle_model": vehicle.model,
                    "vehicle_type": vehicle.vehicle_type
                })
        
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
            escrow_object_id=trip.escrow_object_id,
            requested_at=trip.requested_at,
            matched_at=trip.matched_at,
            picked_up_at=trip.picked_up_at,
            dropped_off_at=trip.dropped_off_at,
            completed_at=trip.completed_at,
            cancelled_at=trip.cancelled_at,
            cancellation_reason=trip.cancellation_reason
        )