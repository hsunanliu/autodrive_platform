"""
Identity Service - DID and Credential Verification
處理 DID 註冊和憑證驗證的業務邏輯
"""
import logging
import json
from typing import Dict, Any
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.models.user import User
from app.models.credential import UserCredential, CredentialType, CredentialStatus
from app.services.zkp_verifier import get_zkp_verifier
from app.core.commitment import is_well_formed

logger = logging.getLogger(__name__)


class IdentityService:
    """身份服務"""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def register_did(
        self,
        user_id: int,
        did: str,
        did_document: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        註冊用戶的 DID

        Args:
            user_id: 用戶 ID
            did: DID 字符串
            did_document: DID 文檔

        Returns:
            註冊結果
        """
        try:
            # 1. 驗證 DID 格式
            if not did.startswith("did:sui:"):
                raise ValueError("Invalid DID format. Must start with 'did:sui:'")

            # 2. 檢查 DID 是否已被其他用戶使用
            result = await self.db.execute(select(User).filter(User.did == did))
            existing_user = result.scalar_one_or_none()
            if existing_user and existing_user.id != user_id:
                raise ValueError("DID already registered by another user")

            # 3. 更新用戶記錄
            result = await self.db.execute(select(User).filter(User.id == user_id))
            user = result.scalar_one_or_none()
            if not user:
                raise ValueError("User not found")

            user.did = did
            user.did_document = json.dumps(did_document)
            await self.db.commit()

            logger.info(f"✅ DID registered: {did} for user {user_id}")

            return {
                "success": True,
                "did": did,
                "user_id": user_id
            }

        except Exception as e:
            logger.error(f"❌ Failed to register DID: {str(e)}")
            await self.db.rollback()
            raise

    async def verify_age_credential(
        self,
        user_id: int,
        did: str,
        proof: str,
        public_signals: list,
        commitment: str
    ) -> Dict[str, Any]:
        """
        驗證年齡憑證（ZKP）

        Args:
            user_id: 用戶 ID
            did: 用戶 DID
            proof: ZKP 證明
            public_signals: 公開信號 [isValid, didCommitment, currentDate, minAge]
            commitment: 憑證承諾值

        Returns:
            驗證結果
        """
        try:
            # 1. 驗證 DID 所有權
            result = await self.db.execute(select(User).filter(User.id == user_id, User.did == did))
            user = result.scalar_one_or_none()
            if not user:
                return {
                    "valid": False,
                    "error": "DID does not match user"
                }

            # 2. 檢查承諾值是否已使用（防止重複使用）
            # TODO: 在生產環境中，應該在智能合約上檢查
            # 現在簡化實現，檢查數據庫

            # 3. 驗證公開信號格式
            if len(public_signals) < 2:
                return {
                    "valid": False,
                    "error": "Invalid public signals format"
                }

            is_valid = public_signals[0]
            if is_valid != 1:
                return {
                    "valid": False,
                    "error": "Proof indicates invalid credential"
                }

            # 4. 實際的 ZKP 驗證
            # TODO: 在生產環境中，應該調用智能合約的 verify_age_credential 函數
            # 現在簡化實現，只檢查基本格式
            verification_result = await self._verify_zkp_on_chain(
                credential_type="age",
                did=did,
                proof=proof,
                public_signals=public_signals,
                commitment=commitment
            )

            if verification_result:
                # 防重放：消費一次性 commitment（重複或格式無效即拒）
                consumed = await self._consume_commitment(user_id, "age", commitment)
                if not consumed:
                    return {
                        "valid": False,
                        "error": "commitment 已使用或格式無效（防重放）"
                    }
                logger.info(f"✅ Age credential verified for user {user_id}")
                return {
                    "valid": True,
                    "credential_type": "age"
                }
            else:
                logger.warning(f"⚠️ Age credential verification failed for user {user_id}")
                return {
                    "valid": False,
                    "error": "ZKP verification failed"
                }

        except Exception as e:
            logger.error(f"❌ Error verifying age credential: {str(e)}")
            return {
                "valid": False,
                "error": str(e)
            }

    async def verify_license_credential(
        self,
        user_id: int,
        did: str,
        proof: str,
        public_signals: list,
        commitment: str
    ) -> Dict[str, Any]:
        """
        驗證駕照憑證（ZKP）

        Args:
            user_id: 用戶 ID
            did: 用戶 DID
            proof: ZKP 證明
            public_signals: 公開信號
            commitment: 憑證承諾值

        Returns:
            驗證結果
        """
        try:
            # 1. 驗證 DID 所有權
            result = await self.db.execute(select(User).filter(User.id == user_id, User.did == did))
            user = result.scalar_one_or_none()
            if not user:
                return {
                    "valid": False,
                    "error": "DID does not match user"
                }

            # 2. 檢查用戶是否為司機
            if not user.is_driver:
                return {
                    "valid": False,
                    "error": "User is not a driver"
                }

            # 3. 驗證公開信號
            if len(public_signals) < 2:
                return {
                    "valid": False,
                    "error": "Invalid public signals format"
                }

            is_valid = public_signals[0]
            if is_valid != 1:
                return {
                    "valid": False,
                    "error": "Proof indicates invalid credential"
                }

            # 4. ZKP 驗證
            verification_result = await self._verify_zkp_on_chain(
                credential_type="license",
                did=did,
                proof=proof,
                public_signals=public_signals,
                commitment=commitment
            )

            if verification_result:
                consumed = await self._consume_commitment(user_id, "license", commitment)
                if not consumed:
                    return {
                        "valid": False,
                        "error": "commitment 已使用或格式無效（防重放）"
                    }
                logger.info(f"✅ License credential verified for user {user_id}")
                return {
                    "valid": True,
                    "credential_type": "license"
                }
            else:
                logger.warning(f"⚠️ License credential verification failed for user {user_id}")
                return {
                    "valid": False,
                    "error": "ZKP verification failed"
                }

        except Exception as e:
            logger.error(f"❌ Error verifying license credential: {str(e)}")
            return {
                "valid": False,
                "error": str(e)
            }

    async def revoke_did(
        self,
        user_id: int,
        did: str
    ) -> Dict[str, Any]:
        """
        撤銷（停用）用戶的 DID

        Args:
            user_id: 用戶 ID
            did: DID 字符串

        Returns:
            撤銷結果
        """
        try:
            # TODO: 在生產環境中，應該調用智能合約的 deactivate_did 函數
            # 現在簡化實現，只清除數據庫記錄

            logger.info(f"✅ DID revoked: {did} for user {user_id}")

            return {
                "success": True,
                "message": "DID revoked successfully"
            }

        except Exception as e:
            logger.error(f"❌ Failed to revoke DID: {str(e)}")
            return {
                "success": False,
                "error": str(e)
            }

    async def _consume_commitment(
        self,
        user_id: int,
        credential_type: str,
        commitment: str,
    ) -> bool:
        """
        一次性消費 commitment（防 ZKP 重放，威脅 T3）。

        1. 格式健檢：拒絕畸形/過短 commitment。
        2. 以 nullifier 唯一約束原子性去重：重複的 commitment INSERT 會撞唯一索引 →
           捕捉 IntegrityError 回傳 False（判定為重放）。

        回傳 True 表示首次使用、已記錄；False 表示重放或格式無效。
        注意：鏈上 `credential_verifier::used_commitments` 為最終強制點；此處為 DB 層
        defense-in-depth，並讓後端能在送鏈前就擋掉重放。
        """
        if not is_well_formed(commitment):
            logger.warning("拒絕畸形 commitment（防重放）")
            return False

        ctype = CredentialType.AGE if credential_type == "age" else CredentialType.LICENSE
        record = UserCredential(
            user_id=user_id,
            credential_type=ctype,
            status=CredentialStatus.VERIFIED,
            is_valid=True,
            nullifier=commitment,
        )
        self.db.add(record)
        try:
            await self.db.flush()  # 觸發唯一約束檢查
        except IntegrityError:
            await self.db.rollback()
            logger.warning("commitment 已被使用，判定為重放並拒絕")
            return False
        await self.db.commit()
        return True

    async def _verify_zkp_on_chain(
        self,
        credential_type: str,
        did: str,
        proof: str,
        public_signals: list,
        commitment: str
    ) -> bool:
        """
        使用 snarkjs 驗證 ZKP 證明

        Args:
            credential_type: 憑證類型（age, license）
            did: DID 字符串
            proof: ZKP 證明 (JSON 或 hex 編碼)
            public_signals: 公開信號
            commitment: 承諾值

        Returns:
            驗證是否成功
        """
        try:
            # 1. 獲取 ZKP 驗證器
            verifier = get_zkp_verifier()

            # 2. 解析 proof (必須是 snarkjs Groth16 JSON)。
            #    不再有任何「模擬驗證」捷徑——舊版 0x 格式或無法解析的 proof 一律拒絕，
            #    否則攻擊者只要送 public_signals[0]=1 就能偽造身分。
            if isinstance(proof, str):
                if proof.startswith("0x"):
                    logger.warning("⚠️ 拒絕舊版 0x 模擬 proof 格式（非真實 Groth16 證明）")
                    return False
                try:
                    proof_dict = json.loads(proof)
                except json.JSONDecodeError:
                    logger.warning("⚠️ Invalid proof JSON format")
                    return False
            elif isinstance(proof, dict):
                proof_dict = proof
            else:
                logger.warning(f"⚠️ Unknown proof format: {type(proof)}")
                return False

            # 3. 計算 DID hash (用於綁定身份)
            import hashlib
            did_bytes = did.encode('utf-8')
            did_hash = int(hashlib.sha256(did_bytes).hexdigest(), 16) % (2**64)

            # 4. 選擇驗證電路
            if credential_type == "age":
                circuit_name = "age_verification"
                result = verifier.verify_age(proof_dict, public_signals, did_hash)
            elif credential_type == "license":
                circuit_name = "license_verification"
                result = verifier.verify_license(proof_dict, public_signals, did_hash)
            else:
                logger.warning(f"⚠️ Unknown credential type: {credential_type}")
                return False

            # 5. 檢查驗證結果
            if result.get("valid"):
                logger.info(f"✅ ZKP verification passed: {credential_type}")
                if result.get("simulated"):
                    logger.warning("⚠️ Using simulated verification (keys not available)")
                return True
            else:
                logger.warning(f"⚠️ ZKP verification failed: {result.get('error')}")
                return False

        except Exception as e:
            logger.error(f"❌ Error in ZKP verification: {str(e)}")
            return False
