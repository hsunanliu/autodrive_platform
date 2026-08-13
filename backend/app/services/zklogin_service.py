"""
zkLogin 服務（Mysten Enoki）— 非託管登入 + 贊助交易

架構：Flutter 產臨時 ed25519 金鑰 + Google 登入（不存私鑰）；後端用 Enoki HTTP API 處理
繁重步驟（nonce、位址推導、ZK proof、贊助交易、送鏈）。使用者從頭到尾沒有助記詞/私鑰。

Enoki HTTP API（docs.enoki.mystenlabs.com）：
  POST /v1/zklogin/nonce                     建立 nonce（帶臨時公鑰）
  GET  /v1/zklogin                           由 JWT 取 zkLogin 位址 + salt（header zklogin-jwt）
  POST /v1/zklogin/zkp                        產生 ZK proof
  POST /v1/transaction-blocks/sponsor         贊助交易（回 digest + bytes）
  POST /v1/transaction-blocks/sponsor/{digest} 送出已簽的贊助交易

需 ENOKI_API_KEY（Bearer）。缺 key 時各方法回可辨識的錯誤，不 mock。
"""
import logging
from typing import Any, Dict, List, Optional

import httpx

from app.config import settings

logger = logging.getLogger(__name__)


class ZkLoginError(Exception):
    pass


class ZkLoginService:
    def __init__(self):
        self.base_url = settings.ENOKI_BASE_URL.rstrip("/")
        self.api_key = settings.ENOKI_API_KEY
        self.network = settings.ENOKI_NETWORK

    def _enabled(self) -> bool:
        return bool(self.api_key)

    def _headers(self, jwt: Optional[str] = None) -> Dict[str, str]:
        h = {"Authorization": f"Bearer {self.api_key}", "Content-Type": "application/json"}
        if jwt:
            h["zklogin-jwt"] = jwt
        return h

    async def _post(self, path: str, body: Dict[str, Any], jwt: Optional[str] = None) -> Dict[str, Any]:
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(f"{self.base_url}{path}", json=body, headers=self._headers(jwt))
            resp.raise_for_status()
            return resp.json().get("data", resp.json())

    async def _get(self, path: str, jwt: Optional[str] = None) -> Dict[str, Any]:
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.get(f"{self.base_url}{path}", headers=self._headers(jwt))
            resp.raise_for_status()
            return resp.json().get("data", resp.json())

    # ── zkLogin ──────────────────────────────────────────────

    async def create_nonce(self, ephemeral_public_key: str, additional_epochs: int = 2) -> Dict[str, Any]:
        """建立 nonce（Flutter 拿去做 OAuth）。回 {nonce, randomness, epoch, maxEpoch, estimatedExpiration}。"""
        if not self._enabled():
            raise ZkLoginError("ENOKI_API_KEY 未設定")
        return await self._post("/v1/zklogin/nonce", {
            "ephemeralPublicKey": ephemeral_public_key,
            "network": self.network,
            "additionalEpochs": additional_epochs,
        })

    async def get_address(self, jwt: str) -> Dict[str, Any]:
        """由 OAuth JWT 取 zkLogin 位址。回 {salt, address, publicKey}。"""
        if not self._enabled():
            raise ZkLoginError("ENOKI_API_KEY 未設定")
        return await self._get("/v1/zklogin", jwt=jwt)

    async def create_zkp(self, jwt: str, ephemeral_public_key: str, max_epoch: int, randomness: str) -> Dict[str, Any]:
        """產生 ZK proof（簽交易時用）。回 {proofPoints, issBase64Details, headerBase64, addressSeed}。"""
        if not self._enabled():
            raise ZkLoginError("ENOKI_API_KEY 未設定")
        return await self._post("/v1/zklogin/zkp", {
            "ephemeralPublicKey": ephemeral_public_key,
            "maxEpoch": max_epoch,
            "randomness": randomness,
            "network": self.network,
        }, jwt=jwt)

    # ── 贊助交易 ──────────────────────────────────────────────

    async def sponsor(
        self,
        tx_kind_bytes: str,
        sender: Optional[str] = None,
        jwt: Optional[str] = None,
        allowed_move_call_targets: Optional[List[str]] = None,
        allowed_addresses: Optional[List[str]] = None,
    ) -> Dict[str, Any]:
        """贊助一筆交易（Enoki 付 gas）。回 {digest, bytes}。sender 與 jwt 至少一個。"""
        if not self._enabled():
            raise ZkLoginError("ENOKI_API_KEY 未設定")
        body: Dict[str, Any] = {"transactionBlockKindBytes": tx_kind_bytes, "network": self.network}
        if sender:
            body["sender"] = sender
        if allowed_move_call_targets:
            body["allowedMoveCallTargets"] = allowed_move_call_targets
        if allowed_addresses:
            body["allowedAddresses"] = allowed_addresses
        return await self._post("/v1/transaction-blocks/sponsor", body, jwt=jwt)

    async def execute_sponsored(self, digest: str, signature: str) -> Dict[str, Any]:
        """送出已由使用者 zkLogin 簽名的贊助交易。回 {digest}。"""
        if not self._enabled():
            raise ZkLoginError("ENOKI_API_KEY 未設定")
        return await self._post(f"/v1/transaction-blocks/sponsor/{digest}", {"signature": signature})


zklogin_service = ZkLoginService()
