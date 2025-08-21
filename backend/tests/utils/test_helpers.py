# backend/tests/utils/test_helpers.py
"""
測試輔助函數
"""
import json
from typing import Dict, Any
from httpx import AsyncClient


async def create_test_user(client: AsyncClient, user_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    通過 API 創建測試用戶
    """
    response = await client.post("/api/v1/users", json=user_data)
    return response


async def login_user(client: AsyncClient, identifier: str, password: str) -> str:
    """
    用戶登入並返回 access token
    """
    response = await client.post("/api/v1/auth/login", json={
        "identifier": identifier,
        "password": password
    })
    
    if response.status_code == 200:
        return response.json()["access_token"]
    else:
        raise Exception(f"Login failed: {response.text}")


def get_auth_headers(token: str) -> Dict[str, str]:
    """
    生成認證標頭
    """
    return {"Authorization": f"Bearer {token}"}


def assert_user_response_structure(user_data: Dict[str, Any]):
    """
    驗證用戶響應數據結構
    """
    required_fields = [
        "id", "username", "wallet_address", "user_type",
        "reputation_score", "is_verified", "is_active",
        "created_at"
    ]
    
    for field in required_fields:
        assert field in user_data, f"Missing required field: {field}"


def assert_error_response(response_data: Dict[str, Any], expected_status: int = 400):
    """
    驗證錯誤響應格式
    """
    assert "detail" in response_data or "error" in response_data
