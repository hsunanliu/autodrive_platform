"""
初始化資料庫 - 創建所有表
"""
import asyncio
from sqlalchemy import text
from app.core.database import engine, Base
from app.models.user import User
from app.models.vehicle import Vehicle
from app.models.ride import Trip
from app.models.review import Review

async def init_db():
    """創建所有表"""
    print("🔧 開始創建資料庫表...")
    print(f"📦 已載入的模型:")
    for table_name in Base.metadata.tables.keys():
        print(f"  - {table_name}")

    async with engine.begin() as conn:
        # 創建所有表
        await conn.run_sync(Base.metadata.create_all)

    print("\n✅ 資料庫表創建完成！")

    # 顯示創建的表
    async with engine.connect() as conn:
        result = await conn.execute(
            text("SELECT tablename FROM pg_tables WHERE schemaname = 'public'")
        )
        tables = result.fetchall()
        print(f"\n📋 資料庫中的表：")
        if tables:
            for table in tables:
                print(f"  - {table[0]}")
        else:
            print("  (無表)")

if __name__ == "__main__":
    asyncio.run(init_db())
