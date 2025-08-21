# Placeholder for crypto utils# backend/app/utils/crypto.py
"""
加密相關工具函數
處理密碼哈希、錢包地址驗證等
"""
import hashlib
import hmac
import secrets
from typing import Optional


def generate_random_hex(length: int = 32) -> str:
    """
    生成隨機十六進制字符串
    
    Args:
        length: 字節長度
        
    Returns:
        str: 十六進制字符串
    """
    return secrets.token_hex(length)


def hash_sensitive_data(data: str, salt: Optional[str] = None) -> tuple[str, str]:
    """
    對敏感數據進行哈希處理
    
    Args:
        data: 要哈希的數據
        salt: 鹽值（如果不提供會自動生成）
        
    Returns:
        tuple: (哈希值, 鹽值)
    """
    if salt is None:
        salt = generate_random_hex(16)
    
    # 使用 PBKDF2 進行哈希
    hash_value = hashlib.pbkdf2_hmac(
        'sha256',
        data.encode('utf-8'),
        salt.encode('utf-8'),
        100000  # 迭代次數
    )
    
    return hash_value.hex(), salt


def verify_sensitive_data(data: str, hash_value: str, salt: str) -> bool:
    """
    驗證敏感數據
    
    Args:
        data: 原始數據
        hash_value: 哈希值
        salt: 鹽值
        
    Returns:
        bool: 是否匹配
    """
    computed_hash, _ = hash_sensitive_data(data, salt)
    return hmac.compare_digest(computed_hash, hash_value)


def normalize_wallet_address(address: str) -> str:
    """
    標準化錢包地址格式
    
    Args:
        address: 原始地址
        
    Returns:
        str: 標準化後的地址（小寫）
    """
    return address.lower().strip()
