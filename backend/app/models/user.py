# backend/app/models/user.py
"""
User 資料庫模型
整合傳統 Web2 用戶管理與 Web3 區塊鏈身份
"""
from sqlalchemy import Column, Integer, String, Boolean, DateTime, CheckConstraint, Text
from sqlalchemy.sql import func
from .base import Base
from sqlalchemy.orm import relationship


class User(Base):
    """
    用戶模型 - 結合傳統與區塊鏈身份
    
    主要特色：
    1. Web3 身份：錢包地址、DID 標識符、智能合約對象ID
    2. Web2 兼容：用戶名、郵箱、密碼（可選）
    3. 業務邏輯：角色管理、信譽分數、統計數據
    """
    __tablename__ = "users"
    #__table_args__ = {"extend_existing": True}  # ✅ 允許重複定義
    
    # === 主鍵 ===
    id = Column(Integer, primary_key=True, index=True, comment="用戶 ID（自動遞增）")
    
    # === 區塊鏈身份 (Web3) ===
    wallet_address = Column(
        String(66), 
        unique=True, 
        nullable=False, 
        index=True,
        comment="IOTA 錢包地址（0x + 64位十六進制）"
    )
    
    did_identifier = Column(
        String(255), 
        unique=True, 
        nullable=True,
        comment="去中心化身份標識符（DID）"
    )
    
    blockchain_object_id = Column(
        String(66), 
        unique=True, 
        nullable=True,
        comment="智能合約中的 UserProfile 對象ID"
    )
    
    # === 傳統身份 (Web2) ===
    username = Column(
        String(50), 
        unique=True, 
        nullable=False, 
        index=True,
        comment="用戶名（3-50字符，唯一）"
    )
    
    email = Column(
        String(255), 
        unique=True, 
        nullable=True,
        comment="郵箱地址（可選）"
    )
    
    phone_number = Column(
        String(20), 
        nullable=True,
        comment="電話號碼（可選）"
    )
    
    # === 認證資訊 ===
    hashed_password = Column(
        String(255), 
        nullable=True,
        comment="密碼哈希（可選，主要用錢包簽名認證）"
    )
    
    password_salt = Column(
        String(255),
        nullable=True,
        comment="密碼鹽值"
    )
    
    # === 角色與權限 ===
    user_type = Column(
        String(20), 
        default="passenger", 
        nullable=False,
        comment="用戶類型：passenger（乘客）、driver（司機）、both（兩者）"
    )
    
    reputation_score = Column(
        Integer, 
        default=50, 
        nullable=False,
        comment="信譽分數（0-100，新用戶默認50）"
    )
    
    is_verified = Column(
        Boolean, 
        default=False, 
        nullable=False,
        comment="身份驗證狀態（KYC）"
    )
    
    is_active = Column(
        Boolean, 
        default=True, 
        nullable=False,
        comment="帳號啟用狀態"
    )
    
    # === 統計資料 ===
    total_rides_as_passenger = Column(
        Integer, 
        default=0, 
        nullable=False,
        comment="作為乘客的總乘車次數"
    )
    
    total_rides_as_driver = Column(
        Integer, 
        default=0, 
        nullable=False,
        comment="作為司機的總服務次數"
    )
    
    total_distance_km = Column(
        Integer,
        default=0,
        nullable=False,
        comment="總行駛距離（公里）"
    )
    
    total_earnings_micro_iota = Column(
        String(50),
        default="0",
        nullable=False,
        comment="總收入（micro IOTA，用字符串存儲避免精度問題）"
    )
    
    # === 個人資料 ===
    display_name = Column(
        String(100),
        nullable=True,
        comment="顯示名稱（可以包含中文、特殊字符）"
    )
    
    bio = Column(
        Text,
        nullable=True,
        comment="個人簡介"
    )
    
    avatar_url = Column(
        String(500),
        nullable=True,
        comment="頭像 URL"
    )
    
    # === 隱私設置 ===
    privacy_settings = Column(
        Text,  # 存儲 JSON
        nullable=True,
        comment="隱私設置（JSON 格式）"
    )
    
    # === 時間戳記 ===
    created_at = Column(
        DateTime(timezone=True), 
        server_default=func.now(), 
        nullable=False,
        comment="帳號創建時間"
    )
    
    updated_at = Column(
        DateTime(timezone=True), 
        onupdate=func.now(),
        comment="最後更新時間"
    )
    
    last_active_at = Column(
        DateTime(timezone=True), 
        server_default=func.now(),
        comment="最後活躍時間"
    )
    
    last_login_at = Column(
        DateTime(timezone=True),
        nullable=True,
        comment="最後登入時間"
    )
    
    # === 約束條件 ===
    __table_args__ = (
        # 信譽分數必須在 0-100 之間
        CheckConstraint(
            'reputation_score >= 0 AND reputation_score <= 100', 
            name='valid_reputation_range'
        ),
        
        # 用戶類型必須是有效值
        CheckConstraint(
            "user_type IN ('passenger', 'driver', 'both')", 
            name='valid_user_type'
        ),
        
        # 統計數據不能為負數
        CheckConstraint(
            'total_rides_as_passenger >= 0', 
            name='valid_passenger_rides'
        ),
        
        CheckConstraint(
            'total_rides_as_driver >= 0', 
            name='valid_driver_rides'
        ),
        
        CheckConstraint(
            'total_distance_km >= 0',
            name='valid_total_distance'
        ),
    )
    
    def __repr__(self):
        return f"<User(id={self.id}, username='{self.username}', wallet='{self.wallet_address[:10]}...')>"
    
    def __str__(self):
        return f"User {self.username} ({self.wallet_address})"
    
    # === 業務邏輯方法 ===
    
    @property
    def total_rides(self) -> int:
        """總乘車次數（乘客 + 司機）"""
        return self.total_rides_as_passenger + self.total_rides_as_driver
    
    @property
    def is_driver(self) -> bool:
        """是否為司機"""
        return self.user_type in ('driver', 'both')
    
    @property
    def is_passenger(self) -> bool:
        """是否為乘客"""
        return self.user_type in ('passenger', 'both')
    
    @property
    def short_wallet_address(self) -> str:
        """錢包地址縮寫顯示"""
        if not self.wallet_address:
            return ""
        return f"{self.wallet_address[:6]}...{self.wallet_address[-4:]}"
    
    def can_drive(self) -> bool:
        """是否可以開車（需要驗證身份且為司機）"""
        return self.is_driver and self.is_verified and self.is_active
    
    def can_request_ride(self) -> bool:
        """是否可以叫車"""
        return self.is_passenger and self.is_active
# === 關聯關係 ===
vehicles = relationship("Vehicle", back_populates="owner")
trips_as_passenger = relationship("Trip", foreign_keys="Trip.user_id", back_populates="passenger")
trips_as_driver = relationship("Trip", foreign_keys="Trip.driver_id", back_populates="driver")
reviews_given = relationship("Review", foreign_keys="Review.reviewer_id", back_populates="reviewer")
reviews_received = relationship("Review", foreign_keys="Review.reviewee_id", back_populates="reviewee")
payment_methods = relationship("PaymentMethod", back_populates="user")