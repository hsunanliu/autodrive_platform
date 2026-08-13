"""
ZKP Prover Service
使用 snarkjs 生成 Groth16 零知識證明

此服務通過調用 Node.js snarkjs CLI 來生成證明
注意：這是一個信任的證明生成服務，私有輸入會傳送到服務器
對於完全去中心化的場景，應該在客戶端生成證明
"""

import json
import subprocess
import os
import logging
import tempfile
import hashlib
from typing import Dict, Any, List, Optional
from pathlib import Path
from datetime import datetime

logger = logging.getLogger(__name__)

# ZKP 密鑰和 WASM 文件路徑
# 都放在 /app/zkp_wasm 目錄下
ZKP_KEYS_DIR = os.getenv("ZKP_KEYS_DIR", "/app/zkp_wasm")
ZKP_WASM_DIR = os.getenv("ZKP_WASM_DIR", "/app/zkp_wasm")


class ZKPProver:
    """
    ZKP 證明生成器

    使用 snarkjs groth16 fullprove 命令生成證明
    """

    def __init__(self, keys_dir: str = ZKP_KEYS_DIR, wasm_dir: str = ZKP_WASM_DIR):
        self.keys_dir = Path(keys_dir)
        self.wasm_dir = Path(wasm_dir)
        self._ensure_paths_exist()

    def _ensure_paths_exist(self):
        """確保密鑰和 WASM 目錄存在"""
        if not self.keys_dir.exists():
            logger.warning(f"ZKP keys directory not found: {self.keys_dir}")
            self.keys_dir.mkdir(parents=True, exist_ok=True)
        if not self.wasm_dir.exists():
            logger.warning(f"ZKP WASM directory not found: {self.wasm_dir}")
            self.wasm_dir.mkdir(parents=True, exist_ok=True)

    def _get_zkey_path(self, circuit_name: str) -> Path:
        """獲取證明密鑰路徑"""
        return self.keys_dir / f"{circuit_name}_final.zkey"

    def _get_wasm_path(self, circuit_name: str) -> Path:
        """獲取 WASM 文件路徑"""
        return self.wasm_dir / f"{circuit_name}.wasm"

    def generate_age_proof(
        self,
        birth_year: int,
        birth_month: int,
        birth_day: int,
        min_age: int,
        did_hash: int
    ) -> Dict[str, Any]:
        """
        生成年齡證明

        Args:
            birth_year: 出生年份
            birth_month: 出生月份
            birth_day: 出生日期
            min_age: 最小年齡要求
            did_hash: DID 哈希值

        Returns:
            {proof: {...}, publicSignals: [...], valid: bool}
        """
        now = datetime.now()

        # 準備輸入
        inputs = {
            "birthYear": birth_year,
            "birthMonth": birth_month,
            "birthDay": birth_day,
            "currentYear": now.year,
            "currentMonth": now.month,
            "currentDay": now.day,
            "minAge": min_age,
            "didHash": did_hash
        }

        return self._generate_proof("age_verification", inputs)

    def generate_license_proof(
        self,
        license_hash: int,
        expiry_year: int,
        expiry_month: int,
        expiry_day: int,
        license_type: int,
        required_type: int,
        did_hash: int
    ) -> Dict[str, Any]:
        """
        生成駕照證明

        Args:
            license_hash: 駕照哈希值
            expiry_year: 有效期年份
            expiry_month: 有效期月份
            expiry_day: 有效期日期
            license_type: 駕照類型 (1=普通車, 2=機車, 3=商用車)
            required_type: 要求的駕照類型
            did_hash: DID 哈希值

        Returns:
            {proof: {...}, publicSignals: [...], valid: bool}
        """
        now = datetime.now()

        # 準備輸入
        inputs = {
            "licenseHash": license_hash,
            "expiryYear": expiry_year,
            "expiryMonth": expiry_month,
            "expiryDay": expiry_day,
            "licenseType": license_type,
            "currentYear": now.year,
            "currentMonth": now.month,
            "currentDay": now.day,
            "requiredType": required_type,
            "didHash": did_hash
        }

        return self._generate_proof("license_verification", inputs)

    def _generate_proof(
        self,
        circuit_name: str,
        inputs: Dict[str, int]
    ) -> Dict[str, Any]:
        """
        生成 ZKP 證明

        Args:
            circuit_name: 電路名稱
            inputs: 輸入值字典

        Returns:
            {proof: {...}, publicSignals: [...], valid: bool}
        """
        try:
            zkey_path = self._get_zkey_path(circuit_name)
            wasm_path = self._get_wasm_path(circuit_name)

            # 檢查必要文件是否存在。缺少證明密鑰/電路時「fail closed」——
            # 絕不退回模擬證明（模擬證明可被偽造成 valid，破壞整個身分驗證）。
            if not zkey_path.exists():
                logger.error(f"ZKey file not found: {zkey_path}")
                return {"valid": False, "error": f"缺少證明密鑰: {zkey_path.name}"}

            if not wasm_path.exists():
                logger.error(f"WASM file not found: {wasm_path}")
                return {"valid": False, "error": f"缺少電路 WASM: {wasm_path.name}"}

            # 創建臨時文件
            with tempfile.TemporaryDirectory() as temp_dir:
                input_file = Path(temp_dir) / "input.json"
                proof_file = Path(temp_dir) / "proof.json"
                public_file = Path(temp_dir) / "public.json"

                # 寫入輸入
                with open(input_file, 'w') as f:
                    json.dump(inputs, f)

                # 調用 snarkjs fullprove
                result = subprocess.run(
                    [
                        "snarkjs", "groth16", "fullprove",
                        str(input_file),
                        str(wasm_path),
                        str(zkey_path),
                        str(proof_file),
                        str(public_file)
                    ],
                    capture_output=True,
                    text=True,
                    timeout=60
                )

                if result.returncode != 0:
                    logger.error(f"Proof generation failed: {result.stderr}")
                    return {
                        "valid": False,
                        "error": result.stderr or "Proof generation failed"
                    }

                # 讀取生成的證明
                with open(proof_file, 'r') as f:
                    proof = json.load(f)

                with open(public_file, 'r') as f:
                    public_signals = json.load(f)

                logger.info(f"ZKP proof generated for {circuit_name}")

                return {
                    "valid": True,
                    "proof": proof,
                    "publicSignals": [int(s) for s in public_signals]
                }

        except subprocess.TimeoutExpired:
            logger.error("Proof generation timed out")
            return {"valid": False, "error": "Proof generation timed out"}
        except Exception as e:
            logger.error(f"Proof generation error: {str(e)}")
            return {"valid": False, "error": str(e)}

# 單例實例
_prover: Optional[ZKPProver] = None


def get_zkp_prover() -> ZKPProver:
    """獲取 ZKP 證明生成器單例"""
    global _prover
    if _prover is None:
        _prover = ZKPProver()
    return _prover


def compute_did_hash(did: str) -> int:
    """計算 DID 哈希值"""
    did_bytes = did.encode('utf-8')
    hash_bytes = hashlib.sha256(did_bytes).digest()
    return int.from_bytes(hash_bytes[:8], 'big')


def compute_license_hash(license_number: str) -> int:
    """計算駕照哈希值"""
    license_bytes = license_number.encode('utf-8')
    hash_bytes = hashlib.sha256(license_bytes).digest()
    return int.from_bytes(hash_bytes[:8], 'big')
