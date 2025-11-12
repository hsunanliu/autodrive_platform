# backend/app/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import logging
import os
import socketio

# 設置日誌
from app.core.logging_config import setup_logging

log_level = os.getenv("LOG_LEVEL", "INFO")
log_to_file = os.getenv("LOG_TO_FILE", "true").lower() == "true"
setup_logging(log_level=log_level, log_to_file=log_to_file)

logger = logging.getLogger(__name__)

# 初始化 Socket.IO
sio = socketio.AsyncServer(
    async_mode="asgi",
    cors_allowed_origins="*",  # 生產環境要改
    logger=True,
    engineio_logger=True
)

# 全局變數來存儲 WebSocket 管理器和通知器
from app.websocket.manager import ConnectionManager
from app.websocket.notifier import WebSocketNotifier
from app.websocket.events import register_socketio_events

# 創建連接管理器
connection_manager = ConnectionManager(sio)
# 創建通知器
websocket_notifier = WebSocketNotifier(connection_manager)

# 註冊 Socket.IO 事件
register_socketio_events(sio, connection_manager)

# 設置全局通知器，讓其他模組可以使用
from app.websocket.dependencies import set_notifier
set_notifier(websocket_notifier)

@asynccontextmanager
async def lifespan(app: FastAPI):
    """應用生命週期管理"""
    logger.info("🚀 Starting AutoDrive API...")
    logger.info("📡 WebSocket 伺服器已初始化")

    # 啟動背景任務
    from app.tasks import start_auto_upgrade_task
    start_auto_upgrade_task()
    logger.info("⏰ 自動升級背景任務已啟動")

    # 啟動定時任務調度器
    from app.services.scheduler_service import scheduler_service
    scheduler_service.start()
    logger.info("⏰ 定時任務調度器已啟動")

    # 啟動時的初始化
    yield
    # 關閉時的清理
    logger.info("👋 Shutting down AutoDrive API...")

    # 關閉定時任務調度器
    scheduler_service.shutdown()

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
from app.api.v1 import refunds as refunds_v1
from app.api.v1 import ipfs as ipfs_v1
from app.api.v1.admin import router as admin_router

app.include_router(users_v1.router, prefix="/api/v1")
app.include_router(vehicles_v1.router, prefix="/api/v1")
app.include_router(trips_v1.router, prefix="/api/v1")
app.include_router(wallet_v1.router, prefix="/api/v1/wallet", tags=["wallet"])
app.include_router(payment_proxy.router, prefix="/api/v1/payment", tags=["payment"])
app.include_router(refunds_v1.router, prefix="/api/v1")
app.include_router(ipfs_v1.router, prefix="/api/v1")
app.include_router(admin_router, prefix="/api/v1")

# 掛載 Socket.IO 應用
socket_app = socketio.ASGIApp(sio, app)

# 導出 socket_app 作為 ASGI 應用
# 注意：在 uvicorn 運行時需要使用 socket_app 而不是 app
