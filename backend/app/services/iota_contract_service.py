# backend/app/services/iota_contract_service.py

"""
IOTA 智能合約整合服務 - 基於您的實際合約
"""

from typing import Dict, Any, Optional, Tuple
import json
from enum import IntEnum

try:
    from iota_sdk import Client
    SDK_AVAILABLE = True
except ImportError:
    SDK_AVAILABLE = False

from app.config import settings

class ContractStatus:
    """狀態映射類"""
    
    # Vehicle Status Mapping
    VEHICLE_STATUS_MOVE_TO_BACKEND = {
        0: "offline",      # STATUS_OFFLINE
        1: "available",    # STATUS_AVAILABLE  
        2: "on_trip"       # STATUS_BUSY (推測)
    }
    
    VEHICLE_STATUS_BACKEND_TO_MOVE = {
        "offline": 0,
        "available": 1, 
        "on_trip": 2,
        "maintenance": 0  # 映射到 offline
    }
    
    # Ride Status Mapping
    RIDE_STATUS_MOVE_TO_BACKEND = {
        0: "requested",    # STATUS_PENDING
        1: "matched",      # STATUS_MATCHED
        2: "completed"     # STATUS_COMPLETED
    }
    
    RIDE_STATUS_BACKEND_TO_MOVE = {
        "requested": 0,
        "matched": 1,
        "picked_up": 1,    # 映射到 matched
        "in_progress": 1,  # 映射到 matched
        "completed": 2,
        "cancelled": 0     # 重置為 pending
    }

class IOTAContractService:
    """基於您實際 Move 合約的服務層"""
    
    def __init__(self):
        if SDK_AVAILABLE:
            self.client = Client({"nodes": [settings.IOTA_NODE_URL]})
        else:
            self.client = None
            
        self.package_id = settings.CONTRACT_PACKAGE_ID
        self.user_registry_id = settings.USER_REGISTRY_ID
        self.vehicle_registry_id = settings.VEHICLE_REGISTRY_ID
        self.matching_service_id = settings.MATCHING_SERVICE_ID
    
    # === 地理位置轉換工具 ===
    
    @staticmethod
    def coords_to_location_string(lat: float, lng: float) -> str:
        """將座標轉換為合約使用的字符串格式"""
        return f"{lat:.6f},{lng:.6f}"
    
    @staticmethod
    def location_string_to_coords(location: str) -> Tuple[float, float]:
        """將合約的位置字符串轉換為座標"""
        try:
            lat_str, lng_str = location.split(',')
            return float(lat_str), float(lng_str)
        except (ValueError, IndexError):
            raise ValueError(f"Invalid location format: {location}")
    
    # === 用戶註冊合約調用 ===
    
    async def register_user_on_blockchain(
        self,
        signer_address: str,
        name: str,
        did_identifier: Optional[str] = None
    ) -> Dict[str, Any]:
        """調用 user_registry::register_user"""
        try:
            transaction_data = {
                "kind": "moveCall",
                "data": {
                    "packageObjectId": self.package_id,
                    "module": "user_registry",
                    "function": "register_user",
                    "arguments": [
                        self.user_registry_id,
                        list(name.encode('utf-8')),  # vector<u8> 格式
                        list((did_identifier or "").encode('utf-8'))  # vector<u8> 格式
                    ],
                    "typeArguments": [],
                    "gasBudget": "10000000"
                }
            }
            
            return {
                "status": "transaction_prepared",
                "transaction_data": transaction_data,
                "signer_address": signer_address,
                "contract_call": "user_registry::register_user",
                "parameters": {
                    "name": name,
                    "did": did_identifier or "",
                    "initial_reputation": 50
                }
            }
            
        except Exception as e:
            return {
                "status": "error",
                "error": str(e),
                "contract": "user_registry"
            }
    
    # === 車輛註冊合約調用 ===
    
    async def register_vehicle_on_blockchain(
        self,
        signer_address: str,
        license_plate: str,
        model: str,
        is_autonomous: bool = True,
        hourly_rate: int = 100000  # micro IOTA
    ) -> Dict[str, Any]:
        """調用 vehicle_registry::register_vehicle"""
        try:
            transaction_data = {
                "kind": "moveCall",
                "data": {
                    "packageObjectId": self.package_id,
                    "module": "vehicle_registry", 
                    "function": "register_vehicle",
                    "arguments": [
                        self.vehicle_registry_id,
                        list(license_plate.encode('utf-8')),
                        list(model.encode('utf-8')),
                        is_autonomous,
                        str(hourly_rate)
                    ],
                    "typeArguments": [],
                    "gasBudget": "15000000"
                }
            }
            
            return {
                "status": "transaction_prepared",
                "transaction_data": transaction_data,
                "signer_address": signer_address,
                "contract_call": "vehicle_registry::register_vehicle",
                "parameters": {
                    "license_plate": license_plate,
                    "model": model,
                    "is_autonomous": is_autonomous,
                    "hourly_rate": hourly_rate,
                    "initial_status": "offline"
                }
            }
            
        except Exception as e:
            return {
                "status": "error",
                "error": str(e),
                "contract": "vehicle_registry"
            }
    
    # === 車輛狀態更新 ===
    
    async def update_vehicle_status_on_blockchain(
        self,
        signer_address: str,
        vehicle_object_id: str,
        new_status: str
    ) -> Dict[str, Any]:
        """調用 vehicle_registry::set_vehicle_status"""
        try:
            # 轉換後端狀態到合約狀態
            move_status = ContractStatus.VEHICLE_STATUS_BACKEND_TO_MOVE.get(new_status)
            if move_status is None:
                raise ValueError(f"Invalid status: {new_status}")
            
            transaction_data = {
                "kind": "moveCall",
                "data": {
                    "packageObjectId": self.package_id,
                    "module": "vehicle_registry",
                    "function": "set_vehicle_status", 
                    "arguments": [
                        vehicle_object_id,  # vehicle 對象引用
                        str(move_status)    # u8 狀態
                    ],
                    "typeArguments": [],
                    "gasBudget": "10000000"
                }
            }
            
            return {
                "status": "transaction_prepared",
                "transaction_data": transaction_data,
                "signer_address": signer_address,
                "contract_call": "vehicle_registry::set_vehicle_status",
                "status_change": {
                    "backend_status": new_status,
                    "move_status": move_status
                }
            }
            
        except Exception as e:
            return {
                "status": "error",
                "error": str(e),
                "contract": "vehicle_registry"
            }
    
    # === 叫車請求合約調用 ===
    
    async def create_ride_request_on_blockchain(
        self,
        signer_address: str,
        pickup_lat: float,
        pickup_lng: float,
        dest_lat: float,
        dest_lng: float,
        max_price: int,
        passenger_count: int = 1
    ) -> Dict[str, Any]:
        """調用 ride_matching::create_ride_request"""
        try:
            # 轉換座標為字符串格式
            pickup_location = self.coords_to_location_string(pickup_lat, pickup_lng)
            destination = self.coords_to_location_string(dest_lat, dest_lng)
            
            transaction_data = {
                "kind": "moveCall",
                "data": {
                    "packageObjectId": self.package_id,
                    "module": "ride_matching",
                    "function": "create_ride_request",
                    "arguments": [
                        self.matching_service_id,
                        list(pickup_location.encode('utf-8')),
                        list(destination.encode('utf-8')),
                        str(max_price),
                        str(passenger_count)
                    ],
                    "typeArguments": [],
                    "gasBudget": "20000000"
                }
            }
            
            return {
                "status": "transaction_prepared",
                "transaction_data": transaction_data,
                "signer_address": signer_address,
                "contract_call": "ride_matching::create_ride_request",
                "ride_details": {
                    "pickup_coords": {"lat": pickup_lat, "lng": pickup_lng},
                    "destination_coords": {"lat": dest_lat, "lng": dest_lng},
                    "pickup_location_string": pickup_location,
                    "destination_string": destination,
                    "max_price": max_price,
                    "passenger_count": passenger_count
                }
            }
            
        except Exception as e:
            return {
                "status": "error",
                "error": str(e),
                "contract": "ride_matching"
            }
    
    # === 配對接受合約調用 ===
    
    async def match_ride_request_on_blockchain(
        self,
        signer_address: str,
        ride_request_object_id: str,
        vehicle_object_id: str,
        driver_address: str,
        agreed_price: int
    ) -> Dict[str, Any]:
        """調用 ride_matching::match_request"""
        try:
            transaction_data = {
                "kind": "moveCall",
                "data": {
                    "packageObjectId": self.package_id,
                    "module": "ride_matching",
                    "function": "match_request",
                    "arguments": [
                        self.matching_service_id,
                        ride_request_object_id,
                        vehicle_object_id,
                        driver_address,
                        str(agreed_price)
                    ],
                    "typeArguments": [],
                    "gasBudget": "25000000"
                }
            }
            
            return {
                "status": "transaction_prepared",
                "transaction_data": transaction_data,
                "signer_address": signer_address,
                "contract_call": "ride_matching::match_request",
                "match_details": {
                    "request_id": ride_request_object_id,
                    "vehicle_id": vehicle_object_id,
                    "driver": driver_address,
                    "agreed_price": agreed_price
                }
            }
            
        except Exception as e:
            return {
                "status": "error",
                "error": str(e),
                "contract": "ride_matching"
            }
    
    # === 完成行程合約調用 ===
    
    async def complete_ride_on_blockchain(
        self,
        signer_address: str,
        ride_match_object_id: str
    ) -> Dict[str, Any]:
        """調用 ride_matching::complete_ride"""
        try:
            transaction_data = {
                "kind": "moveCall",
                "data": {
                    "packageObjectId": self.package_id,
                    "module": "ride_matching",
                    "function": "complete_ride",
                    "arguments": [
                        ride_match_object_id
                    ],
                    "typeArguments": [],
                    "gasBudget": "15000000"
                }
            }
            
            return {
                "status": "transaction_prepared",
                "transaction_data": transaction_data,
                "signer_address": signer_address,
                "contract_call": "ride_matching::complete_ride",
                "match_id": ride_match_object_id
            }
            
        except Exception as e:
            return {
                "status": "error",
                "error": str(e),
                "contract": "ride_matching"
            }
    
    # === 事件監聽和狀態同步 ===
    
    async def parse_contract_events(self, tx_digest: str) -> Dict[str, Any]:
        """解析合約事件"""
        try:
            tx_result = await self.client.get_transaction_block(
                digest=tx_digest,
                options={"showEvents": True}
            )
            
            events = []
            for event in tx_result.get("events", []):
                event_type = event.get("type", "")
                
                # 解析不同類型的事件
                if "UserRegistered" in event_type:
                    events.append({
                        "event_type": "user_registered",
                        "user_id": event["parsedJson"]["user_id"],
                        "name": event["parsedJson"]["name"],
                        "owner": event["parsedJson"]["owner"]
                    })
                
                elif "VehicleRegistered" in event_type:
                    events.append({
                        "event_type": "vehicle_registered",
                        "vehicle_id": event["parsedJson"]["vehicle_id"],
                        "license_plate": event["parsedJson"]["license_plate"],
                        "owner": event["parsedJson"]["owner"]
                    })
                
                elif "RideRequestCreated" in event_type:
                    pickup_lat, pickup_lng = self.location_string_to_coords(
                        event["parsedJson"]["pickup_location"]
                    )
                    dest_lat, dest_lng = self.location_string_to_coords(
                        event["parsedJson"]["destination"]  
                    )
                    
                    events.append({
                        "event_type": "ride_request_created",
                        "request_id": event["parsedJson"]["request_id"],
                        "passenger": event["parsedJson"]["passenger"],
                        "pickup_coords": {"lat": pickup_lat, "lng": pickup_lng},
                        "destination_coords": {"lat": dest_lat, "lng": dest_lng}
                    })
                
                elif "RideMatched" in event_type:
                    events.append({
                        "event_type": "ride_matched",
                        "request_id": event["parsedJson"]["request_id"],
                        "match_id": event["parsedJson"]["match_id"],
                        "vehicle_id": event["parsedJson"]["vehicle_id"],
                        "passenger": event["parsedJson"]["passenger"],
                        "driver": event["parsedJson"]["driver"],
                        "agreed_price": event["parsedJson"]["agreed_price"]
                    })
            
            return {
                "status": "events_parsed",
                "transaction_digest": tx_digest,
                "events": events
            }
            
        except Exception as e:
            return {
                "status": "parse_failed",
                "error": str(e)
            }

# 全局服務實例
_iota_contract_service = None

def get_iota_contract_service() -> IOTAContractService:
    global _iota_contract_service
    if _iota_contract_service is None:
        _iota_contract_service = IOTAContractService()
    return _iota_contract_service
