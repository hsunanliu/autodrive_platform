# backend/tests/utils/test_data.py
"""
測試用的示範資料
"""

# 有效的測試資料
VALID_USER_DATA = {
    "username": "alice123",
    "wallet_address": "0x9bdeefc53afba9fca554dc61025514e21fb4e9f9281ad4449bca86f72f18dd5f",
    "email": "alice@example.com",
    "password": "StrongPass123!",
    "phone_number": "0912345678",
    "user_type": "passenger"
}

VALID_DRIVER_DATA = {
    "username": "driver_bob",
    "wallet_address": "0x742d35cc8686c6ebb13c6b3dc4f3c7e6a6fd9ff3abc123def456789abcdef123",
    "email": "bob@example.com", 
    "password": "DriverPass456#",
    "phone_number": "0987654321",
    "user_type": "driver"
}

# 無效的測試資料
INVALID_USER_DATA = [
    {
        "name": "短用戶名",
        "data": {
            "username": "ab",  # 太短
            "wallet_address": "0x742d35cc8686c6ebb13c6b3dc4f3c7e6a6fd9ff3abc123def456789abcdef123",
            "password": "StrongPass123!"
        }
    },
    {
        "name": "無效錢包地址",
        "data": {
            "username": "alice123",
            "wallet_address": "invalid_address",
            "password": "StrongPass123!"
        }
    },
    {
        "name": "弱密碼",
        "data": {
            "username": "alice123",
            "wallet_address": "0x742d35cc8686c6ebb13c6b3dc4f3c7e6a6fd9ff3abc123def456789abcdef123",
            "password": "weak"
        }
    },
    {
        "name": "無效郵箱",
        "data": {
            "username": "alice123",
            "wallet_address": "0x742d35cc8686c6ebb13c6b3dc4f3c7e6a6fd9ff3abc123def456789abcdef123",
            "password": "StrongPass123!",
            "email": "not_an_email"
        }
    }
]

# 測試錢包地址
TEST_WALLET_ADDRESSES = {
    "valid": [
        "0x9bdeefc53afba9fca554dc61025514e21fb4e9f9281ad4449bca86f72f18dd5f",
        "0x742d35cc8686c6ebb13c6b3dc4f3c7e6a6fd9ff3abc123def456789abcdef123",
        "0x123abc456def789012345678901234567890abcdef123456789abcdef0123456"
    ],
    "invalid": [
        "invalid_address",
        "0x123",  # 太短
        "742d35cc...",  # 沒有 0x 開頭
        "0xZZZ...",  # 非十六進制字符
    ]
}

# 測試 DID 標識符
TEST_DID_IDENTIFIERS = {
    "valid": [
        "did:iota:alice_verified",
        "did:example:123456789abcdef",
        "did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK"
    ],
    "invalid": [
        "not_a_did",
        "did:",  # 不完整
        "did:method",  # 缺少標識符
    ]
}
