"""
Envelope 加密（混合加密）— 存入 Walrus 前把 PII 加密

威脅 T4：GPS 軌跡、對話、評價等 PII 若明文存進公開的 Walrus，全網可讀。
本模組在上傳前加密：
  1. 每個 blob 產生隨機 256-bit DEK（資料加密金鑰），用 AES-256-GCM 加密內容。
  2. DEK 再用**每個授權對象的 X25519 公鑰**非對稱包裝（libsodium sealed-box 風格：
     一次性 ephemeral ECDH → HKDF → AES-GCM 包裝 DEK）。
  只有持對應 X25519 私鑰者（乘客/司機/授權稽核）能解出 DEK、進而解密內容。

Walrus 上只存**密文**；鏈上錨定的是**密文的 SHA256**（完整性），wrapped DEK 放 DB/鏈下。

⚠️ 生產升級路徑：Sui **Seal**（門檻加密 + 鏈上存取控管）可取代自管 wrapped-DEK 的
金鑰派送；本模組為不依賴外部服務、可立即上線的方案。介面（store/read）設計為可替換。
"""

import os
from typing import Dict, List

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.asymmetric.x25519 import (
    X25519PrivateKey,
    X25519PublicKey,
)
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives import hashes

_DEK_LEN = 32          # AES-256
_NONCE_LEN = 12        # GCM nonce
_X25519_PUB_LEN = 32
_WRAP_INFO = b"chainsui-dek-wrap-v1"


# ── 對稱層：內容加解密 ──────────────────────────────────────────────

def generate_dek() -> bytes:
    return os.urandom(_DEK_LEN)


def encrypt_content(plaintext: bytes, dek: bytes, aad: bytes = b"") -> Dict[str, bytes]:
    """用 DEK 以 AES-256-GCM 加密內容。回傳 {ciphertext, nonce}（nonce 隨機、非機密）。"""
    nonce = os.urandom(_NONCE_LEN)
    ct = AESGCM(dek).encrypt(nonce, plaintext, aad)
    return {"ciphertext": ct, "nonce": nonce}


def decrypt_content(ciphertext: bytes, dek: bytes, nonce: bytes, aad: bytes = b"") -> bytes:
    return AESGCM(dek).decrypt(nonce, ciphertext, aad)


# ── 非對稱層：把 DEK 包裝給某個 X25519 公鑰持有者 ──────────────────

def wrap_dek(dek: bytes, recipient_pub_raw: bytes) -> bytes:
    """
    以 sealed-box 風格把 DEK 包給收件者公鑰：
    output = ephemeral_pub(32) ∥ nonce(12) ∥ AESGCM(hkdf(ecdh))(dek)
    每次呼叫用全新 ephemeral key，故無需另存 nonce 熵來源。
    """
    if len(recipient_pub_raw) != _X25519_PUB_LEN:
        raise ValueError("recipient public key 必須是 32-byte X25519 raw")
    recipient_pub = X25519PublicKey.from_public_bytes(recipient_pub_raw)
    eph_priv = X25519PrivateKey.generate()
    eph_pub_raw = eph_priv.public_key().public_bytes_raw()
    shared = eph_priv.exchange(recipient_pub)
    key = HKDF(
        algorithm=hashes.SHA256(), length=32, salt=None,
        info=_WRAP_INFO + eph_pub_raw + recipient_pub_raw,
    ).derive(shared)
    nonce = os.urandom(_NONCE_LEN)
    wrapped = AESGCM(key).encrypt(nonce, dek, None)
    return eph_pub_raw + nonce + wrapped


def unwrap_dek(blob: bytes, recipient_priv_raw: bytes) -> bytes:
    """用收件者 X25519 私鑰解出 DEK。"""
    if len(recipient_priv_raw) != _DEK_LEN:
        raise ValueError("recipient private key 必須是 32-byte X25519 raw")
    eph_pub_raw = blob[:_X25519_PUB_LEN]
    nonce = blob[_X25519_PUB_LEN:_X25519_PUB_LEN + _NONCE_LEN]
    wrapped = blob[_X25519_PUB_LEN + _NONCE_LEN:]
    recipient_priv = X25519PrivateKey.from_private_bytes(recipient_priv_raw)
    recipient_pub_raw = recipient_priv.public_key().public_bytes_raw()
    shared = recipient_priv.exchange(X25519PublicKey.from_public_bytes(eph_pub_raw))
    key = HKDF(
        algorithm=hashes.SHA256(), length=32, salt=None,
        info=_WRAP_INFO + eph_pub_raw + recipient_pub_raw,
    ).derive(shared)
    return AESGCM(key).decrypt(nonce, wrapped, None)


# ── 高階：一次加密給多個收件者 ─────────────────────────────────────

def seal_for_recipients(plaintext: bytes, recipient_pubs: List[bytes], aad: bytes = b"") -> Dict:
    """
    加密內容並把 DEK 包給每個收件者。
    回傳：{ciphertext, nonce, wrapped_deks: {hex(pub): wrapped_bytes}}
    """
    if not recipient_pubs:
        raise ValueError("至少需一個收件者公鑰")
    dek = generate_dek()
    enc = encrypt_content(plaintext, dek, aad)
    wrapped = {pub.hex(): wrap_dek(dek, pub) for pub in recipient_pubs}
    return {"ciphertext": enc["ciphertext"], "nonce": enc["nonce"], "wrapped_deks": wrapped}


def open_sealed(ciphertext: bytes, nonce: bytes, wrapped_dek: bytes,
                recipient_priv_raw: bytes, aad: bytes = b"") -> bytes:
    """收件者用自己的 wrapped DEK + 私鑰解密內容。"""
    dek = unwrap_dek(wrapped_dek, recipient_priv_raw)
    return decrypt_content(ciphertext, dek, nonce, aad)
