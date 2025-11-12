#!/usr/bin/env python3
"""
批次處理待處理的退款請求
定期運行，將 pending_blockchain 狀態的退款提交到智能合約
"""

import os
import sys
import asyncio
import logging
from datetime import datetime
from typing import List

# 添加父目錄到 Python 路徑，以便導入 app 模組
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

from app.models import RefundRequest
from app.services.sui_client import SuiBlockchainClient
from app.config import settings

# 配置日誌
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class RefundBatchProcessor:
    """批次退款處理器"""

    def __init__(self, session: AsyncSession):
        self.session = session
        self.sui_client = SuiBlockchainClient()

    async def get_pending_refunds(self) -> List[RefundRequest]:
        """獲取待處理的退款請求"""
        query = select(RefundRequest).where(
            and_(
                RefundRequest.status == 'pending_blockchain',
                RefundRequest.refund_request_object_id.isnot(None),
                RefundRequest.escrow_object_id.isnot(None)
            )
        ).order_by(RefundRequest.created_at.asc())

        result = await self.session.execute(query)
        refunds = result.scalars().all()

        logger.info(f"📋 找到 {len(refunds)} 筆待處理的退款請求")
        return refunds

    async def process_single_refund(self, refund: RefundRequest) -> bool:
        """處理單筆退款"""
        try:
            logger.info(f"💸 開始處理退款: ID={refund.id}, Trip={refund.trip_id}, Amount={refund.refund_amount_sui} SUI")

            # 檢查必要資訊
            if not refund.refund_request_object_id:
                logger.error(f"❌ 退款 {refund.id} 缺少 refund_request_object_id")
                return False

            if not settings.REFUND_POOL_ID:
                logger.error(f"❌ REFUND_POOL_ID 未配置")
                return False

            # 調用智能合約執行退款
            result = self.sui_client.approve_and_execute_refund(
                refund_request_object_id=refund.refund_request_object_id,
                refund_pool_id=settings.REFUND_POOL_ID,
                platform_address=settings.PLATFORM_WALLET_ADDRESS,
                private_key=settings.OPERATOR_PRIVATE_KEY
            )

            if result and result.get('success'):
                # 更新資料庫狀態
                refund.status = 'approved'
                refund.blockchain_tx_hash = result.get('transaction_hash')
                refund.processed_at = datetime.utcnow()

                await self.session.commit()

                logger.info(f"✅ 退款 {refund.id} 處理成功!")
                logger.info(f"   交易哈希: {result.get('transaction_hash')}")
                return True
            else:
                error_msg = result.get('error', '未知錯誤') if result else '無返回結果'
                logger.error(f"❌ 退款 {refund.id} 處理失敗: {error_msg}")

                # 更新失敗狀態（但保持 pending_blockchain，等待下次重試）
                refund.admin_note = f"批次處理失敗: {error_msg}"
                await self.session.commit()

                return False

        except Exception as e:
            logger.error(f"❌ 處理退款 {refund.id} 時發生異常: {str(e)}")
            return False

    async def process_all_pending_refunds(self) -> dict:
        """處理所有待處理的退款"""
        start_time = datetime.utcnow()

        # 檢查 Sui 客戶端是否可用
        if not self.sui_client.is_available():
            logger.warning("⚠️ Sui 客戶端不可用，跳過批次處理")
            return {
                'success': False,
                'error': 'Sui 客戶端不可用'
            }

        # 獲取待處理的退款
        pending_refunds = await self.get_pending_refunds()

        if not pending_refunds:
            logger.info("✅ 沒有待處理的退款請求")
            return {
                'success': True,
                'processed': 0,
                'succeeded': 0,
                'failed': 0
            }

        # 處理每筆退款
        succeeded = 0
        failed = 0

        for refund in pending_refunds:
            success = await self.process_single_refund(refund)
            if success:
                succeeded += 1
            else:
                failed += 1

            # 避免過快調用，休息 1 秒
            await asyncio.sleep(1)

        # 計算處理時間
        duration = (datetime.utcnow() - start_time).total_seconds()

        logger.info(f"")
        logger.info(f"{'='*60}")
        logger.info(f"📊 批次處理完成!")
        logger.info(f"   總計: {len(pending_refunds)} 筆")
        logger.info(f"   成功: {succeeded} 筆")
        logger.info(f"   失敗: {failed} 筆")
        logger.info(f"   耗時: {duration:.2f} 秒")
        logger.info(f"{'='*60}")
        logger.info(f"")

        return {
            'success': True,
            'processed': len(pending_refunds),
            'succeeded': succeeded,
            'failed': failed,
            'duration_seconds': duration
        }


async def run_batch_processor():
    """運行批次處理器（主函數）"""
    logger.info("🚀 啟動退款批次處理器...")

    # 創建資料庫連接
    engine = create_async_engine(
        settings.DATABASE_URL,
        echo=False,
        pool_pre_ping=True,
    )

    async_session = sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False
    )

    async with async_session() as session:
        processor = RefundBatchProcessor(session)
        result = await processor.process_all_pending_refunds()

    await engine.dispose()

    return result


if __name__ == "__main__":
    # 直接運行腳本
    try:
        result = asyncio.run(run_batch_processor())

        if result.get('success'):
            sys.exit(0)
        else:
            sys.exit(1)

    except Exception as e:
        logger.error(f"❌ 批次處理器執行失敗: {str(e)}")
        sys.exit(1)
