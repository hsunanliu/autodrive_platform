# Placeholder for user schema# backend/app/schemas/user.py
"""
User API 資料驗證模型
使用 Pydantic 進行請求/響應資料驗證
"""
from pydantic import BaseModel, EmailStr, Field, validator
from datetime import datetime
from typing import Optional
from app.utils.validators import (
    password_strength_ok, 
    phone_number_ok, 
    wallet_address_ok, 
    did_identifier_ok, 
    username_ok
)


# === 基礎模型 ===

class UserBase(BaseModel):
    """用戶基礎資料模型"""
    username: str = Field(..., min_length=3, max_length=50, description="用戶名")
    email: Optional[EmailStr] = Field(None, description="郵箱地址（可選）")
    phone_number: Optional[str] = Field(None, description="電話號碼（可選）")
    display_name: Optional[str] = Field(None, max_length=100, description="顯示名稱")
    bio: Optional[str] = Field(None, max_length=500, description="個人簡介")


# === 創建用戶請求 ===

class UserCreateWithPassword(UserBase):
    """使用密碼註冊的用戶創建請求"""
    wallet_address: str = Field(..., description="IOTA 錢包地址")
    password: str = Field(..., min_length=8, description="密碼")
    did_identifier: Optional[str] = Field(None, description="DID 標識符（可選）")
    user_type: str = Field(default="passenger", description="用戶類型")
    
    @validator('wallet_address')
    def validate_wallet_address(cls, v):
        if not wallet_address_ok(v):
            raise ValueError('錢包地址格式不正確')
        return v.lower()
    
    @validator('password')
    def validate_password_strength(cls, v):
        if not password_strength_ok(v):
            raise ValueError('密碼需至少8碼且包含3種以上字元類型（大寫、小寫、數字、特殊字符）')
        return v
    
    @validator('phone_number')
    def validate_phone_number(cls, v):
        if v and not phone_number_ok(v):
            raise ValueError('電話號碼格式不正確')
        return v
    
    @validator('did_identifier')
    def validate_did(cls, v):
        if v and not did_identifier_ok(v):
            raise ValueError('DID 標識符格式不正確')
        return v
    
    @validator('username')
    def validate_username(cls, v):
        if not username_ok(v):
            raise ValueError('用戶名格式不正確（3-50字符，字母開頭，只能包含字母數字下劃線連字符）')
        return v
    
    @validator('user_type')
    def validate_user_type(cls, v):
        if v not in ['passenger', 'driver', 'both']:
            raise ValueError('用戶類型必須是 passenger、driver 或 both')
        return v


class UserCreateWithWallet(BaseModel):
    """使用錢包簽名註冊的用戶創建請求"""
    username: str = Field(..., min_length=3, max_length=50)
    wallet_address: str = Field(..., description="IOTA 錢包地址")
    signature: str = Field(..., description="錢包簽名")
    message: str = Field(..., description="簽名的原始訊息")
    did_identifier: Optional[str] = Field(None, description="DID 標識符")
    email: Optional[EmailStr] = None
    phone_number: Optional[str] = None
    user_type: str = Field(default="passenger")
    
    # 使用相同的驗證器
    _validate_wallet = validator('wallet_address', allow_reuse=True)(
        UserCreateWithPassword.validate_wallet_address
    )
    _validate_username = validator('username', allow_reuse=True)(
        UserCreateWithPassword.validate_username
    )
    _validate_phone = validator('phone_number', allow_reuse=True)(
        UserCreateWithPassword.validate_phone_number
    )
    _validate_did = validator('did_identifier', allow_reuse=True)(
        UserCreateWithPassword.validate_did
    )
    _validate_type = validator('user_type', allow_reuse=True)(
        UserCreateWithPassword.validate_user_type
    )


# === 更新用戶請求 ===

class UserUpdate(BaseModel):
    """用戶資料更新請求"""
    username: Optional[str] = Field(None, min_length=3, max_length=50)
    email: Optional[EmailStr] = None
    phone_number: Optional[str] = None
    display_name: Optional[str] = Field(None, max_length=100)
    bio: Optional[str] = Field(None, max_length=500)
    user_type: Optional[str] = None
    avatar_url: Optional[str] = Field(None, max_length=500)
    
    @validator('username')
    def validate_username(cls, v):
        if v and not username_ok(v):
            raise ValueError('用戶名格式不正確')
        return v
    
    @validator('phone_number')
    def validate_phone_number(cls, v):
        if v and not phone_number_ok(v):
            raise ValueError('電話號碼格式不正確')
        return v
    
    @validator('user_type')
    def validate_user_type(cls, v):
        if v and v not in ['passenger', 'driver', 'both']:
            raise ValueError('用戶類型必須是 passenger、driver 或 both')
        return v


# === 密碼相關 ===

class PasswordChangeRequest(BaseModel):
    """密碼變更請求"""
    current_password: str = Field(..., description="當前密碼")
    new_password: str = Field(..., min_length=8, description="新密碼")
    
    @validator('new_password')
    def validate_new_password(cls, v):
        if not password_strength_ok(v):
            raise ValueError('新密碼需至少8碼且包含3種以上字元類型')
        return v


class PasswordResetRequest(BaseModel):
    """密碼重置請求"""
    email: Optional[EmailStr] = None
    phone_number: Optional[str] = None
    wallet_address: Optional[str] = None
    
    @validator('wallet_address')
    def validate_wallet_address(cls, v):
        if v and not wallet_address_ok(v):
            raise ValueError('錢包地址格式不正確')
        return v.lower() if v else None


# === 登入相關 ===

class LoginWithPassword(BaseModel):
    """密碼登入請求"""
    identifier: str = Field(..., description="用戶名、郵箱或電話號碼")
    password: str = Field(..., description="密碼")


class LoginWithWallet(BaseModel):
    """錢包簽名登入請求"""
    wallet_address: str = Field(..., description="錢包地址")
    signature: str = Field(..., description="簽名")
    message: str = Field(..., description="簽名訊息")
    
    @validator('wallet_address')
    def validate_wallet_address(cls, v):
        if not wallet_address_ok(v):
            raise ValueError('錢包地址格式不正確')
        return v.lower()


# === 響應模型 ===

class UserResponse(BaseModel):
    """用戶資料響應模型"""
    id: int
    username: str
    wallet_address: str
    did_identifier: Optional[str]
    blockchain_object_id: Optional[str]
    
    email: Optional[str]
    phone_number: Optional[str]
    display_name: Optional[str]
    bio: Optional[str]
    avatar_url: Optional[str]
    
    user_type: str
    reputation_score: int
    is_verified: bool
    is_active: bool
    
    total_rides_as_passenger: int
    total_rides_as_driver: int
    total_distance_km: int
    total_earnings_micro_iota: str
    
    created_at: datetime
    updated_at: Optional[datetime]
    last_active_at: Optional[datetime]
    last_login_at: Optional[datetime]
    
    # 計算屬性
    total_rides: Optional[int] = None
    short_wallet_address: Optional[str] = None
    
    class Config:
        from_attributes = True
        
    @validator('total_rides', pre=False, always=True)
    def calculate_total_rides(cls, v, values):
        passenger_rides = values.get('total_rides_as_passenger', 0)
        driver_rides = values.get('total_rides_as_driver', 0)
        return passenger_rides + driver_rides
    
    @validator('short_wallet_address', pre=False, always=True)
    def calculate_short_address(cls, v, values):
        wallet = values.get('wallet_address', '')
        if wallet and len(wallet) >= 10:
            return f"{wallet[:6]}...{wallet[-4:]}"
        return wallet


class UserPublicResponse(BaseModel):
    """用戶公開資料響應（隱藏敏感資訊）"""
    id: int
    username: str
    display_name: Optional[str]
    bio: Optional[str]
    avatar_url: Optional[str]
    user_type: str
    reputation_score: int
    is_verified: bool
    total_rides_as_passenger: int
    total_rides_as_driver: int
    created_at: datetime
    short_wallet_address: str
    
    class Config:
        from_attributes = True


class UserListResponse(BaseModel):
    """用戶列表響應"""
    users: list[UserPublicResponse]
    total: int
    page: int
    page_size: int
    total_pages: int


# === 認證響應 ===

class TokenResponse(BaseModel):
    """登入成功響應"""
    access_token: str
    token_type: str = "bearer"
    expires_in: int  # 秒
    user: UserResponse


class RefreshTokenRequest(BaseModel):
    """刷新 Token 請求"""
    refresh_token: str


# === 區塊鏈相關 ===

class BlockchainRegistrationResponse(BaseModel):
    """區塊鏈註冊結果"""
    success: bool
    transaction_hash: Optional[str]
    object_id: Optional[str]
    gas_used: Optional[int]
    error_message: Optional[str]


class UserStatsResponse(BaseModel):
    """用戶統計資料響應"""
    total_users: int
    active_users: int
    verified_users: int
    drivers_count: int
    passengers_count: int
    average_reputation: float
