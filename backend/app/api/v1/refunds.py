# backend/app/api/v1/refunds.py
"""
退款 API - 處理已完成行程的退款（實際上鏈）
"""

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel, Field
from typing import Optional
import logging

from app.core.database import get_async_session
from app.services.refund_service_v2 import RefundServiceV2
from app.services.ipfs_service import ipfs_service, log_ipfs_upload
from app.api.deps import get_current_user
from app.models import User

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/refunds", tags=["refunds"])


class RefundRequestCreate(BaseModel):
    """創建退款請求"""
    trip_id: int = Field(..., description="行程 ID")
    reason: str = Field(..., min_length=10, max_length=500, description="退款原因（至少 10 個字）")
    refund_amount_sui: float = Field(..., gt=0, description="退款金額（SUI）")


class RefundApproval(BaseModel):
    """批准退款"""
    admin_note: Optional[str] = Field(None, max_length=500, description="管理員備註")


class RefundRejection(BaseModel):
    """拒絕退款"""
    admin_note: str = Field(..., min_length=10, max_length=500, description="拒絕原因（至少 10 個字）")


@router.post("/create")
async def create_refund_request(
    trip_id: int = Form(..., description="行程 ID"),
    reason: str = Form(..., min_length=10, description="退款原因"),
    refund_amount_sui: float = Form(..., gt=0, description="退款金額（SUI）"),
    evidence_file: Optional[UploadFile] = File(None, description="退款證據（選填）"),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_async_session)
):
    """
    創建退款請求（乘客端）

    - 行程必須已完成
    - 必須有 escrow_object_id
    - 只有乘客可以申請退款
    - 退款金額不能超過原始支付金額
    - 可選擇上傳退款證據（圖片、PDF 等）
    """
    service = RefundServiceV2(session)

    try:
        # 處理 IPFS 上傳（如果有證據文件）
        evidence_cid = None
        evidence_hash = None
        evidence_filename = None
        evidence_content_type = None

        if evidence_file:
            # 驗證文件大小（最大 10MB）
            MAX_FILE_SIZE = 10 * 1024 * 1024
            file_content = await evidence_file.read()

            if len(file_content) > MAX_FILE_SIZE:
                raise HTTPException(
                    status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                    detail=f"證據文件過大，最大允許 10 MB"
                )

            # 驗證文件類型
            allowed_types = [
                'image/jpeg', 'image/png', 'image/gif', 'image/webp',
                'application/pdf',
                'text/plain'
            ]

            if evidence_file.content_type not in allowed_types:
                raise HTTPException(
                    status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
                    detail=f"不支援的文件類型: {evidence_file.content_type}"
                )

            # 上傳到 IPFS
            metadata = {
                "uploaded_by": current_user.id,
                "username": current_user.username,
                "purpose": "refund_evidence",
                "trip_id": trip_id,
                "content_type": evidence_file.content_type
            }

            ipfs_result = await ipfs_service.upload_file(
                file_content=file_content,
                filename=evidence_file.filename or "refund_evidence",
                metadata=metadata
            )

            if not ipfs_result['success']:
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail=f"證據上傳失敗: {ipfs_result.get('error', '未知錯誤')}"
                )

            evidence_cid = ipfs_result['cid']
            evidence_hash = ipfs_result['hash']
            evidence_filename = evidence_file.filename
            evidence_content_type = evidence_file.content_type

            # 記錄審計日誌
            log_ipfs_upload(
                cid=evidence_cid,
                filename=evidence_filename,
                uploaded_by=current_user.id,
                purpose="refund_evidence",
                related_id=trip_id
            )

            logger.info(f"✅ 退款證據已上傳到 IPFS: {evidence_cid}")

        # 創建並執行退款（嘗試鏈上退款）
        result = await service.create_and_execute_refund(
            trip_id=trip_id,
            user_id=current_user.id,
            reason=reason,
            refund_amount_sui=refund_amount_sui,
            evidence_cid=evidence_cid,
            evidence_hash=evidence_hash,
            evidence_filename=evidence_filename,
            evidence_content_type=evidence_content_type
        )

        if result["success"]:
            return {
                "success": True,
                "data": result,
                "evidence_ipfs_url": f"http://localhost:8080/ipfs/{evidence_cid}" if evidence_cid else None
            }
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=result["error"]
            )

    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"❌ 創建退款請求失敗: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"創建退款請求失敗: {str(e)}"
        )


@router.post("/{refund_request_id}/approve")
async def approve_refund(
    refund_request_id: int,
    approval_data: RefundApproval,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_async_session)
):
    """
    批准退款並執行鏈上轉帳（管理員端）

    - 僅管理員可調用
    - 退款請求必須為 pending 狀態
    - 執行鏈上退款交易
    """
    # TODO: 添加管理員權限驗證
    # if not current_user.is_admin:
    #     raise HTTPException(status_code=403, detail="需要管理員權限")

    service = RefundServiceV2(session)

    try:
        result = await service.approve_and_execute_refund(
            refund_request_id=refund_request_id,
            admin_note=approval_data.admin_note
        )

        if result["success"]:
            return {
                "success": True,
                "data": result
            }
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=result["error"]
            )

    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"批准退款失敗: {str(e)}"
        )


@router.post("/{refund_request_id}/reject")
async def reject_refund(
    refund_request_id: int,
    rejection_data: RefundRejection,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_async_session)
):
    """
    拒絕退款請求（管理員端）

    - 僅管理員可調用
    - 退款請求必須為 pending 狀態
    """
    # TODO: 添加管理員權限驗證

    service = RefundServiceV2(session)

    try:
        result = await service.reject_refund(
            refund_request_id=refund_request_id,
            admin_note=rejection_data.admin_note
        )

        if result["success"]:
            return {
                "success": True,
                "data": result
            }
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=result["error"]
            )

    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"拒絕退款失敗: {str(e)}"
        )
