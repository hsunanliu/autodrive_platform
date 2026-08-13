"""
Identity API - DID and Credential Verification
DID（去中心化身份標識符）和憑證驗證 API
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional
import logging

from app.core.database import get_async_session
from app.models.user import User
from app.schemas.identity import (
    DIDRegistrationRequest,
    DIDRegistrationResponse,
    CredentialVerificationRequest,
    CredentialVerificationResponse,
    DIDInfoResponse,
)
from app.services.identity_service import IdentityService
from app.api.deps import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter()

@router.post("/register-did", response_model=DIDRegistrationResponse)
async def register_did(
    request: DIDRegistrationRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_session)
):
    """
    註冊用戶的 DID

    用戶在移動端創建 DID 後，將 DID 與帳號關聯
    """
    try:
        identity_service = IdentityService(db)

        # 檢查用戶是否已註冊 DID
        if current_user.did:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User already has a DID registered"
            )

        # 註冊 DID（更新用戶記錄）
        result = await identity_service.register_did(
            user_id=current_user.id,
            did=request.did,
            did_document=request.did_document
        )

        logger.info(f"✅ DID registered for user {current_user.id}: {request.did}")

        return DIDRegistrationResponse(
            success=True,
            did=result['did'],
            message="DID registered successfully"
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Failed to register DID for user {current_user.id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to register DID: {str(e)}"
        )


@router.post("/verify-age", response_model=CredentialVerificationResponse)
async def verify_age_credential(
    request: CredentialVerificationRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_session)
):
    """
    驗證用戶年齡憑證（ZKP）

    用戶提交 ZKP 證明，證明年齡 >= 18 歲而不揭露實際出生日期
    """
    try:
        identity_service = IdentityService(db)

        # 檢查用戶是否有 DID
        if not current_user.did:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User must register DID first"
            )

        # 驗證年齡 ZKP
        result = await identity_service.verify_age_credential(
            user_id=current_user.id,
            did=current_user.did,
            proof=request.proof,
            public_signals=request.public_signals,
            commitment=request.commitment
        )

        if result['valid']:
            # 更新用戶的驗證狀態
            current_user.age_verified = True
            await db.commit()

            logger.info(f"✅ Age verified for user {current_user.id}")

            return CredentialVerificationResponse(
                success=True,
                credential_type="age",
                verified=True,
                message="Age credential verified successfully"
            )
        else:
            logger.warning(f"⚠️ Age verification failed for user {current_user.id}")

            return CredentialVerificationResponse(
                success=False,
                credential_type="age",
                verified=False,
                message=result.get('error', 'Verification failed')
            )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Failed to verify age for user {current_user.id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to verify age credential: {str(e)}"
        )


@router.post("/verify-license", response_model=CredentialVerificationResponse)
async def verify_license_credential(
    request: CredentialVerificationRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_session)
):
    """
    驗證司機駕照憑證（ZKP）

    司機提交 ZKP 證明，證明持有有效駕照而不揭露駕照號碼
    """
    try:
        identity_service = IdentityService(db)

        # 檢查用戶是否有 DID
        if not current_user.did:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User must register DID first"
            )

        # 檢查用戶是否為司機
        if not current_user.is_driver:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only drivers can verify license"
            )

        # 驗證駕照 ZKP
        result = await identity_service.verify_license_credential(
            user_id=current_user.id,
            did=current_user.did,
            proof=request.proof,
            public_signals=request.public_signals,
            commitment=request.commitment
        )

        if result['valid']:
            # 更新司機的驗證狀態
            current_user.license_verified = True
            await db.commit()

            logger.info(f"✅ Driver license verified for user {current_user.id}")

            return CredentialVerificationResponse(
                success=True,
                credential_type="license",
                verified=True,
                message="Driver license verified successfully"
            )
        else:
            logger.warning(f"⚠️ License verification failed for user {current_user.id}")

            return CredentialVerificationResponse(
                success=False,
                credential_type="license",
                verified=False,
                message=result.get('error', 'Verification failed')
            )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Failed to verify license for user {current_user.id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to verify license credential: {str(e)}"
        )


@router.get("/did-info", response_model=DIDInfoResponse)
async def get_did_info(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_session)
):
    """
    獲取用戶的 DID 和驗證狀態
    """
    try:
        return DIDInfoResponse(
            did=current_user.did,
            age_verified=current_user.age_verified or False,
            license_verified=current_user.license_verified or False,
            created_at=current_user.created_at
        )

    except Exception as e:
        logger.error(f"❌ Failed to get DID info for user {current_user.id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get DID info: {str(e)}"
        )


from pydantic import BaseModel

class AgeProofRequest(BaseModel):
    birth_year: int
    birth_month: int
    birth_day: int
    min_age: int = 18

class LicenseProofRequest(BaseModel):
    license_number: str
    expiry_year: int
    expiry_month: int
    expiry_day: int
    license_type: int = 1


@router.post("/generate-age-proof")
async def generate_and_verify_age(
    request: AgeProofRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_session)
):
    """
    生成年齡證明並存儲憑證（一站式服務）

    用戶提交出生日期，後端生成 ZKP 證明並存儲憑證
    """
    from datetime import datetime, timezone, timedelta
    import json
    from app.services.zkp_prover import get_zkp_prover, compute_did_hash
    from app.models.credential import UserCredential, CredentialType, CredentialStatus

    try:
        # 1. 確保用戶有 DID，如果沒有則自動創建
        if not current_user.did:
            wallet = current_user.wallet_address.lower()
            if wallet.startswith("0x"):
                wallet = wallet[2:]
            did = f"did:sui:0x{wallet}"

            did_document = {
                "@context": ["https://www.w3.org/ns/did/v1"],
                "id": did,
                "controller": did,
                "verificationMethod": [{
                    "id": f"{did}#key-1",
                    "type": "EcdsaSecp256k1VerificationKey2019",
                    "controller": did,
                    "blockchainAccountId": f"eip155:1:{current_user.wallet_address}"
                }],
                "authentication": [f"{did}#key-1"],
                "created": datetime.now(timezone.utc).isoformat()
            }

            current_user.did = did
            current_user.did_document = json.dumps(did_document)
            await db.commit()
            logger.info(f"Auto-created DID for user {current_user.id}: {did}")

        # 2. 生成 ZKP 證明
        prover = get_zkp_prover()
        did_hash = compute_did_hash(current_user.did)

        result = prover.generate_age_proof(
            birth_year=request.birth_year,
            birth_month=request.birth_month,
            birth_day=request.birth_day,
            min_age=request.min_age,
            did_hash=did_hash
        )

        if not result.get("valid"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=result.get("error", "Age proof generation failed")
            )

        public_signals = result.get("publicSignals", [])
        is_age_valid = len(public_signals) > 0 and public_signals[0] == 1

        if not is_age_valid:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Age does not meet minimum requirement"
            )

        # 3. 存儲憑證
        # 刪除舊憑證
        from sqlalchemy import delete
        await db.execute(
            delete(UserCredential).where(
                UserCredential.user_id == current_user.id,
                UserCredential.credential_type == CredentialType.AGE
            )
        )

        credential = UserCredential(
            user_id=current_user.id,
            credential_type=CredentialType.AGE,
            status=CredentialStatus.VERIFIED,
            proof_json=json.dumps(result.get("proof")),
            public_signals=json.dumps(public_signals),
            did_commitment=str(public_signals[1]) if len(public_signals) > 1 else None,
            is_valid=True,
            is_simulated=result.get("simulated", False),
            min_age_verified=request.min_age,
            verified_at=datetime.now(timezone.utc),
            expires_at=datetime.now(timezone.utc) + timedelta(days=365)
        )
        db.add(credential)

        # 4. 更新用戶狀態
        current_user.age_verified = True
        await db.commit()

        logger.info(f"✅ Age proof generated and stored for user {current_user.id}")

        return {
            "success": True,
            "credential_type": "age",
            "is_valid": True,
            "is_simulated": result.get("simulated", False),
            "min_age_verified": request.min_age,
            "did": current_user.did
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Failed to generate age proof: {str(e)}")
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.post("/generate-license-proof")
async def generate_and_verify_license(
    request: LicenseProofRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_session)
):
    """
    生成駕照證明並存儲憑證（一站式服務）

    司機提交駕照資訊，後端生成 ZKP 證明並存儲憑證
    """
    from datetime import datetime, timezone
    import json
    from app.services.zkp_prover import get_zkp_prover, compute_did_hash, compute_license_hash
    from app.models.credential import UserCredential, CredentialType, CredentialStatus

    try:
        # 1. 確保用戶是司機
        if not current_user.is_driver:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only drivers can verify license"
            )

        # 2. 確保用戶有 DID
        if not current_user.did:
            wallet = current_user.wallet_address.lower()
            if wallet.startswith("0x"):
                wallet = wallet[2:]
            did = f"did:sui:0x{wallet}"

            did_document = {
                "@context": ["https://www.w3.org/ns/did/v1"],
                "id": did,
                "controller": did,
                "created": datetime.now(timezone.utc).isoformat()
            }

            current_user.did = did
            current_user.did_document = json.dumps(did_document)
            await db.commit()

        # 3. 生成 ZKP 證明
        prover = get_zkp_prover()
        did_hash = compute_did_hash(current_user.did)
        license_hash = compute_license_hash(request.license_number)

        result = prover.generate_license_proof(
            license_hash=license_hash,
            expiry_year=request.expiry_year,
            expiry_month=request.expiry_month,
            expiry_day=request.expiry_day,
            license_type=request.license_type,
            required_type=1,
            did_hash=did_hash
        )

        if not result.get("valid"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=result.get("error", "License proof generation failed")
            )

        public_signals = result.get("publicSignals", [])
        is_license_valid = len(public_signals) > 0 and public_signals[0] == 1

        if not is_license_valid:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="License is expired or invalid"
            )

        # 4. 存儲憑證
        from sqlalchemy import delete
        await db.execute(
            delete(UserCredential).where(
                UserCredential.user_id == current_user.id,
                UserCredential.credential_type == CredentialType.LICENSE
            )
        )

        credential = UserCredential(
            user_id=current_user.id,
            credential_type=CredentialType.LICENSE,
            status=CredentialStatus.VERIFIED,
            proof_json=json.dumps(result.get("proof")),
            public_signals=json.dumps(public_signals),
            did_commitment=str(public_signals[1]) if len(public_signals) > 1 else None,
            is_valid=True,
            is_simulated=result.get("simulated", False),
            license_type_verified=request.license_type,
            verified_at=datetime.now(timezone.utc),
            expires_at=datetime(request.expiry_year, request.expiry_month, request.expiry_day, tzinfo=timezone.utc)
        )
        db.add(credential)

        # 5. 更新用戶狀態
        current_user.license_verified = True
        await db.commit()

        logger.info(f"✅ License proof generated and stored for user {current_user.id}")

        return {
            "success": True,
            "credential_type": "license",
            "is_valid": True,
            "is_simulated": result.get("simulated", False),
            "license_type_verified": request.license_type,
            "did": current_user.did
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Failed to generate license proof: {str(e)}")
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/credentials")
async def get_user_credentials(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_session)
):
    """
    獲取當前用戶的所有憑證
    """
    from sqlalchemy import select
    from app.models.credential import UserCredential

    try:
        result = await db.execute(
            select(UserCredential).where(UserCredential.user_id == current_user.id)
        )
        credentials = result.scalars().all()

        return {
            "user_id": current_user.id,
            "did": current_user.did,
            "credentials": [cred.to_dict() for cred in credentials]
        }

    except Exception as e:
        logger.error(f"❌ Failed to get credentials: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.delete("/did")
async def revoke_did(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_async_session)
):
    """
    撤銷用戶的 DID（停用）

    用戶可以選擇停用自己的 DID
    """
    try:
        if not current_user.did:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User has no DID to revoke"
            )

        identity_service = IdentityService(db)

        # 在鏈上停用 DID
        result = await identity_service.revoke_did(
            user_id=current_user.id,
            did=current_user.did
        )

        if result['success']:
            # 清除用戶的 DID 和驗證狀態
            current_user.did = None
            current_user.age_verified = False
            current_user.license_verified = False
            await db.commit()

            logger.info(f"✅ DID revoked for user {current_user.id}")

            return {
                "success": True,
                "message": "DID revoked successfully"
            }
        else:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=result.get('error', 'Failed to revoke DID')
            )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Failed to revoke DID for user {current_user.id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to revoke DID: {str(e)}"
        )
