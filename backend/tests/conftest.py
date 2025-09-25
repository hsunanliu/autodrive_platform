# backend/tests/conftest.py (詳細調試版本)

"""
pytest 配置文件 - 詳細調試版本
"""

import asyncio
import pytest
import pytest_asyncio
from typing import AsyncGenerator
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy import text

print("🚀 [STEP 1] 開始導入模組...")

from app.main import app
from app.core.database import get_async_session

print("🚀 [STEP 2] 導入 Base...")
from app.models.base import Base
print(f"📋 [STEP 2] Base 物件: {Base}")
print(f"📋 [STEP 2] Base.metadata: {Base.metadata}")
print(f"📋 [STEP 2] Base.metadata.tables (導入後): {list(Base.metadata.tables.keys())}")

print("🚀 [STEP 3] 導入 User 模組...")
import app.models.user
print(f"📋 [STEP 3] app.models.user 模組: {app.models.user}")

print("🚀 [STEP 4] 從模組導入 User 類別...")
from app.models.user import User
print(f"📋 [STEP 4] User 類別: {User}")
print(f"📋 [STEP 4] User.__tablename__: {getattr(User, '__tablename__', 'NOT_FOUND')}")
print(f"📋 [STEP 4] User.__table__: {getattr(User, '__table__', 'NOT_FOUND')}")

print("🚀 [STEP 5] 檢查 Base.metadata 最終狀態...")
print(f"📋 [STEP 5] Base.metadata.tables (最終): {list(Base.metadata.tables.keys())}")

# 使用 PostgreSQL 作為測試資料庫
TEST_DATABASE_URL = "postgresql+asyncpg://autodrive:autodrive2025@db:5432/autodrive_test"

# 創建測試引擎
test_engine = create_async_engine(
    TEST_DATABASE_URL,
    echo=True,  # 開啟 SQL 日誌
    future=True
)

# 創建會話工廠
test_async_session_maker = async_sessionmaker(
    test_engine,
    class_=AsyncSession,
    expire_on_commit=False
)

@pytest.fixture(scope="session")
def event_loop():
    """創建用於整個測試會話的事件循環"""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()

@pytest_asyncio.fixture(scope="session", autouse=True)
async def setup_test_database():
    """設置測試資料庫 - 詳細調試版本"""
    print("\n" + "="*80)
    print("🔧 [SETUP] 開始設置測試資料庫...")
    
    # 🔍 詳細檢查 Base 和模型狀態
    print(f"📋 [SETUP] Base 物件 ID: {id(Base)}")
    print(f"📋 [SETUP] Base.metadata ID: {id(Base.metadata)}")
    print(f"📋 [SETUP] Base.metadata.tables: {Base.metadata.tables}")
    print(f"📋 [SETUP] Base.metadata 包含的表格: {list(Base.metadata.tables.keys())}")
    
    # 🔍 檢查 User 類別詳細資訊
    print(f"📋 [SETUP] User 類別: {User}")
    print(f"📋 [SETUP] User.__bases__: {User.__bases__}")
    print(f"📋 [SETUP] User.metadata: {getattr(User, 'metadata', 'NOT_FOUND')}")
    
    # 🔍 檢查 User.__table__ 詳細資訊
    if hasattr(User, '__table__'):
        table = User.__table__
        print(f"📋 [SETUP] User.__table__: {table}")
        print(f"📋 [SETUP] User.__table__.name: {table.name}")
        print(f"📋 [SETUP] User.__table__.metadata: {table.metadata}")
        print(f"📋 [SETUP] User.__table__.metadata is Base.metadata: {table.metadata is Base.metadata}")
    else:
        print("❌ [SETUP] User 沒有 __table__ 屬性！")
    
    # 🔍 手動檢查模型是否在 Base.metadata 中
    if 'users' in Base.metadata.tables:
        print("✅ [SETUP] users 表格已在 Base.metadata 中")
        users_table = Base.metadata.tables['users']
        print(f"📋 [SETUP] users 表格物件: {users_table}")
    else:
        print("❌ [SETUP] users 表格不在 Base.metadata 中！")
        
        # 🔧 嘗試強制註冊
        print("🔧 [SETUP] 嘗試強制重新導入...")
        import importlib
        importlib.reload(app.models.user)
        
        print(f"📋 [SETUP] 重新導入後 Base.metadata 包含的表格: {list(Base.metadata.tables.keys())}")
        
        if 'users' not in Base.metadata.tables:
            print("❌ [SETUP] 重新導入後仍然失敗！")
            
            # 🔧 最後手段：手動創建表格定義
            print("🔧 [SETUP] 使用最後手段：手動檢查...")
            try:
                # 檢查是否有循環導入或其他問題
                from app.models.user import User as UserCheck
                print(f"📋 [SETUP] 重新導入 User: {UserCheck}")
                print(f"📋 [SETUP] UserCheck.__table__: {getattr(UserCheck, '__table__', 'NOT_FOUND')}")
            except Exception as e:
                print(f"❌ [SETUP] 重新導入 User 失敗: {e}")
    
    # 先刪除所有表格
    async with test_engine.begin() as conn:
        print("🧹 [SETUP] 清理現有表格...")
        await conn.run_sync(Base.metadata.drop_all)
    
    # 創建所有表格
    async with test_engine.begin() as conn:
        print("🔧 [SETUP] 創建資料庫表格...")
        print(f"📋 [SETUP] 即將創建的表格: {list(Base.metadata.tables.keys())}")
        await conn.run_sync(Base.metadata.create_all)
    
    print("✅ [SETUP] 測試資料庫設置完成")
    
    # 驗證表格創建
    async with test_engine.connect() as conn:
        result = await conn.execute(text("SELECT tablename FROM pg_tables WHERE schemaname = 'public'"))
        tables = [row[0] for row in result]
        print(f"📋 [SETUP] 資料庫中實際存在的表格: {tables}")
    
    print("="*80 + "\n")
    
    yield
    
    # 測試結束後清理
    print("🧹 [CLEANUP] 清理測試資料庫...")
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)

@pytest_asyncio.fixture
async def db_session() -> AsyncSession:
    """為每個測試提供一個乾淨的資料庫會話"""
    print("🔍 [SESSION] 創建新的資料庫會話...")
    
    session = test_async_session_maker()
    
    try:
        yield session
    finally:
        await session.rollback()
        await session.close()
        print("🔍 [SESSION] 資料庫會話已關閉")

# 其他 fixtures 保持不變...
async def override_get_async_session() -> AsyncGenerator[AsyncSession, None]:
    """覆蓋應用中的資料庫會話依賴"""
    async with test_async_session_maker() as session:
        yield session

@pytest_asyncio.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    """創建測試用的 HTTP 客戶端"""
    app.dependency_overrides[get_async_session] = override_get_async_session
    async with AsyncClient(app=app, base_url="http://testserver") as ac:
        yield ac
    app.dependency_overrides.clear()

@pytest.fixture
def sample_user_data():
    """提供測試用的用戶資料"""
    return {
        "username": "test_alice",
        "wallet_address": "0x742d35cc8686c6ebb13c6b3dc4f3c7e6a6fd9ff3abc123def456789abcdef123",
        "email": "alice@test.com",
        "password": "TestPass123!",
        "phone_number": "0912345678",
        "user_type": "passenger"
    }

@pytest.fixture
def sample_wallet_addresses():
    """提供測試用的錢包地址"""
    return {
        "valid": [
            "0x742d35cc8686c6ebb13c6b3dc4f3c7e6a6fd9ff3abc123def456789abcdef123",  # ✅ 66字符
            "0x123abc456def789012345678901234567890abcdef123456789abcdef0123456",   # ✅ 修正為66字符
            "0xabcdef123456789abcdef123456789abcdef123456789abcdef123456789abcd"    # ✅ 修正為66字符

        ],
        "invalid": [
            "0x742d35cc",
            "0x742d35cc8686c6ebb13c6b3dc4f3c7e6a6fd9ff3abc123def456789abcdef1234",
            "742d35cc8686c6ebb13c6b3dc4f3c7e6a6fd9ff3abc123def456789abcdef123",
            "0xZZZd35cc8686c6ebb13c6b3dc4f3c7e6a6fd9ff3abc123def456789abcdef123"
        ]
    }

@pytest_asyncio.fixture
async def created_user(db_session: AsyncSession, sample_user_data):
    """創建一個測試用戶並返回"""
    user = User(**sample_user_data)
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user
