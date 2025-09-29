# backend/app/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import logging

# 設置日誌
logging.basicConfig(level=logging.INFO)
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
app.include_router(users_v1.router, prefix="/api/v1")    