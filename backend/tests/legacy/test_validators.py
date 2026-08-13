# backend/tests/test_validators.py
"""
測試所有驗證器函數
"""
import pytest
import re
from app.utils.validators import (
    password_strength_ok,
    phone_number_ok,
    email_format_ok,
    wallet_address_ok,
    did_identifier_ok,
    username_ok
)
from tests.utils.test_data import TEST_WALLET_ADDRESSES, TEST_DID_IDENTIFIERS


class TestPasswordValidation:
    """測試密碼強度驗證"""
    
    def test_strong_passwords(self):
        """
        測試強密碼(三種以上的字符類型都算強密碼)
        """
        strong_passwords = [
            "StrongPass123!",
            "MySecure456#",
            "Complex789$Password",
            "Test@123Password"
             "Password123"       
        ]
        
        for password in strong_passwords:
            assert password_strength_ok(password), f"Password should be strong: {password}"
    
    def test_weak_passwords(self):
        """測試弱密碼"""
        weak_passwords = [
            "weak",              # 太短
            "password",          # 只有小寫
            "PASSWORD",          # 只有大寫
            "12345678",         # 只有數字
            "Password",         # 只有兩種字符類型
           
        ]
        
        for password in weak_passwords:
            assert not password_strength_ok(password), f"Password should be weak: {password}"


class TestWalletAddressValidation:
    """測試錢包地址驗證"""
    
    def test_valid_addresses(self):
        """測試有效錢包地址"""
        for address in TEST_WALLET_ADDRESSES["valid"]:
            assert wallet_address_ok(address), f"Address should be valid: {address}"
    
    def test_invalid_addresses(self):
        """測試無效錢包地址"""
        for address in TEST_WALLET_ADDRESSES["invalid"]:
            assert not wallet_address_ok(address), f"Address should be invalid: {address}"


class TestUsernameValidation:
    """測試用戶名驗證"""
    
    def test_valid_usernames(self):
        """測試有效用戶名"""
        valid_usernames = [
            "alice123",
            "bob_driver",
            "test-user",
            "username",
            "user_123_test"
        ]
        
        for username in valid_usernames:
            assert username_ok(username), f"Username should be valid: {username}"
    
    def test_invalid_usernames(self):
        """測試無效用戶名"""
        invalid_usernames = [
            "ab",           # 太短
            "123user",      # 數字開頭
            "user@name",    # 包含特殊字符
            "a" * 51,       # 太長
            "",             # 空字符串
        ]
        
        for username in invalid_usernames:
            assert not username_ok(username), f"Username should be invalid: {username}"


class TestPhoneValidation:
    """測試電話號碼驗證"""
    
    def test_valid_phone_numbers(self):
        """測試有效電話號碼"""
        valid_phones = [
            "0912345678",
            "+886-912-345-678",
            "(02)1234-5678",
            "02-12345678",
            ""  # 空字符串（選填）
        ]
        
        for phone in valid_phones:
            assert phone_number_ok(phone), f"Phone should be valid: {phone}"
    
    def test_invalid_phone_numbers(self):
        """測試無效電話號碼"""
        invalid_phones = [
            "123",          # 太短
            "abcdefgh",     # 沒有數字
        ]
        
        for phone in invalid_phones:
            assert not phone_number_ok(phone), f"Phone should be invalid: {phone}"


class TestEmailValidation:
    """測試郵箱驗證"""
    
    def test_valid_emails(self):
        """測試有效郵箱"""
        valid_emails = [
            "test@example.com",
            "user.name@domain.co.uk",
            "test123@test-domain.org",
        ]
        
        for email in valid_emails:
            assert email_format_ok(email), f"Email should be valid: {email}"
    
    def test_invalid_emails(self):
        """測試無效郵箱"""
        invalid_emails = [
            "not_an_email",
            "@example.com",
            "test@",
            "test@.com",
            ""
        ]
        
        for email in invalid_emails:
            assert not email_format_ok(email), f"Email should be invalid: {email}"


class TestDIDValidation:
    """測試 DID 標識符驗證"""
    
    def test_valid_dids(self):
        """測試有效 DID"""
        for did in TEST_DID_IDENTIFIERS["valid"]:
            assert did_identifier_ok(did), f"DID should be valid: {did}"
        
        # 空值應該也是有效的（選填）
        assert did_identifier_ok(None)
        assert did_identifier_ok("")
    
    def test_invalid_dids(self):
        """測試無效 DID"""
        for did in TEST_DID_IDENTIFIERS["invalid"]:
            assert not did_identifier_ok(did), f"DID should be invalid: {did}"
