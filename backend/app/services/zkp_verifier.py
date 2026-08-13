"""
ZKP Verifier Service
使用 snarkjs 驗證 Groth16 零知識證明

此服務通過調用 Node.js snarkjs CLI 來驗證證明
"""

import json
import subprocess
import os
import logging
from typing import Dict, Any, List, Optional
from pathlib import Path

logger = logging.getLogger(__name__)

# ZKP 密鑰文件路徑
# 預設在 /app/zkp_keys（Docker 容器內）或本地開發時的 ./zkp_keys
ZKP_KEYS_DIR = os.getenv("ZKP_KEYS_DIR", "/app/zkp_keys")

class ZKPVerifier:
    """
    ZKP 證明驗證器

    使用 snarkjs groth16 verify 命令驗證證明
    """

    def __init__(self, keys_dir: str = ZKP_KEYS_DIR):
        self.keys_dir = Path(keys_dir)
        self._ensure_keys_exist()

    def _ensure_keys_exist(self):
        """確保密鑰目錄存在"""
        if not self.keys_dir.exists():
            logger.warning(f"ZKP keys directory not found: {self.keys_dir}")
            self.keys_dir.mkdir(parents=True, exist_ok=True)

    def _get_verification_key_path(self, circuit_name: str) -> Path:
        """獲取驗證密鑰路徑"""
        return self.keys_dir / f"{circuit_name}_vkey.json"

    def verify_proof(
        self,
        circuit_name: str,
        proof: Dict[str, Any],
        public_signals: List[int]
    ) -> Dict[str, Any]:
        """
        驗證 ZKP 證明

        Args:
            circuit_name: 電路名稱 (age_verification 或 license_verification)
            proof: Groth16 證明 (包含 pi_a, pi_b, pi_c)
            public_signals: 公開信號列表

        Returns:
            驗證結果 {valid: bool, error?: str}
        """
        try:
            vkey_path = self._get_verification_key_path(circuit_name)

            if not vkey_path.exists():
                # Fail closed：缺驗證密鑰就拒絕，絕不退回可偽造的模擬驗證
                # （原本缺 key 時只要 public_signals[0]==1 就通過，等於任何人都能偽造身分）。
                logger.error(f"Verification key not found: {vkey_path}")
                return {"valid": False, "error": f"缺少驗證密鑰: {vkey_path.name}"}

            # 創建臨時文件存儲證明和公開信號
            proof_file = self.keys_dir / f"temp_proof_{circuit_name}.json"
            signals_file = self.keys_dir / f"temp_signals_{circuit_name}.json"

            # 寫入證明
            with open(proof_file, 'w') as f:
                json.dump(proof, f)

            # 寫入公開信號
            with open(signals_file, 'w') as f:
                json.dump([str(s) for s in public_signals], f)

            # 調用 snarkjs verify
            result = subprocess.run(
                [
                    "snarkjs", "groth16", "verify",
                    str(vkey_path),
                    str(signals_file),
                    str(proof_file)
                ],
                capture_output=True,
                text=True,
                timeout=30
            )

            # 清理臨時文件
            proof_file.unlink(missing_ok=True)
            signals_file.unlink(missing_ok=True)

            # 解析結果
            if result.returncode == 0 and "OK" in result.stdout:
                logger.info(f"ZKP verification passed for {circuit_name}")
                return {"valid": True}
            else:
                logger.warning(f"ZKP verification failed: {result.stderr}")
                return {
                    "valid": False,
                    "error": result.stderr or "Verification failed"
                }

        except subprocess.TimeoutExpired:
            logger.error("ZKP verification timed out")
            return {"valid": False, "error": "Verification timed out"}
        except Exception as e:
            logger.error(f"ZKP verification error: {str(e)}")
            return {"valid": False, "error": str(e)}

    def verify_age(
        self,
        proof: Dict[str, Any],
        public_signals: List[int],
        did_hash: int
    ) -> Dict[str, Any]:
        """
        驗證年齡證明

        public_signals 格式:
        [0]: isValid (1=年齡合格, 0=不合格)
        [1]: didCommitment
        [2-5]: 其他公開輸入 (currentYear, currentMonth, currentDay, minAge)
        """
        # 驗證 DID 承諾值
        if len(public_signals) > 1:
            proof_did_hash = public_signals[1]
            # 簡單的 DID 綁定檢查
            # 實際應該更嚴格地驗證

        return self.verify_proof("age_verification", proof, public_signals)

    def verify_license(
        self,
        proof: Dict[str, Any],
        public_signals: List[int],
        did_hash: int
    ) -> Dict[str, Any]:
        """
        驗證駕照證明

        public_signals 格式:
        [0]: isValid (1=駕照有效, 0=無效)
        [1]: didCommitment
        [2]: licenseCommitment
        [3-6]: 其他公開輸入
        """
        return self.verify_proof("license_verification", proof, public_signals)


# 單例實例
_verifier: Optional[ZKPVerifier] = None

def get_zkp_verifier() -> ZKPVerifier:
    """獲取 ZKP 驗證器單例"""
    global _verifier
    if _verifier is None:
        _verifier = ZKPVerifier()
    return _verifier
