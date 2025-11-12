"""
背景任務：自動升級等待過久的標準叫車訂單
定期檢查並升級等待超過 15 分鐘的 priority 2 訂單
"""

import asyncio
import logging
from datetime import datetime
from app.core.database import async_session_maker
from app.services.trip_service import TripService

logger = logging.getLogger(__name__)


async def run_auto_upgrade_task():
    """
    背景任務主函數
    每 5 分鐘執行一次自動升級檢查
    """
    logger.info("🚀 自動升級背景任務已啟動")

    while True:
        try:
            # 創建資料庫會話
            async with async_session_maker() as db:
                trip_service = TripService(db)

                # 執行自動升級
                result = await trip_service.auto_upgrade_waiting_trips()

                if result["upgraded_count"] > 0:
                    logger.info(
                        f"✅ 自動升級完成: {result['upgraded_count']} 個訂單已升級 "
                        f"(IDs: {result['upgraded_trip_ids']})"
                    )
                else:
                    logger.debug("⏳ 沒有需要升級的訂單")

        except Exception as e:
            logger.error(f"❌ 自動升級任務執行失敗: {e}", exc_info=True)

        # 等待 5 分鐘後再次執行
        await asyncio.sleep(300)  # 300 秒 = 5 分鐘


def start_auto_upgrade_task():
    """
    啟動背景任務
    這個函數應該在 FastAPI 應用啟動時被調用
    """
    asyncio.create_task(run_auto_upgrade_task())
    logger.info("📋 自動升級背景任務已註冊")
