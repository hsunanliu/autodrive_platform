# backend/app/schemas/payment.py
"""
Payment Pydantic 模型
區塊鏈支付相關的數據結構
"""

from pydantic import BaseModel, Field, field_validator
from typing import Optional, Dict, Any
from datetime import datetime
from enum import Enum

class PaymentStatus(str, Enum):
    """支付狀態枚舉"""
    PENDING = "pending"
    CONFIRMED = "confirmed"
    FAILED = "failed"
    REFUNDED = "refunded"

class BlockchainNetwork(str, Enum):
    """區塊鏈網絡枚舉"""
    IOTA_MAINNET = "iota_mainnet"
    IOTA_TESTNET = "iota_testnet"

class PaymentTransaction(BaseModel):
    """區塊鏈支付交易記錄"""
    transaction_id: str = Field(..., description="交易ID (通常是區塊鏈哈希)")
    trip_id: int = Field(..., description="關聯的行程ID")
    
    # 錢包地址
    payer_wallet: str = Field(..., description="付款人錢包地址")
    payee_wallet: str = Field(..., description="收款人錢包地址")
    platform_wallet: str = Field(..., description="平台錢包地址")
    
    # 金額信息 (使用字符串避免精度問題)
    amount_micro_iota: str = Field(..., description="總金額 (micro IOTA)")
    driver_amount_micro_iota: str = Field(..., description="司機收入 (micro IOTA)")
    platform_fee_micro_iota: str = Field(..., description="平台費用 (micro IOTA)")
    
    # 區塊鏈信息
    blockchain_tx_hash: str = Field(..., description="區塊鏈交易哈希")
    blockchain_block_number: Optional[int] = Field(None, description="區塊號")
    network: BlockchainNetwork = Field(BlockchainNetwork.IOTA_TESTNET, description="區塊鏈網絡")
    
    # 狀態和時間
    status: PaymentStatus = Field(PaymentStatus.PENDING, description="支付狀態")
    created_at: datetime = Field(..., description="交易創建時間")
    confirmed_at: Optional[datetime] = Field(None, description="交易確認時間")
    
    # 額外信息
    gas_fee_micro_iota: Optional[str] = Field(None, description="Gas費用 (micro IOTA)")
    confirmation_count: int = Field(0, description="確認次數")
    
    class Config:
        from_attributes = True

class PaymentRequest(BaseModel):
    """支付請求"""
    trip_id: int = Field(..., description="行程ID")
    passenger_wallet: str = Field(..., description="乘客錢包地址")
    driver_wallet: str = Field(..., description="司機錢包地址")
    amount_breakdown: Dict[str, int] = Field(..., description="費用分解")
    
    @field_validator('passenger_wallet', 'driver_wallet')
    @classmethod
    def validate_wallet_address(cls, v):
        if not v.startswith('0x') or len(v) != 66:
            raise ValueError('錢包地址格式不正確')
        return v.lower()

class PaymentResponse(BaseModel):
    """支付響應"""
    transaction_id: str
    blockchain_tx_hash: str
    status: PaymentStatus
    amount_micro_iota: str
    estimated_confirmation_time_seconds: int
    network_fee_micro_iota: Optional[str] = None

class WalletBalance(BaseModel):
    """錢包餘額"""
    wallet_address: str
    balance_micro_iota: str
    balance_iota: float  # 轉換為 IOTA 單位方便顯示
    last_updated: datetime
    
    @field_validator('wallet_address')
    @classmethod
    def validate_wallet_address(cls, v):
        if not v.startswith('0x') or len(v) != 66:
            raise ValueError('錢包地址格式不正確')
        return v.lower()

class TransactionStatus(BaseModel):
    """交易狀態查詢"""
    transaction_hash: str
    status: PaymentStatus
    confirmation_count: int
    block_number: Optional[int] = None
    block_hash: Optional[str] = None
    gas_used: Optional[str] = None
    timestamp: Optional[datetime] = None

class PaymentHistory(BaseModel):
    """支付歷史記錄"""
    transaction_id: str
    trip_id: int
    amount_micro_iota: str
    status: PaymentStatus
    created_at: datetime
    confirmed_at: Optional[datetime]
    
    # 行程相關信息
    pickup_address: Optional[str] = None
    dropoff_address: Optional[str] = None
    distance_km: Optional[float] = None
    
    # 對方信息 (從用戶角度)
    counterpart_name: Optional[str] = None  # 司機名或乘客名
    counterpart_wallet: str
    
    # 交易類型 (從用戶角度)
    transaction_type: str  # "payment" (乘客) 或 "earning" (司機)

class PlatformEarnings(BaseModel):
    """平台收益統計"""
    total_earnings_micro_iota: str
    total_transactions: int
    average_fee_micro_iota: str
    period_start: datetime
    period_end: datetime
    
    # 詳細統計
    daily_earnings: Dict[str, str]  # 日期 -> 收益
    top_routes: list  # 熱門路線統計

class RefundRequest(BaseModel):
    """退款請求"""
    transaction_id: str
    reason: str = Field(..., max_length=500, description="退款原因")
    refund_amount_micro_iota: Optional[str] = Field(None, description="退款金額，None表示全額退款")
    
class RefundResponse(BaseModel):
    """退款響應"""
    refund_transaction_id: str
    original_transaction_id: str
    refund_amount_micro_iota: str
    status: PaymentStatus
    estimated_completion_time: datetime