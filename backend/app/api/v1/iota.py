# backend/app/api/v1/iota.py
from fastapi import APIRouter, HTTPException, Depends
from app.services.iota_service import get_iota_service, IOTAService
from pydantic import BaseModel
from typing import Optional

router = APIRouter()

class UserRegistrationRequest(BaseModel):
    signer_address: str
    username: str
    did_identifier: Optional[str] = None

class VehicleRegistrationRequest(BaseModel):
    signer_address: str
    license_plate: str
    make_model: str
    hourly_rate: int

class RideRequestModel(BaseModel):
    signer_address: str
    pickup_location: str
    destination: str
    max_price: int
    passenger_count: int = 1

@router.get("/iota/info")
async def get_network_info(iota_service: IOTAService = Depends(get_iota_service)):
    """獲取 IOTA 網路資訊"""
    try:
        info = await iota_service.get_network_info()
        return {
            "status": "success",
            "network_info": info,
            "contracts": {
                "package_id": iota_service.package_id,
                "user_registry": "0x9bdeefc53afba9fca554dc61025514e21fb4e9f9281ad4449bca86f72f18dd5f",
                "vehicle_registry": "0xfaf54e90664e669943e07e9845dbd2523e71920b04dd5bf264700a68c1370ce4",
                "matching_service": "0xa700e716702ae263edc3db7201da6235231e4b76a534c3bb23842eb92a29bfda"
            }
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/iota/register-user")
async def register_user(
    request: UserRegistrationRequest,
    iota_service: IOTAService = Depends(get_iota_service)
):
    """準備用戶註冊交易"""
    try:
        result = await iota_service.register_user(
            request.signer_address,
            request.username,
            request.did_identifier
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/iota/register-vehicle")
async def register_vehicle(
    request: VehicleRegistrationRequest,
    iota_service: IOTAService = Depends(get_iota_service)
):
    """準備車輛註冊交易"""
    try:
        result = await iota_service.register_vehicle(
            request.signer_address,
            request.license_plate,
            request.make_model,
            request.hourly_rate
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/iota/create-ride-request")
async def create_ride_request(
    request: RideRequestModel,
    iota_service: IOTAService = Depends(get_iota_service)
):
    """準備乘車請求交易"""
    try:
        result = await iota_service.create_ride_request(
            request.signer_address,
            request.pickup_location,
            request.destination,
            request.max_price,
            request.passenger_count
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/iota/object/{object_id}")
async def get_object_info(
    object_id: str,
    iota_service: IOTAService = Depends(get_iota_service)
):
    """獲取鏈上對象詳情"""
    try:
        obj = await iota_service.get_object(object_id)
        if not obj:
            raise HTTPException(status_code=404, detail="Object not found")
        return {"status": "success", "object": obj}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
