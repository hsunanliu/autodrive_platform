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
    
    # IOTA 配置
    IOTA_NODE_URL: str = "https://api.testnet.iota.cafe"
    IOTA_NETWORK: str = "testnet"
    CONTRACT_PACKAGE_ID: str = "0xa353f4acea9dbacd0cc7af37479b277299160d9288495d017ec4d824ea7a5d31"
    USER_REGISTRY_ID: str = "0x9bdeefc53afba9fca554dc61025514e21fb4e9f9281ad4449bca86f72f18dd5f"
    VEHICLE_REGISTRY_ID: str = "0xfaf54e90664e669943e07e9845dbd2523e71920b04dd5bf264700a68c1370ce4"
    MATCHING_SERVICE_ID: str = "0xa700e716702ae263edc3db7201da6235231e4b76a534c3bb23842eb92a29bfda"
    PLATFORM_WALLET: str = "0x0000000000000000000000000000000000000000000000000000000000000000"
    
    # Mock 模式設置（測試用）
    MOCK_MODE: bool = True
    
    class Config:
        env_file = ".env"
        case_sensitive = True


# 創建全局設置實例
settings = Settings()
