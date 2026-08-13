"""
ZKP API Router
零知識證明相關的 API 端點
"""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from typing import Optional, List, Any, Dict
import logging

from app.services.zkp_prover import (
    get_zkp_prover,
    compute_did_hash,
    compute_license_hash
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/zkp", tags=["Zero-Knowledge Proofs"])


# ====== Schemas ======

class AgeProofRequest(BaseModel):
    """年齡證明請求"""
    birth_year: int = Field(..., ge=1900, le=2100, description="出生年份")
    birth_month: int = Field(..., ge=1, le=12, description="出生月份")
    birth_day: int = Field(..., ge=1, le=31, description="出生日期")
    min_age: int = Field(default=18, ge=0, le=150, description="最小年齡要求")
    did: str = Field(..., description="用戶 DID")


class LicenseProofRequest(BaseModel):
    """駕照證明請求"""
    license_number: str = Field(..., min_length=1, description="駕照號碼")
    expiry_year: int = Field(..., ge=2000, le=2100, description="有效期年份")
    expiry_month: int = Field(..., ge=1, le=12, description="有效期月份")
    expiry_day: int = Field(..., ge=1, le=31, description="有效期日期")
    license_type: int = Field(default=1, ge=1, le=5, description="駕照類型 (1=普通車, 2=機車, 3=商用車)")
    required_type: int = Field(default=1, ge=1, le=5, description="要求的駕照類型")
    did: str = Field(..., description="用戶 DID")


class ProofResponse(BaseModel):
    """證明響應"""
    valid: bool = Field(..., description="是否成功生成證明")
    proof: Optional[Dict[str, Any]] = Field(None, description="Groth16 證明")
    public_signals: Optional[List[int]] = Field(None, description="公開信號")
    error: Optional[str] = Field(None, description="錯誤信息")
    simulated: Optional[bool] = Field(None, description="是否為模擬證明")


# ====== API Endpoints ======

@router.post("/generate-age-proof", response_model=ProofResponse)
async def generate_age_proof(request: AgeProofRequest):
    """
    生成年齡證明

    此端點接收用戶的出生日期（私有輸入），生成一個零知識證明，
    證明用戶年齡大於等於指定的最小年齡，而不暴露實際的出生日期。

    注意：這是一個信任的證明生成服務。對於完全去中心化的場景，
    應該在客戶端（瀏覽器/App）生成證明。

    Args:
        request: 年齡證明請求

    Returns:
        ProofResponse: 包含證明和公開信號
    """
    try:
        logger.info(f"Generating age proof for DID: {request.did}")

        prover = get_zkp_prover()
        did_hash = compute_did_hash(request.did)

        result = prover.generate_age_proof(
            birth_year=request.birth_year,
            birth_month=request.birth_month,
            birth_day=request.birth_day,
            min_age=request.min_age,
            did_hash=did_hash
        )

        if result.get("valid"):
            logger.info(f"Age proof generated successfully for DID: {request.did}")
            return ProofResponse(
                valid=True,
                proof=result.get("proof"),
                public_signals=result.get("publicSignals"),
                simulated=result.get("simulated")
            )
        else:
            logger.warning(f"Age proof generation failed: {result.get('error')}")
            return ProofResponse(
                valid=False,
                error=result.get("error")
            )

    except Exception as e:
        logger.error(f"Error generating age proof: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/generate-license-proof", response_model=ProofResponse)
async def generate_license_proof(request: LicenseProofRequest):
    """
    生成駕照證明

    此端點接收用戶的駕照信息（私有輸入），生成一個零知識證明，
    證明用戶持有有效的駕照，而不暴露駕照號碼等詳細信息。

    Args:
        request: 駕照證明請求

    Returns:
        ProofResponse: 包含證明和公開信號
    """
    try:
        logger.info(f"Generating license proof for DID: {request.did}")

        prover = get_zkp_prover()
        did_hash = compute_did_hash(request.did)
        license_hash = compute_license_hash(request.license_number)

        result = prover.generate_license_proof(
            license_hash=license_hash,
            expiry_year=request.expiry_year,
            expiry_month=request.expiry_month,
            expiry_day=request.expiry_day,
            license_type=request.license_type,
            required_type=request.required_type,
            did_hash=did_hash
        )

        if result.get("valid"):
            logger.info(f"License proof generated successfully for DID: {request.did}")
            return ProofResponse(
                valid=True,
                proof=result.get("proof"),
                public_signals=result.get("publicSignals"),
                simulated=result.get("simulated")
            )
        else:
            logger.warning(f"License proof generation failed: {result.get('error')}")
            return ProofResponse(
                valid=False,
                error=result.get("error")
            )

    except Exception as e:
        logger.error(f"Error generating license proof: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/verification-keys")
async def get_verification_keys():
    """
    獲取驗證密鑰

    返回可用的驗證密鑰列表，供客戶端驗證使用。

    Returns:
        可用的驗證密鑰信息
    """
    import os
    from pathlib import Path

    keys_dir = Path(os.getenv("ZKP_KEYS_DIR", "/app/zkp_keys"))

    available_keys = []
    for key_file in keys_dir.glob("*_vkey.json"):
        circuit_name = key_file.stem.replace("_vkey", "")
        available_keys.append({
            "circuit": circuit_name,
            "file": key_file.name,
            "available": True
        })

    return {
        "keys_directory": str(keys_dir),
        "available_keys": available_keys
    }


@router.get("/health")
async def zkp_health_check():
    """
    ZKP 服務健康檢查

    檢查 ZKP 服務是否正常運行，包括 snarkjs 和密鑰文件。
    """
    import subprocess
    import os
    from pathlib import Path

    # 檢查 snarkjs 是否可用
    # 注意：snarkjs --version 會返回非零退出碼 (99)，但仍會輸出版本信息
    try:
        result = subprocess.run(
            ["snarkjs", "--version"],
            capture_output=True,
            text=True,
            timeout=5
        )
        # 檢查輸出中是否包含版本信息，而不是依賴返回碼
        output = result.stdout + result.stderr
        snarkjs_available = "snarkjs@" in output or "Copyright" in output
        # 提取版本號
        import re
        version_match = re.search(r'snarkjs@([\d.]+)', output)
        snarkjs_version = version_match.group(1) if version_match else None
    except Exception:
        snarkjs_available = False
        snarkjs_version = None

    # 檢查密鑰文件
    keys_dir = Path(os.getenv("ZKP_KEYS_DIR", "/app/zkp_keys"))
    age_vkey = keys_dir / "age_verification_vkey.json"
    license_vkey = keys_dir / "license_verification_vkey.json"

    return {
        "status": "healthy" if snarkjs_available else "degraded",
        "snarkjs": {
            "available": snarkjs_available,
            "version": snarkjs_version
        },
        "keys": {
            "directory": str(keys_dir),
            "age_verification": age_vkey.exists(),
            "license_verification": license_vkey.exists()
        },
        "mode": "real" if (snarkjs_available and age_vkey.exists()) else "simulated"
    }
