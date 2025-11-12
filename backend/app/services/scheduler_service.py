"""
定時任務調度服務
使用 APScheduler 定期執行批次任務
"""

import logging
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.interval import IntervalTrigger
from apscheduler.triggers.cron import CronTrigger
from datetime import datetime

logger = logging.getLogger(__name__)


class SchedulerService:
    """定時任務調度服務"""

    def __init__(self):
        self.scheduler = AsyncIOScheduler()
        self._is_started = False

    def start(self):
        """啟動調度器"""
        if self._is_started:
            logger.warning("⚠️ 調度器已經啟動")
            return

        try:
            # 添加定時任務
            self._add_jobs()

            # 啟動調度器
            self.scheduler.start()
            self._is_started = True

            logger.info("✅ 定時任務調度器已啟動")
            logger.info(f"   當前時間: {datetime.now()}")

        except Exception as e:
            logger.error(f"❌ 啟動調度器失敗: {str(e)}")

    def shutdown(self):
        """關閉調度器"""
        if not self._is_started:
            return

        try:
            self.scheduler.shutdown()
            self._is_started = False
            logger.info("✅ 定時任務調度器已關閉")
        except Exception as e:
            logger.error(f"❌ 關閉調度器失敗: {str(e)}")

    def _add_jobs(self):
        """添加定時任務"""

        # 1. 批次處理退款 - 每小時執行一次
        self.scheduler.add_job(
            func=self._process_pending_refunds,
            trigger=IntervalTrigger(hours=1),
            id="process_pending_refunds",
            name="批次處理待處理的退款",
            replace_existing=True,
            max_instances=1,  # 同時只能有一個實例運行
        )

        logger.info("📋 已添加定時任務: 批次處理退款 (每小時)")

        # 可以根據需要添加更多定時任務
        # 例如：
        # - 清理過期的訂單
        # - 更新車輛位置
        # - 發送通知
        # - 生成報表

    async def _process_pending_refunds(self):
        """批次處理待處理的退款（異步任務）"""
        try:
            logger.info("🔄 開始執行定時任務: 批次處理退款...")

            # 動態導入以避免循環依賴
            from scripts.process_pending_refunds import run_batch_processor

            # 執行批次處理
            result = await run_batch_processor()

            if result.get('success'):
                logger.info(f"✅ 批次處理退款完成: 成功 {result.get('succeeded')}/{result.get('processed')} 筆")
            else:
                logger.error(f"❌ 批次處理退款失敗: {result.get('error')}")

        except Exception as e:
            logger.error(f"❌ 執行批次處理退款任務時發生異常: {str(e)}")


# 創建全局調度器實例
scheduler_service = SchedulerService()
