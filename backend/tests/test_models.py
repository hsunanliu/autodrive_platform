# backend/tests/test_models.py
"""
測試 SQLAlchemy 資料模型
"""
import pytest
from sqlalchemy.exc import IntegrityError
from app.models.user import User
from tests.utils.test_data import VALID_USER_DATA


class TestUserModel:
    """測試 User 模型"""
    
    @pytest.mark.asyncio
    async def test_user_creation(self, db_session):
        """測試用戶創建"""
        
        user = User(
            username="test_user",
            wallet_address="0x9bdeefc53afba9fca554dc61025514e21fb4e9f9281ad4449bca86f72f18dd",
            email="test@example.com",
            user_type="passenger"
        )
        
        db_session.add(user)
        await db_session.commit()
        await db_session.refresh(user)
        
        assert user.id is not None
        assert user.username == "test_user"
        assert user.reputation_score == 50  # 默認值
        assert user.is_active is True       # 默認值
        assert user.created_at is not None
    
    @pytest.mark.asyncio
    async def test_user_unique_constraints(self, db_session):
        """測試用戶唯一性約束"""
        # 創建第一個用戶
        user1 = User(
            username="unique_user",
            wallet_address="0x9bdeefc53afba9fca554dc61025514e21fb4e9f9281ad4449bca86f72f18dd5f",
            email="unique@example.com"
        )
        
        db_session.add(user1)
        await db_session.commit()
        
        # 嘗試創建相同用戶名的用戶
        user2 = User(
            username="unique_user",  # 重複用戶名
            wallet_address="0x9bdeefc53afba9fca554dc61025514e21fb4e9f9281ad4449bca86f72f18dd5f",
            email="different@example.com"
        )
        
        db_session.add(user2)
        
        with pytest.raises(IntegrityError):
            await db_session.commit()
    
    @pytest.mark.asyncio
    async def test_user_properties(self, db_session):
        """測試用戶模型屬性"""
        user = User(
            username="property_test",
            wallet_address="0x742d35cc8686c6ebb13c6b3dc4f3c7e6a6fd9ff3abc123def456789abcdef123",
            user_type="both",
            total_rides_as_passenger=5,
            total_rides_as_driver=3
        )
        
        # 測試計算屬性
        assert user.total_rides == 8
        assert user.is_driver is True
        assert user.is_passenger is True
        assert user.short_wallet_address == "0x742d...f123"
        
        # 測試業務邏輯方法
        user.is_verified = True
        user.is_active = True
        assert user.can_drive() is True
        assert user.can_request_ride() is True
    
    @pytest.mark.asyncio
    async def test_user_constraints(self, db_session):
        """測試用戶約束條件"""
        # 測試信譽分數約束
        user = User(
            username="constraint_test",
            wallet_address="0x742d35cc8686c6ebb13c6b3dc4f3c7e6a6fd9ff3abc123def456789abcdef123",
            reputation_score=150  # 超出範圍
        )
        
        db_session.add(user)
        
        with pytest.raises(IntegrityError):
            await db_session.commit()
