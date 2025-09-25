# backend/app/schemas/contract.py

"""
智能合約相關的 Pydantic schemas
"""

from pydantic import BaseModel, Field, validator
from typing import Optional

class ContractUserRegister(BaseModel):
    name: str = Field(..., description="用戶名稱")
    did_identifier: Optional[str] = Field(None, description="DID 標識符")
    
    @validator('name')
    def validate_name(cls, v):
        if len(v.encode('utf-8')) > 100:
            raise ValueError('名稱過長，最多100字節')
        return v

class ContractVehicleRegister(BaseModel):
    license_plate: str = Field(..., description="車牌號")
    model: str = Field(..., description="車輛型號")
    is_autonomous: bool = Field(True, description="是否自動駕駛")
    hourly_rate: int = Field(100000, description="每小時費率(micro IOTA)")
    
    @validator('hourly_rate')
    def validate_rate(cls, v):
        if v < 0:
            raise ValueError('費率不能為負數')
        return v

class ContractRideRequest(BaseModel):
    pickup_lat: float = Field(..., description="上車緯度")
    pickup_lng: float = Field(..., description="上車經度")
    dest_lat: float = Field(..., description="目的地緯度")
    dest_lng: float = Field(..., description="目的地經度")
    max_price: int = Field(..., description="最高價格(micro IOTA)")
    passenger_count: int = Field(1, description="乘客數量")
    
    @validator('passenger_count')
    def validate_passenger_count(cls, v):
        if not (1 <= v <= 8):
            raise ValueError('乘客數量必須在1-8之間')
        return v

class TransactionConfirmation(BaseModel):
    tx_digest: str = Field(..., description="交易摘要")
    object_ids: Optional[list] = Field(None, description="創建的對象ID列表")
