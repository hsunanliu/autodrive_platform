# backend/app/utils/validators.py
"""
用戶資料驗證工具
借鑒 Flask 範例的驗證邏輯，適配到 FastAPI + 區塊鏈環境
"""
import re
from typing import Optional


def password_strength_ok(password: str) -> bool:
    """
    密碼強度檢查（借鑒 Flask 範例）
    
    要求：
    - 至少 8 個字符
    - 至少包含 3 種字符類型：小寫、大寫、數字、特殊字符
    
    Args:
        password: 要檢查的密碼
        
    Returns:
        bool: 密碼是否符合強度要求
    """
    if not password or len(password) < 8:
        return False
    
    # 統計字符類型
    char_types = 0
    char_types += any(c.islower() for c in password)   # 小寫字母
    char_types += any(c.isupper() for c in password)   # 大寫字母  
    char_types += any(c.isdigit() for c in password)   # 數字
    char_types += any(not c.isalnum() for c in password)  # 特殊字符
    
    return char_types >= 3


def phone_number_ok(phone: str) -> bool:
    """
    電話號碼格式檢查
    
    要求：
    - 可以為空（選填欄位）
    - 如果填寫，至少包含 8 個數字
    - 支援各種格式：+886-912-345-678, 0912345678, (02)1234-5678
    
    Args:
        phone: 電話號碼字符串
        
    Returns:
        bool: 格式是否正確
    """
    if not phone:
        return True  # 電話號碼是選填的
    
    # 提取所有數字
    digits = ''.join(c for c in phone if c.isdigit())
    
    # 至少需要 8 個數字
    return len(digits) >= 8


def email_format_ok(email: str) -> bool:
    """
    Email 格式基本檢查
    
    Args:
        email: Email 地址
        
    Returns:
        bool: 格式是否正確
    """
    if not email:
        return False
    
    # 基本格式檢查：必須包含 @ 和 .
    if '@' not in email or '.' not in email:
        return False
    
    # 使用正規表達式進行更詳細的檢查
    email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(email_pattern, email) is not None


def wallet_address_ok(address: str) -> bool:
    """
    IOTA 錢包地址格式檢查
    
    IOTA 地址格式：0x + 64位十六進制字符 = 64字符總長
    
    Args:
        address: 錢包地址
        
    Returns:
        bool: 格式是否正確
    """
    if not address:
        return False
    
    # 檢查格式：0x 開頭，總長度 66
    if not address.startswith('0x') or len(address) != 66:
        return False
    
    # 檢查十六進制字符
    hex_part = address[2:]  # 去掉 0x
    try:
        int(hex_part, 16)  # 嘗試解析為十六進制
        return True
    except ValueError:
        return False


def did_identifier_ok(did: Optional[str]) -> bool:
    """
    DID 標識符格式檢查
    
    DID 格式範例：did:method:identifier
    
    Args:
        did: DID 標識符（可選）
        
    Returns:
        bool: 格式是否正確
    """
    if not did:
        return True  # DID 是選填的
    
    # 基本格式：必須以 "did:" 開頭，且包含至少兩個冒號
    if not did.startswith('did:') or did.count(':') < 2:
        return False
    
    return True


def username_ok(username: str) -> bool:
    """
    用戶名格式檢查
    
    要求：
    - 3-50 個字符
    - 只能包含字母、數字、下劃線、連字符
    - 不能以數字開頭
    
    Args:
        username: 用戶名
        
    Returns:
        bool: 格式是否正確
    """
    if not username:
        return False
    
    # 長度檢查
    if len(username) < 3 or len(username) > 50:
        return False
    
    # 字符檢查：只允許字母、數字、下劃線、連字符
    if not re.match(r'^[a-zA-Z][a-zA-Z0-9_-]*$', username):
        return False
    
    return True
