# backend/app/models/credential.py
"""
UserCredential 資料庫模型
存儲用戶的 ZKP 憑證（年齡驗證、駕照驗證等）
"""
from sqlalchemy import Column, Integer, String, Boolean, DateTime, Text, ForeignKey, Enum as SQLEnum
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base
import enum


class CredentialType(str, enum.Enum):
    """憑證類型"""
    AGE = "age"
    LICENSE = "license"


class CredentialStatus(str, enum.Enum):
    """憑證狀態"""
    PENDING = "pending"      # 待驗證
    VERIFIED = "verified"    # 已驗證
    EXPIRED = "expired"      # 已過期
    REVOKED = "revoked"      # 已撤銷


class UserCredential(Base):
    """
    用戶憑證模型 - 存儲 ZKP 證明

    用於存儲用戶通過零知識證明驗證的憑證，
    如年齡驗證、駕照驗證等。
    """
    __tablename__ = "user_credentials"

    # === 主鍵 ===
    id = Column(Integer, primary_key=True, index=True, comment="憑證 ID")

    # === 關聯 ===
    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="用戶 ID"
    )

    # === 憑證類型與狀態 ===
    credential_type = Column(
        SQLEnum(CredentialType),
        nullable=False,
        comment="憑證類型：age（年齡）、license（駕照）"
    )

    status = Column(
        SQLEnum(CredentialStatus),
        default=CredentialStatus.VERIFIED,
        nullable=False,
        comment="憑證狀態"
    )

    # === ZKP 證明數據 ===
    proof_json = Column(
        Text,
        nullable=True,
        comment="Groth16 證明（JSON 格式）"
    )

    public_signals = Column(
        Text,
        nullable=True,
        comment="公開信號（JSON 數組格式）"
    )

    did_commitment = Column(
        String(255),
        nullable=True,
        comment="DID 承諾值（來自 ZKP 公開信號）"
    )

    nullifier = Column(
        String(130),
        nullable=True,
        unique=True,
        index=True,
        comment="一次性 commitment/nullifier（唯一）；防 ZKP 重放，見 core/commitment.py"
    )

    # === 驗證結果 ===
    is_valid = Column(
        Boolean,
        default=False,
        nullable=False,
        comment="驗證結果是否有效"
    )

    # === 模擬模式標記 ===
    is_simulated = Column(
        Boolean,
        default=False,
        nullable=False,
        comment="是否為模擬證明（非真實 snarkjs 生成）"
    )

    # === 元數據 ===
    # 年齡驗證專用
    min_age_verified = Column(
        Integer,
        nullable=True,
        comment="驗證的最小年齡（如 18）"
    )

    # 駕照驗證專用
    license_type_verified = Column(
        Integer,
        nullable=True,
        comment="驗證的駕照類型（1=普通, 2=機車, 3=商用）"
    )

    # === 時間戳記 ===
    verified_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        comment="驗證時間"
    )

    expires_at = Column(
        DateTime(timezone=True),
        nullable=True,
        comment="憑證過期時間"
    )

    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        comment="創建時間"
    )

    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        comment="更新時間"
    )

    # === 關係 ===
    # user = relationship("User", back_populates="credentials")

    def __repr__(self):
        return f"<UserCredential(id={self.id}, user_id={self.user_id}, type={self.credential_type}, status={self.status})>"

    # === 業務邏輯方法 ===

    @property
    def is_active(self) -> bool:
        """憑證是否有效（已驗證且未過期）"""
        from datetime import datetime, timezone
        if self.status != CredentialStatus.VERIFIED:
            return False
        if self.expires_at and self.expires_at < datetime.now(timezone.utc):
            return False
        return True

    def to_dict(self) -> dict:
        """轉換為字典"""
        return {
            "id": self.id,
            "user_id": self.user_id,
            "credential_type": self.credential_type.value if self.credential_type else None,
            "status": self.status.value if self.status else None,
            "is_valid": self.is_valid,
            "is_simulated": self.is_simulated,
            "min_age_verified": self.min_age_verified,
            "license_type_verified": self.license_type_verified,
            "verified_at": self.verified_at.isoformat() if self.verified_at else None,
            "expires_at": self.expires_at.isoformat() if self.expires_at else None,
        }
