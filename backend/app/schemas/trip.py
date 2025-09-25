# backend/app/schemas/trip.py

from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class TripBase(BaseModel):
    pickup_lat: float
    pickup_lng: float
    dropoff_lat: float
    dropoff_lng: float
    pickup_address: Optional[str] = None
    dropoff_address: Optional[str] = None
    passenger_count: Optional[int] = 1

class StartTripRequest(TripBase):
    vehicle_id: Optional[str] = None
    distance_km: Optional[float] = None
    fare: Optional[float] = None

class TripCreate(TripBase):
    vehicle_id: Optional[str] = None
    distance_km: Optional[float] = None
    fare: Optional[float] = None

class TripStatusUpdate(BaseModel):
    status: str = Field(..., description="新狀態")
    cancellation_reason: Optional[str] = None

class TripResponse(TripBase):
    trip_id: int
    user_id: int
    vehicle_id: Optional[str]
    driver_id: Optional[int]
    distance_km: Optional[float]
    fare: Optional[float]
    status: str
    requested_at: datetime
    matched_at: Optional[datetime]
    picked_up_at: Optional[datetime]
    completed_at: Optional[datetime]
    cancellation_reason: Optional[str]
    
    class Config:
        from_attributes = True
