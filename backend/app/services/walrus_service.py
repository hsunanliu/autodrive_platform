"""
Walrus 去中心化存儲服務

把大容量/高頻資料（GPS 軌跡、評價文字與媒體、退款佐證）存到 Walrus，
鏈上只錨定 blob_id 與內容 SHA256。讀取時比對 hash，確保資料完整、不可竄改。

Walrus HTTP API：
  - Publisher:  PUT  {publisher}/v1/blobs?epochs=N   body = blob bytes
                回傳 JSON，內含 newlyCreated.blobObject.blobId 或 alreadyCertified.blobId
  - Aggregator: GET  {aggregator}/v1/blobs/{blobId}   回傳 blob bytes

設計要點：
  - 上傳失敗重試（指數退避）。
  - 上傳後回傳 blob_id 與 sha256，供 Move 錨定。
  - 讀取後比對 sha256，不符即視為毀損/竄改並拒絕。
"""

import asyncio
import hashlib
import logging
from typing import List, Optional

import httpx

from app.config import settings
from app.core import envelope

logger = logging.getLogger(__name__)


class WalrusError(Exception):
    """Walrus 操作失敗。"""


class WalrusService:
    def __init__(
        self,
        publisher_url: Optional[str] = None,
        aggregator_url: Optional[str] = None,
        epochs: Optional[int] = None,
        max_retries: int = 3,
        timeout_s: float = 30.0,
    ):
        self.publisher_url = (publisher_url or settings.WALRUS_PUBLISHER_URL).rstrip("/")
        self.aggregator_url = (aggregator_url or settings.WALRUS_AGGREGATOR_URL).rstrip("/")
        self.epochs = epochs if epochs is not None else settings.WALRUS_EPOCHS
        self.max_retries = max_retries
        self.timeout_s = timeout_s

    @staticmethod
    def content_hash(data: bytes) -> bytes:
        """回傳內容的 SHA256（32 bytes），用於鏈上錨定與讀取校驗。"""
        return hashlib.sha256(data).digest()

    async def store(self, data: bytes, epochs: Optional[int] = None) -> dict:
        """
        上傳 bytes 到 Walrus。

        Returns:
            {
              "blob_id": str,               # Walrus blob id（可再上鏈錨定）
              "content_hash": bytes,        # SHA256(data)，32 bytes
              "content_hash_hex": str,
              "size": int,
            }

        Raises:
            WalrusError: 重試耗盡仍失敗。
        """
        if not data:
            raise WalrusError("不可上傳空資料")

        epochs = epochs if epochs is not None else self.epochs
        url = f"{self.publisher_url}/v1/blobs?epochs={epochs}"
        digest = self.content_hash(data)

        last_err: Optional[Exception] = None
        for attempt in range(1, self.max_retries + 1):
            try:
                async with httpx.AsyncClient(timeout=self.timeout_s) as client:
                    resp = await client.put(url, content=data)
                    resp.raise_for_status()
                    body = resp.json()

                blob_id = self._extract_blob_id(body)
                if not blob_id:
                    raise WalrusError(f"Walrus 回應缺少 blobId: {body}")

                logger.info("✅ Walrus 上傳成功 blob_id=%s size=%d", blob_id, len(data))
                return {
                    "blob_id": blob_id,
                    "content_hash": digest,
                    "content_hash_hex": digest.hex(),
                    "size": len(data),
                }
            except Exception as e:  # noqa: BLE001 - 需捕捉所有網路/解析錯誤以重試
                last_err = e
                logger.warning("Walrus 上傳失敗（第 %d/%d 次）：%s", attempt, self.max_retries, e)
                if attempt < self.max_retries:
                    await asyncio.sleep(0.5 * (2 ** (attempt - 1)))

        raise WalrusError(f"Walrus 上傳重試耗盡：{last_err}")

    async def read(self, blob_id: str, expected_hash: Optional[bytes] = None) -> bytes:
        """
        從 Walrus 讀取 blob。若提供 expected_hash（通常來自鏈上錨定），會比對，
        不符即拋 WalrusError（視為毀損或遭竄改）。
        """
        url = f"{self.aggregator_url}/v1/blobs/{blob_id}"

        last_err: Optional[Exception] = None
        for attempt in range(1, self.max_retries + 1):
            try:
                async with httpx.AsyncClient(timeout=self.timeout_s) as client:
                    resp = await client.get(url)
                    resp.raise_for_status()
                    data = resp.content

                if expected_hash is not None and self.content_hash(data) != expected_hash:
                    raise WalrusError(
                        f"blob {blob_id} 內容雜湊與鏈上錨定不符（可能毀損或遭竄改）"
                    )
                return data
            except WalrusError:
                # 雜湊不符不重試（重試也一樣），直接往外拋
                raise
            except Exception as e:  # noqa: BLE001
                last_err = e
                logger.warning("Walrus 讀取失敗（第 %d/%d 次）：%s", attempt, self.max_retries, e)
                if attempt < self.max_retries:
                    await asyncio.sleep(0.5 * (2 ** (attempt - 1)))

        raise WalrusError(f"Walrus 讀取重試耗盡：{last_err}")

    async def store_encrypted(
        self,
        plaintext: bytes,
        recipient_pubs: List[bytes],
        aad: bytes = b"",
        epochs: Optional[int] = None,
    ) -> dict:
        """
        Envelope 加密後上傳（威脅 T4：PII 不再明文上公網）。
        內容用隨機 DEK 加密，DEK 包給每個收件者 X25519 公鑰；Walrus 只存密文。

        Returns:
            {
              "blob_id": str,            # 密文的 Walrus blob id（可上鏈錨定）
              "content_hash": bytes,     # 密文 SHA256（鏈上錨定用）
              "content_hash_hex": str,
              "nonce": bytes,            # GCM nonce（非機密）
              "wrapped_deks": {pub_hex: wrapped_bytes},  # 各收件者的包裝 DEK（存 DB/鏈下）
              "size": int,               # 密文大小
            }
        """
        sealed = envelope.seal_for_recipients(plaintext, recipient_pubs, aad)
        result = await self.store(sealed["ciphertext"], epochs=epochs)
        result["nonce"] = sealed["nonce"]
        result["wrapped_deks"] = sealed["wrapped_deks"]
        return result

    async def read_encrypted(
        self,
        blob_id: str,
        nonce: bytes,
        wrapped_dek: bytes,
        recipient_priv_raw: bytes,
        expected_hash: Optional[bytes] = None,
        aad: bytes = b"",
    ) -> bytes:
        """
        讀回密文（可比對鏈上錨定的密文 hash），再用收件者的 wrapped DEK + 私鑰解密。
        """
        ciphertext = await self.read(blob_id, expected_hash=expected_hash)
        return envelope.open_sealed(ciphertext, nonce, wrapped_dek, recipient_priv_raw, aad)

    @staticmethod
    def _extract_blob_id(body: dict) -> Optional[str]:
        """從 publisher 回應解析 blobId（兩種情況：新建 / 已存在）。"""
        if not isinstance(body, dict):
            return None
        if "newlyCreated" in body:
            return (
                body["newlyCreated"]
                .get("blobObject", {})
                .get("blobId")
            )
        if "alreadyCertified" in body:
            return body["alreadyCertified"].get("blobId")
        return None


# 全局單例
walrus_service = WalrusService()
