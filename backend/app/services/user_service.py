# backend/app/services/user_service.py
from typing import Optional, List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from app.models.user import User
from app.core.security import hash_password, verify_password
from app.schemas.user import UserCreateWithPassword, UserResponse, UserUpdate
import logging

logger = logging.getLogger(__name__)

class UserService:
    def __init__(self, db: AsyncSession):
        self.db = db
    
    async def create_user(self, user_data: UserCreateWithPassword) -> User:
        """創建新用戶"""
        # 檢查用戶名是否存在
        stmt = select(User).where(User.username == user_data.username)
        result = await self.db.execute(stmt)
        if result.scalar_one_or_none():
            raise ValueError("Username already exists")
        
        # 檢查錢包地址是否存在
        stmt = select(User).where(User.wallet_address == user_data.wallet_address)
        result = await self.db.execute(stmt)
        if result.scalar_one_or_none():
            raise ValueError("Wallet address already registered")
        
        # 創建用戶
        user = User(
            username=user_data.username,
            wallet_address=user_data.wallet_address.lower(),
            email=user_data.email,
            phone_number=user_data.phone_number,
            hashed_password=hash_password(user_data.password),
            user_type=user_data.user_type,
            display_name=user_data.display_name,
            did_identifier=user_data.did_identifier
        )
        
        self.db.add(user)
        await self.db.commit()
        await self.db.refresh(user)
        
        logger.info(f"✅ User created: {user.username}")
        return user
    
    async def get_user_by_id(self, user_id: int) -> Optional[User]:
        """根據 ID 獲取用戶"""
        stmt = select(User).where(User.id == user_id)
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()
    
    async def get_user_by_username(self, username: str) -> Optional[User]:
        """根據用戶名獲取用戶"""
        stmt = select(User).where(User.username == username)
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()
    
    async def authenticate_user(self, identifier: str, password: str) -> Optional[User]:
        """驗證用戶 - 支援用戶名、郵箱或錢包地址"""
        # 嘗試用戶名
        stmt = select(User).where(User.username == identifier)
        result = await self.db.execute(stmt)
        user = result.scalar_one_or_none()
        
        # 如果用戶名找不到，嘗試郵箱
        if not user:
            stmt = select(User).where(User.email == identifier)
            result = await self.db.execute(stmt)
            user = result.scalar_one_or_none()
        
        # 如果郵箱找不到，嘗試錢包地址
        if not user:
            stmt = select(User).where(User.wallet_address == identifier.lower())
            result = await self.db.execute(stmt)
            user = result.scalar_one_or_none()
        
        if user and verify_password(password, user.hashed_password):
            return user
        return None
    async def update_user(self, user_id: int, user_data: UserUpdate) -> Optional[User]:
        """更新用戶資料"""
        user = await self.get_user_by_id(user_id)
        if not user:
            return None
        
        # 更新提供的欄位
        update_data = user_data.model_dump(exclude_unset=True)
        for key, value in update_data.items():
            setattr(user, key, value)
        
        user.updated_at = func.now()
        await self.db.commit()
        await self.db.refresh(user)
        
        return user    