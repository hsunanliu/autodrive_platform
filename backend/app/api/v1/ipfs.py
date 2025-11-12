# backend/app/api/v1/ipfs.py
"""
IPFS API - 處理文件上傳與檢索

功能：
1. 上傳退款證據到 IPFS
2. 檢索 IPFS 文件
3. 驗證文件完整性
4. 管理固定的文件
"""

from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, status, Form
from fastapi.responses import Response
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel, Field
from typing import Optional, List
import logging

from app.core.database import get_async_session
from app.services.ipfs_service import ipfs_service, log_ipfs_upload
from app.api.deps import get_current_user
from app.models import User

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ipfs", tags=["ipfs"])


class IPFSUploadResponse(BaseModel):
    """IPFS 上傳回應"""
    success: bool
    cid: Optional[str] = None
    size: Optional[int] = None
    filename: Optional[str] = None
    hash: Optional[str] = None
    ipfs_url: Optional[str] = None
    uploaded_at: Optional[str] = None
    error: Optional[str] = None


class IPFSFileInfo(BaseModel):
    """IPFS 文件資訊"""
    cid: str
    size: int
    filename: Optional[str] = None
    uploaded_by: Optional[int] = None
    purpose: Optional[str] = None


@router.post("/upload", response_model=IPFSUploadResponse)
async def upload_to_ipfs(
    file: UploadFile = File(..., description="要上傳的文件"),
    purpose: str = Form(..., description="用途（refund_evidence, service_proof, etc.）"),
    related_id: Optional[int] = Form(None, description="關聯 ID（例如：退款請求 ID）"),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_async_session)
):
    """
    上傳文件到 IPFS

    - **file**: 要上傳的文件（支援圖片、PDF、文本等）
    - **purpose**: 用途（refund_evidence, service_proof, trip_photo, etc.）
    - **related_id**: 關聯記錄 ID（選填）

    返回 IPFS CID（內容標識符）
    """
    try:
        # 驗證文件大小（最大 10MB）
        MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB
        file_content = await file.read()

        if len(file_content) > MAX_FILE_SIZE:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"文件過大，最大允許 {MAX_FILE_SIZE / 1024 / 1024} MB"
            )

        # 驗證文件類型
        allowed_types = [
            'image/jpeg', 'image/png', 'image/gif', 'image/webp',
            'application/pdf',
            'text/plain'
        ]

        if file.content_type not in allowed_types:
            raise HTTPException(
                status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
                detail=f"不支援的文件類型: {file.content_type}"
            )

        # 上傳到 IPFS
        metadata = {
            "uploaded_by": current_user.id,
            "username": current_user.username,
            "purpose": purpose,
            "related_id": related_id,
            "content_type": file.content_type
        }

        result = await ipfs_service.upload_file(
            file_content=file_content,
            filename=file.filename or "unnamed",
            metadata=metadata
        )

        if not result['success']:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=result.get('error', '上傳失敗')
            )

        # 記錄審計日誌
        log_ipfs_upload(
            cid=result['cid'],
            filename=file.filename or "unnamed",
            uploaded_by=current_user.id,
            purpose=purpose,
            related_id=related_id
        )

        logger.info(f"✅ 用戶 {current_user.username} 上傳文件到 IPFS: {result['cid']}")

        return IPFSUploadResponse(**result)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ IPFS 上傳失敗: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"上傳失敗: {str(e)}"
        )


@router.get("/retrieve/{cid}")
async def retrieve_from_ipfs(
    cid: str,
    current_user: User = Depends(get_current_user)
):
    """
    從 IPFS 檢索文件

    - **cid**: IPFS 內容標識符

    返回文件內容（二進制）
    """
    try:
        result = await ipfs_service.retrieve_file(cid)

        if not result['success']:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=result.get('error', '文件不存在')
            )

        # 返回文件內容
        return Response(
            content=result['content'],
            media_type="application/octet-stream",
            headers={
                "Content-Disposition": f"attachment; filename={cid}"
            }
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ IPFS 檢索失敗: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"檢索失敗: {str(e)}"
        )


@router.get("/info/{cid}")
async def get_ipfs_file_info(
    cid: str,
    current_user: User = Depends(get_current_user)
):
    """
    獲取 IPFS 文件資訊

    - **cid**: IPFS 內容標識符

    返回文件大小、類型等資訊
    """
    try:
        result = await ipfs_service.get_file_info(cid)

        if not result['success']:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=result.get('error', '文件不存在')
            )

        return {
            "success": True,
            "data": result
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ 獲取文件資訊失敗: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"獲取資訊失敗: {str(e)}"
        )


@router.post("/verify/{cid}")
async def verify_ipfs_file(
    cid: str,
    expected_hash: str = Form(..., description="預期的 SHA256 雜湊值"),
    current_user: User = Depends(get_current_user)
):
    """
    驗證 IPFS 文件完整性

    - **cid**: IPFS 內容標識符
    - **expected_hash**: 預期的 SHA256 雜湊值

    返回驗證結果
    """
    try:
        is_valid = await ipfs_service.verify_file(cid, expected_hash)

        return {
            "success": True,
            "cid": cid,
            "valid": is_valid,
            "message": "文件完整性驗證通過" if is_valid else "文件已被篡改或損壞"
        }

    except Exception as e:
        logger.error(f"❌ 文件驗證失敗: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"驗證失敗: {str(e)}"
        )


@router.post("/pin/{cid}")
async def pin_ipfs_file(
    cid: str,
    current_user: User = Depends(get_current_user)
):
    """
    固定 IPFS 文件（防止垃圾回收）

    僅管理員可用
    """
    # TODO: 添加管理員權限檢查
    # if not current_user.is_admin:
    #     raise HTTPException(status_code=403, detail="需要管理員權限")

    try:
        result = await ipfs_service.pin_file(cid)

        if not result['success']:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=result.get('error', '固定失敗')
            )

        return {
            "success": True,
            "cid": result['cid'],
            "message": "文件已固定"
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ 固定文件失敗: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"固定失敗: {str(e)}"
        )


@router.delete("/unpin/{cid}")
async def unpin_ipfs_file(
    cid: str,
    current_user: User = Depends(get_current_user)
):
    """
    取消固定 IPFS 文件（允許垃圾回收）

    僅管理員可用
    """
    # TODO: 添加管理員權限檢查

    try:
        result = await ipfs_service.unpin_file(cid)

        if not result['success']:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=result.get('error', '取消固定失敗')
            )

        return {
            "success": True,
            "cid": cid,
            "message": "已取消固定"
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ 取消固定失敗: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"取消固定失敗: {str(e)}"
        )
