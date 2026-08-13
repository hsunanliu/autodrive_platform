"""
Identity Schemas - DID and Credential Verification
"""
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


class DIDRegistrationRequest(BaseModel):
    """DID 註冊請求"""
    did: str = Field(..., description="DID 字符串，格式：did:sui:<address>")
    did_document: dict = Field(..., description="DID 文檔（JSON 對象）")


class DIDRegistrationResponse(BaseModel):
    """DID 註冊響應"""
    success: bool
    did: str
    message: str


class CredentialVerificationRequest(BaseModel):
    """憑證驗證請求（ZKP）"""
    proof: str = Field(..., description="ZKP 證明（hex 編碼）")
    public_signals: List[int] = Field(..., description="公開信號")
    commitment: str = Field(..., description="憑證承諾值（防止重複使用）")


class CredentialVerificationResponse(BaseModel):
    """憑證驗證響應"""
    success: bool
    credential_type: str = Field(..., description="憑證類型：age, license, etc.")
    verified: bool
    message: str


class DIDInfoResponse(BaseModel):
    """用戶 DID 信息響應"""
    did: Optional[str] = Field(None, description="用戶的 DID")
    age_verified: bool = Field(False, description="是否已驗證年齡")
    license_verified: bool = Field(False, description="是否已驗證駕照")
    created_at: datetime

    class Config:
        from_attributes = True
