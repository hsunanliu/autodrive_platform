# backend/app/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import logging
import os

# 設置日誌
from app.core.logging_config import setup_logging

log_level = os.getenv("LOG_LEVEL", "INFO")
log_to_file = os.getenv("LOG_TO_FILE", "true").lower() == "true"
setup_logging(log_level=log_level, log_to_file=log_to_file)

logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    """應用生命週期管理"""
    logger.info("🚀 Starting AutoDrive API...")
    # 啟動時的初始化
    yield
    # 關閉時的清理
    logger.info("👋 Shutting down AutoDrive API...")

app = FastAPI(
    title="AutoDrive API",
    description="去中心化叫車平台 API",
    version="1.0.0",
    lifespan=lifespan
)

# CORS 設置
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 生產環境要改
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    return {
        "message": "🚗 AutoDrive API is running!",
        "status": "healthy",
        "docs": "/docs"
    }

@app.get("/health")
async def health_check():
    """健康檢查端點"""
    return {
        "status": "healthy",
        "services": {
            "api": "running",
            "database": "pending",  # 稍後實作
            "redis": "pending",     # 稍後實作
            "blockchain": "pending" # 稍後實作
        }
    }
from app.api.v1 import users as users_v1
from app.api.v1 import vehicles as vehicles_v1
from app.api.v1 import trips as trips_v1
from app.api.v1 import wallet as wallet_v1
from app.api.v1 import payment_proxy
from app.api.v1.admin import router as admin_router

app.include_router(users_v1.router, prefix="/api/v1")
app.include_router(vehicles_v1.router, prefix="/api/v1")
app.include_router(trips_v1.router, prefix="/api/v1")
app.include_router(wallet_v1.router, prefix="/api/v1/wallet", tags=["wallet"])
app.include_router(payment_proxy.router, prefix="/api/v1/payment", tags=["payment"])
app.include_router(admin_router, prefix="/api/v1")
