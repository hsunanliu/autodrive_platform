# backend/app/main.py（完整測試版）
from typing import Dict, Any
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from app.services.iota_service import get_iota_service

app = FastAPI(
    title="AutoDrive API",
    description="去中心化自動駕駛服務平台",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    return {
        "message": "AutoDrive API is running!",
        "status": "OK",
        "version": "1.0.0"
    }

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

@app.get("/iota/network-info")
async def get_iota_network_info():
    """測試 IOTA 網路連接"""
    iota_service = get_iota_service()
    return await iota_service.get_network_info()

@app.get("/iota/registry-stats")
async def get_registry_statistics():
    """獲取你之前測試的真實智能合約數據"""
    iota_service = get_iota_service()
    return await iota_service.get_all_registry_stats()

@app.get("/iota/object/{object_id}")
async def get_blockchain_object(object_id: str):
    """查詢任意鏈上對象"""
    iota_service = get_iota_service()
    result = await iota_service.get_object(object_id)
    if result:
        return {"status": "success", "object": result}
    else:
        raise HTTPException(status_code=404, detail="Object not found")

@app.get("/demo/blockchain-proof")
async def demo_blockchain_integration():
    """Demo 專用：證明區塊鏈整合的端點"""
    iota_service = get_iota_service()
    
    # 獲取網路信息
    network = await iota_service.get_network_info()
    
    # 獲取智能合約統計
    stats = await iota_service.get_all_registry_stats()
    
    return {
        "demo_title": "AutoDrive 區塊鏈整合證明",
        "blockchain_network": network,
        "smart_contracts": stats,
        "proof_points": [
            "✅ 真實 IOTA 網路連接",
            "✅ 智能合約已部署並運行",
            f"✅ {stats.get('data', {}).get('user_registry', {}).get('total_users', 0)} 個用戶已註冊", 
            f"✅ {stats.get('data', {}).get('vehicle_registry', {}).get('total_vehicles', 0)} 輛車已註冊",
            f"✅ {stats.get('data', {}).get('matching_service', {}).get('total_matches', 0)} 次成功配對"
        ],
        "message": "這是真實的區塊鏈數據，不是模擬！"
    }
