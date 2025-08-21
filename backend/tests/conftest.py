# backend/tests/conftest.py
"""
pytest 配置文件
定義測試用的 fixtures 和設置
"""
import asyncio
import pytest
from typing import AsyncGenerator
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.pool import StaticPool
from sqlalchemy.pool import StaticPool
from sqlalchemy import event
from sqlalchemy.engine import Engine
import sqlite3

from app.main import app
from app.core.database import get_async_session, Base
from app.models.user import User

# 測試資料庫 URL（使用獨立的測試資料庫）
TEST_DATABASE_URL = "postgresql+asyncpg://autodrive:password@db:5432/autodrive_test"

# 創建測試用的異步引擎
test_engine = create_async_engine(
    TEST_DATABASE_URL,
    echo=False,  # 測試時不顯示 SQL
    poolclass=StaticPool,
    connect_args={"check_same_thread": False}
)

# 創建測試會話工廠
test_async_session_maker = async_sessionmaker(
    test_engine,
    class_=AsyncSession,
    expire_on_commit=False
)


@pytest.fixture(scope="session")
def event_loop():
    """
    創建用於整個測試會話的事件循環
    """
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(scope="session")
async def setup_test_database():
    """
    設置測試資料庫
    在所有測試開始前創建表格，測試結束後清理
    """
    # 創建所有表格
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    yield
    
    # 清理：刪除所有表格
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest.fixture
async def db_session(setup_test_database):
    """
    為每個測試提供一個乾淨的資料庫會話
    """
    import asyncio
    def _get_session():
        loop = asyncio.get_event_loop()
        session = test_async_session_maker()
    
        class SessionWrapper:
            def __init__(self, session):
                self._session = session
                self._transaction = None
            
            def __getattr__(self, name):
                return getattr(self._session, name)
            
            async def __aenter__(self):
                self._transaction = await self._session.begin()
                return self._session
            
            async def __aexit__(self, exc_type, exc_val, exc_tb):
                if self._transaction:
                    await self._transaction.rollback()
                await self._session.close()
        
        return SessionWrapper(session)
    
    return _get_session()


async def override_get_async_session() -> AsyncGenerator[AsyncSession, None]:
    """
    覆蓋應用中的資料庫會話依賴
    """
    async with test_async_session_maker() as session:
        yield session


@pytest.fixture
async def client(setup_test_database) -> AsyncGenerator[AsyncClient, None]:
    """
    創建測試用的 HTTP 客戶端
    """
    # 覆蓋資料庫依賴
    app.dependency_overrides[get_async_session] = override_get_async_session
    
    async with AsyncClient(app=app, base_url="http://testserver") as ac:
        yield ac
    
    # 清理依賴覆蓋
    app.dependency_overrides.clear()


@pytest.fixture
async def sample_user_data():
    """
    提供測試用的用戶資料
    """
    return {
        "username": "test_alice",
        "wallet_address": "0x742d35cc8686c6ebb13c6b3dc4f3c7e6a6fd9ff3abc123def456789abcdef123",
        "email": "alice@test.com",
        "password": "TestPass123!",
        "phone_number": "0912345678",
        "user_type": "passenger"
    }


@pytest.fixture
async def created_user(db_session: AsyncSession, sample_user_data):
    """
    創建一個測試用戶並返回
    """
    from app.services.user_service import UserService
    from app.repositories.user_repository import UserRepository
    from app.schemas.user import UserCreateWithPassword
    
    user_repo = UserRepository(User, db_session)
    user_service = UserService(user_repo)
    
    user_create = UserCreateWithPassword(**sample_user_data)
    user = await user_service.create_user(user_create)
    
    return user


@pytest.fixture
def sample_wallet_addresses():
    """
    提供測試用的錢包地址
    """
    return [
        "0x742d35cc8686c6ebb13c6b3dc4f3c7e6a6fd9ff3abc123def456789abcdef123",
        "0x123abc456def789012345678901234567890abcdef123456789abcdef012345",
        "0xabcdef123456789abcdef123456789abcdef123456789abcdef123456789abc"
    ]
