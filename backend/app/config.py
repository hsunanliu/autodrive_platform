# backend/app/config.py
"""
應用配置管理
"""
import os
from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    """應用設置"""
    
    # 應用基礎配置
    APP_NAME: str = "AutoDrive API"
    DEBUG: bool = True
    API_V1_STR: str = "/api/v1"
    
    # 數據庫配置
    DATABASE_URL: str = os.getenv("DATABASE_URL", "postgresql+asyncpg://autodrive:autodrive2025@db:5432/autodrive_dev")
    
    # Redis 配置
    REDIS_URL: str = "redis://redis:6379"
    
    # 安全配置
    SECRET_KEY: str = "your-secret-key-change-in-production"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    ALGORITHM: str = "HS256"
    
    # Sui 配置
    SUI_NODE_URL: str = os.getenv("SUI_NODE_URL", "https://fullnode.testnet.sui.io:443")
    SUI_NETWORK: str = os.getenv("SUI_NETWORK", "testnet")
    CONTRACT_PACKAGE_ID: str = os.getenv("CONTRACT_PACKAGE_ID", "")
    USER_REGISTRY_ID: str = os.getenv("USER_REGISTRY_ID", "")
    VEHICLE_REGISTRY_ID: str = os.getenv("VEHICLE_REGISTRY_ID", "")
    MATCHING_SERVICE_ID: str = os.getenv("MATCHING_SERVICE_ID", "")
    PLATFORM_WALLET: str = os.getenv("PLATFORM_WALLET_ADDRESS", "0x0000000000000000000000000000000000000000000000000000000000000000")
    
    # Mock 模式設置（默認關閉，使用真實區塊鏈驗證）
    MOCK_MODE: bool = os.getenv("MOCK_MODE", "false").lower() == "true"
    
    # 真實區塊鏈交互模式
    REAL_BLOCKCHAIN_MODE: bool = os.getenv("REAL_BLOCKCHAIN_MODE", "false").lower() == "true"
    
    # 操作錢包私鑰（僅用於支付 gas 費用，不涉及資金轉移）
    # 資金流向：乘客 → 智能合約 → 司機（直接轉帳）
    OPERATOR_PRIVATE_KEY: str = os.getenv("OPERATOR_PRIVATE_KEY", "")
    
    class Config:
        env_file = ".env"
        case_sensitive = True


# 創建全局設置實例
settings = Settings()
