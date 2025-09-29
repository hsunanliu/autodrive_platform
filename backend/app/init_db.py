# backend/init_db.py (新建)
import asyncio
from app.core.database import init_db

# 導入所有 models 以確保它們被註冊到 metadata
from app.models.user import User
from app.models.vehicle import Vehicle
from app.models.ride import Trip
from app.models.review import Review
from app.models.payment import PaymentMethod

async def main():
    print("Importing models...")
    from app.core.database import Base
    print(f"Available tables in metadata: {list(Base.metadata.tables.keys())}")
    
    await init_db()
    print("✅ Database initialized!")

if __name__ == "__main__":
    asyncio.run(main())