"""
憑證 commitment（nullifier）派生 — 防 ZKP 重放（威脅 T3）

問題：原本 commitment = sha256(did:type:timestamp)（`did_service.dart:416`），**可預測**，
且後端沒有做去重（`identity_service` 的 replay 檢查是 TODO）。

設計：commitment 由後端以下列綁定重新派生（不信任客戶端送的 commitment 值），
再作為一次性 nullifier 去重：
    commitment = SHA256( DOMAIN ∥ len-prefixed(wallet_address, credential_type, proof_id, nonce) )
- `wallet_address`：綁定身分（zkLogin/錢包位址）→ 換位址就換 commitment。
- `credential_type`：age / license 分離。
- `proof_id`：該次 ZK 證明的識別（如 public_signals 摘要）→ 綁定到具體證明。
- `nonce`：一次性 32-byte 高熵亂數（由客戶端每次新產）→ 不可預測、不可重算。

去重的**最終強制點**是鏈上 `credential_verifier::used_commitments`；後端 DB 唯一約束為
defense-in-depth（見 `identity_service` 與 migration 004）。
"""

import hashlib
import os

_DOMAIN = b"chainsui-credential-commitment-v1"


def new_nonce() -> str:
    """一次性高熵 nonce（客戶端每次驗證新產一枚）。"""
    return os.urandom(32).hex()


def _enc(part: str) -> bytes:
    b = part.encode("utf-8")
    return len(b).to_bytes(4, "big") + b


def derive_commitment(
    wallet_address: str,
    credential_type: str,
    proof_id: str,
    nonce: str,
) -> str:
    """由綁定要素派生 commitment（0x + 64 hex）。位址大小寫正規化。"""
    payload = (
        _DOMAIN
        + _enc(wallet_address.lower())
        + _enc(credential_type)
        + _enc(proof_id)
        + _enc(nonce)
    )
    return "0x" + hashlib.sha256(payload).hexdigest()


def is_well_formed(commitment: str) -> bool:
    """格式健檢：0x 前綴可選，需為 64 位 hex。"""
    c = commitment[2:] if commitment.startswith("0x") else commitment
    if len(c) != 64:
        return False
    try:
        int(c, 16)
        return True
    except ValueError:
        return False
