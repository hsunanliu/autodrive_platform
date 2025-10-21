# backend/app/api/v1/wallet.py
"""
錢包管理 API
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any

from app.api.deps import get_async_session, get_current_user
from app.models.user import User
from app.services.wallet_service import wallet_service
import logging

logger = logging.getLogger(__name__)

router = APIRouter()


# ============================================================================
# Pydantic Models
# ============================================================================

class CreateWalletRequest(BaseModel):
    """創建錢包請求"""
    password: str = Field(..., min_length=8, description="錢包密碼（至少8位）")


class ImportWalletRequest(BaseModel):
    """導入錢包請求"""
    mnemonic: str = Field(..., description="助記詞（12個單詞）")
    password: str = Field(..., min_length=8, description="錢包密碼")


class SignTransactionRequest(BaseModel):
    """簽署交易請求"""
    password: str = Field(..., description="錢包密碼")
    transaction: Dict[str, Any] = Field(..., description="交易數據")


class WalletResponse(BaseModel):
    """錢包響應"""
    success: bool
    address: Optional[str] = None
    public_key: Optional[str] = None
    mnemonic: Optional[str] = None
    error: Optional[str] = None


class BalanceResponse(BaseModel):
    """餘額響應"""
    success: bool
    balance_sui: float
    balance_mist: int
    address: str
    error: Optional[str] = None


# ============================================================================
# API Endpoints
# ============================================================================

@router.post("/create", response_model=WalletResponse)
async def create_wallet(
    request: CreateWalletRequest
):
    """
    創建新錢包（無需認證）
    
    - 創建一個新的 Sui 錢包
    - 私鑰使用用戶密碼加密
    - 返回助記詞（僅此一次，請用戶備份）
    - 此端點用於註冊流程，不需要用戶已登入
    """
    try:
        # 創建錢包
        result = await wallet_service.create_wallet(request.password)
        
        if not result['success']:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=result.get('error', '創建錢包失敗')
            )
        
        logger.info(f"創建錢包成功: {result['address']}")
        
        return WalletResponse(
            success=True,
            address=result['address'],
            public_key=result['public_key'],
            mnemonic=result['mnemonic'],  # 僅返回一次
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"創建錢包失敗: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"創建錢包失敗: {str(e)}"
        )


@router.post("/create-for-user", response_model=WalletResponse)
async def create_wallet_for_user(
    request: CreateWalletRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_session)
):
    """
    為已登入用戶創建錢包
    
    - 為當前用戶創建一個新的 Sui 錢包
    - 私鑰使用用戶密碼加密存儲
    - 返回助記詞（僅此一次，請用戶備份）
    """
    try:
        # 檢查用戶是否已有錢包
        if current_user.wallet_address:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="用戶已有錢包"
            )
        
        # 創建錢包
        result = await wallet_service.create_wallet(request.password)
        
        if not result['success']:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=result.get('error', '創建錢包失敗')
            )
        
        # 更新用戶信息
        current_user.wallet_address = result['address']
        current_user.public_key = result['public_key']
        current_user.encrypted_private_key = result['encrypted_private_key']
        
        await db.commit()
        
        logger.info(f"用戶 {current_user.id} 創建錢包成功: {result['address']}")
        
        return WalletResponse(
            success=True,
            address=result['address'],
            public_key=result['public_key'],
            mnemonic=result['mnemonic'],  # 僅返回一次
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"創建錢包失敗: {str(e)}")
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"創建錢包失敗: {str(e)}"
        )


@router.post("/import", response_model=WalletResponse)
async def import_wallet(
    request: ImportWalletRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_session)
):
    """
    導入錢包
    
    - 使用助記詞導入現有錢包
    - 私鑰使用用戶密碼加密存儲
    """
    try:
        # 檢查用戶是否已有錢包
        if current_user.wallet_address:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="用戶已有錢包，請先刪除現有錢包"
            )
        
        # 導入錢包
        result = await wallet_service.import_wallet(
            request.mnemonic,
            request.password
        )
        
        if not result['success']:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=result.get('error', '導入錢包失敗')
            )
        
        # 更新用戶信息
        current_user.wallet_address = result['address']
        current_user.public_key = result['public_key']
        current_user.encrypted_private_key = result['encrypted_private_key']
        
        await db.commit()
        
        logger.info(f"用戶 {current_user.id} 導入錢包成功: {result['address']}")
        
        return WalletResponse(
            success=True,
            address=result['address'],
            public_key=result['public_key'],
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"導入錢包失敗: {str(e)}")
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"導入錢包失敗: {str(e)}"
        )


@router.get("/balance", response_model=BalanceResponse)
async def get_balance(
    current_user: User = Depends(get_current_user)
):
    """
    查詢錢包餘額
    
    - 查詢當前用戶的 Sui 錢包餘額
    """
    try:
        if not current_user.wallet_address:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="用戶尚未創建錢包"
            )
        
        # 查詢餘額
        result = await wallet_service.get_balance(current_user.wallet_address)
        
        return BalanceResponse(
            success=result['success'],
            balance_sui=result['balance_sui'],
            balance_mist=result['balance_mist'],
            address=current_user.wallet_address,
            error=result.get('error'),
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"查詢餘額失敗: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"查詢餘額失敗: {str(e)}"
        )


@router.post("/sign-transaction")
async def sign_transaction(
    request: SignTransactionRequest,
    current_user: User = Depends(get_current_user)
):
    """
    簽署並執行交易
    
    - 使用用戶的私鑰簽署交易
    - 需要提供密碼解密私鑰
    """
    try:
        if not current_user.wallet_address:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="用戶尚未創建錢包"
            )
        
        if not current_user.encrypted_private_key:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="錢包數據不完整"
            )
        
        # 簽署交易
        result = await wallet_service.sign_and_execute_transaction(
            current_user.encrypted_private_key,
            request.password,
            request.transaction
        )
        
        if not result['success']:
            if '密碼錯誤' in result.get('error', ''):
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="密碼錯誤"
                )
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=result.get('error', '簽署交易失敗')
            )
        
        logger.info(f"用戶 {current_user.id} 簽署交易成功: {result['transaction_digest']}")
        
        return {
            'success': True,
            'transaction_digest': result['transaction_digest'],
            'effects': result['effects'],
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"簽署交易失敗: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"簽署交易失敗: {str(e)}"
        )


@router.get("/info")
async def get_wallet_info(
    current_user: User = Depends(get_current_user)
):
    """
    獲取錢包信息
    
    - 返回當前用戶的錢包地址和公鑰
    - 不返回私鑰
    """
    if not current_user.wallet_address:
        return {
            'has_wallet': False,
            'address': None,
            'public_key': None,
        }
    
    return {
        'has_wallet': True,
        'address': current_user.wallet_address,
        'public_key': current_user.public_key,
    }
