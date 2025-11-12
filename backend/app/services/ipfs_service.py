# backend/app/services/ipfs_service.py
"""
IPFS 服務 - 處理退款證據、服務證明等文件上傳

功能：
1. 上傳文件到 IPFS
2. 從 IPFS 檢索文件
3. 生成並保存 CID 記錄
4. 驗證文件完整性
"""

import httpx
import json
import hashlib
import logging
from typing import Optional, Dict, Any, BinaryIO
from datetime import datetime
from pathlib import Path

logger = logging.getLogger(__name__)


class IPFSService:
    """IPFS 整合服務"""

    def __init__(
        self,
        api_url: str = "http://localhost:5001",
        gateway_url: str = "http://localhost:8080"
    ):
        """
        初始化 IPFS 服務

        Args:
            api_url: IPFS API 端點（預設本地節點）
            gateway_url: IPFS Gateway 端點
        """
        self.api_url = api_url
        self.gateway_url = gateway_url
        self.client = httpx.AsyncClient(timeout=30.0)

    async def upload_file(
        self,
        file_content: bytes,
        filename: str,
        metadata: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        上傳文件到 IPFS

        Args:
            file_content: 文件內容（二進制）
            filename: 文件名稱
            metadata: 額外元數據（例如：類型、用途、上傳者）

        Returns:
            {
                "success": True,
                "cid": "QmXxx...",
                "size": 12345,
                "filename": "refund_proof.jpg",
                "hash": "sha256_hash",
                "uploaded_at": "2025-10-26T12:00:00"
            }
        """
        try:
            # 計算文件 Hash（用於驗證）
            file_hash = hashlib.sha256(file_content).hexdigest()

            # 準備上傳
            files = {
                'file': (filename, file_content)
            }

            # 上傳到 IPFS
            response = await self.client.post(
                f"{self.api_url}/api/v0/add",
                files=files,
                params={
                    'pin': 'true',  # 固定文件，防止被垃圾回收
                    'wrap-with-directory': 'false'
                }
            )

            if response.status_code != 200:
                logger.error(f"IPFS 上傳失敗: {response.text}")
                return {
                    "success": False,
                    "error": f"IPFS API 錯誤: {response.status_code}"
                }

            result = response.json()
            cid = result.get('Hash')

            logger.info(f"✅ 文件已上傳到 IPFS: {cid}")

            return {
                "success": True,
                "cid": cid,
                "size": result.get('Size', len(file_content)),
                "filename": filename,
                "hash": file_hash,
                "uploaded_at": datetime.utcnow().isoformat(),
                "metadata": metadata or {},
                "ipfs_url": f"{self.gateway_url}/ipfs/{cid}"
            }

        except httpx.ConnectError:
            logger.error("❌ 無法連接到 IPFS 節點")
            return {
                "success": False,
                "error": "無法連接到 IPFS 節點，請確認 IPFS 守護進程正在運行"
            }
        except Exception as e:
            logger.error(f"❌ IPFS 上傳失敗: {str(e)}")
            return {
                "success": False,
                "error": f"上傳失敗: {str(e)}"
            }

    async def retrieve_file(self, cid: str) -> Dict[str, Any]:
        """
        從 IPFS 檢索文件

        Args:
            cid: IPFS 內容標識符

        Returns:
            {
                "success": True,
                "content": bytes,
                "size": 12345
            }
        """
        try:
            response = await self.client.post(
                f"{self.api_url}/api/v0/cat",
                params={'arg': cid}
            )

            if response.status_code != 200:
                return {
                    "success": False,
                    "error": f"檢索失敗: HTTP {response.status_code}"
                }

            content = response.content

            return {
                "success": True,
                "content": content,
                "size": len(content),
                "cid": cid
            }

        except Exception as e:
            logger.error(f"❌ IPFS 檢索失敗: {str(e)}")
            return {
                "success": False,
                "error": f"檢索失敗: {str(e)}"
            }

    async def verify_file(self, cid: str, expected_hash: str) -> bool:
        """
        驗證 IPFS 文件完整性

        Args:
            cid: IPFS 內容標識符
            expected_hash: 預期的 SHA256 雜湊值

        Returns:
            True if 文件完整性驗證通過
        """
        try:
            result = await self.retrieve_file(cid)

            if not result['success']:
                return False

            actual_hash = hashlib.sha256(result['content']).hexdigest()
            return actual_hash == expected_hash

        except Exception as e:
            logger.error(f"❌ 文件驗證失敗: {str(e)}")
            return False

    async def pin_file(self, cid: str) -> Dict[str, Any]:
        """
        固定文件到 IPFS（防止垃圾回收）

        Args:
            cid: IPFS 內容標識符

        Returns:
            {"success": True, "cid": "QmXxx..."}
        """
        try:
            response = await self.client.post(
                f"{self.api_url}/api/v0/pin/add",
                params={'arg': cid}
            )

            if response.status_code != 200:
                return {
                    "success": False,
                    "error": f"固定失敗: HTTP {response.status_code}"
                }

            result = response.json()

            return {
                "success": True,
                "cid": result.get('Pins', [cid])[0]
            }

        except Exception as e:
            logger.error(f"❌ IPFS 固定失敗: {str(e)}")
            return {
                "success": False,
                "error": f"固定失敗: {str(e)}"
            }

    async def unpin_file(self, cid: str) -> Dict[str, Any]:
        """
        取消固定文件（允許垃圾回收）

        Args:
            cid: IPFS 內容標識符

        Returns:
            {"success": True, "cid": "QmXxx..."}
        """
        try:
            response = await self.client.post(
                f"{self.api_url}/api/v0/pin/rm",
                params={'arg': cid}
            )

            if response.status_code != 200:
                return {
                    "success": False,
                    "error": f"取消固定失敗: HTTP {response.status_code}"
                }

            return {
                "success": True,
                "cid": cid
            }

        except Exception as e:
            logger.error(f"❌ 取消固定失敗: {str(e)}")
            return {
                "success": False,
                "error": f"取消固定失敗: {str(e)}"
            }

    async def get_file_info(self, cid: str) -> Dict[str, Any]:
        """
        獲取 IPFS 文件資訊

        Args:
            cid: IPFS 內容標識符

        Returns:
            {
                "success": True,
                "cid": "QmXxx...",
                "size": 12345,
                "type": "file"
            }
        """
        try:
            response = await self.client.post(
                f"{self.api_url}/api/v0/object/stat",
                params={'arg': cid}
            )

            if response.status_code != 200:
                return {
                    "success": False,
                    "error": f"獲取資訊失敗: HTTP {response.status_code}"
                }

            result = response.json()

            return {
                "success": True,
                "cid": cid,
                "size": result.get('CumulativeSize', 0),
                "num_links": result.get('NumLinks', 0),
                "block_size": result.get('BlockSize', 0)
            }

        except Exception as e:
            logger.error(f"❌ 獲取文件資訊失敗: {str(e)}")
            return {
                "success": False,
                "error": f"獲取資訊失敗: {str(e)}"
            }

    async def close(self):
        """關閉 HTTP 客戶端"""
        await self.client.aclose()


# 創建全局 IPFS 服務實例
ipfs_service = IPFSService()


# 輔助函數：生成審計日誌
def log_ipfs_upload(
    cid: str,
    filename: str,
    uploaded_by: int,
    purpose: str,
    related_id: Optional[int] = None
) -> Dict[str, Any]:
    """
    記錄 IPFS 上傳審計日誌

    Args:
        cid: IPFS 內容標識符
        filename: 文件名稱
        uploaded_by: 上傳者 User ID
        purpose: 用途（refund_evidence, service_proof, etc.）
        related_id: 關聯 ID（例如：退款請求 ID）

    Returns:
        審計日誌記錄
    """
    log_entry = {
        "timestamp": datetime.utcnow().isoformat(),
        "cid": cid,
        "filename": filename,
        "uploaded_by": uploaded_by,
        "purpose": purpose,
        "related_id": related_id
    }

    # 寫入審計日誌文件
    log_file = Path("logs/ipfs_upload_audit.jsonl")
    log_file.parent.mkdir(parents=True, exist_ok=True)

    with open(log_file, "a", encoding="utf-8") as f:
        f.write(json.dumps(log_entry, ensure_ascii=False) + "\n")

    logger.info(f"📝 IPFS 上傳已記錄: {cid} ({purpose})")

    return log_entry
