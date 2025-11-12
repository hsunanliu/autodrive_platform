# AutoDrive Platform 專案概覽

## 專案簡介

AutoDrive 是一個基於區塊鏈的去中心化叫車平台，使用 SUI 區塊鏈進行支付結算。

## 技術棧

### 後端
- **框架**: FastAPI (Python)
- **數據庫**: PostgreSQL 15
- **快取**: Redis 7
- **WebSocket**: Socket.IO (實時通訊)
- **區塊鏈**: SUI Testnet
- **異步**: asyncio + asyncpg

### 前端
- **框架**: Flutter (Dart)
- **狀態管理**: StatefulWidget
- **地圖**: flutter_map + OpenStreetMap
- **WebSocket**: socket_io_client
- **HTTP**: http package

### 基礎設施
- **容器化**: Docker + Docker Compose
- **API 文檔**: FastAPI 自動生成 (Swagger UI)

## 核心功能

### 1. 用戶系統
- 雙角色支持（乘客 passenger / 司機 driver / 兩者 both）
- JWT 認證
- 錢包集成（SUI 錢包地址）

### 2. 車輛管理
- 車輛註冊
- 狀態管理（available, on_trip, offline, maintenance, busy）
- 位置追蹤
- **車輛召回**（新功能）- 司機可召回空閒車輛到指定位置

### 3. 行程系統
- 行程創建與配對
- 智能推送通知（半自動配對）
  - 推送給附近 10km 內的司機
  - 60 秒倒計時
  - 可接受或忽略
- 行程狀態追蹤
- 實時位置更新

### 4. 動態定價
- 多因素加權計算
  - 時間因素（30%）- 尖峰/離峰時段
  - 天氣因素（20%）- 惡劣天氣加價
  - 供需因素（50%）- 供需平衡
- 位置波動（±15%）

### 5. 支付系統
- SUI 鏈上支付
- 雙幣種顯示（SUI + USD）
- 平台費用分潤

### 6. WebSocket 實時通訊
- 新行程推送 (`new_trip_nearby`)
- 行程取消通知 (`trip_cancelled`)
- 支付完成通知 (`payment_completed`)

## 項目結構

```
autodrive_platform/
├── backend/                 # FastAPI 後端
│   ├── app/
│   │   ├── api/v1/         # API 端點
│   │   ├── models/         # 數據模型
│   │   ├── services/       # 業務邏輯
│   │   ├── websocket/      # WebSocket 管理
│   │   └── core/           # 核心配置
│   ├── migrations/         # 數據庫遷移
│   └── Dockerfile
├── mobile/                  # Flutter 前端
│   ├── lib/
│   │   ├── pages/          # 頁面組件
│   │   ├── widgets/        # 可重用組件
│   │   └── services/       # API & WebSocket 服務
│   └── pubspec.yaml
├── contracts/               # SUI 智能合約
├── dashboard/               # 管理後台（Node.js）
├── docker-compose.yml
└── .env                     # 環境變量

## 數據庫主要表結構

### users
- 用戶資訊（乘客、司機）
- 錢包地址
- 角色類型（user_type）

### vehicles
- 車輛資訊
- 當前位置（current_lat, current_lng）
- 狀態（status）
- **召回欄位**（recall_target_lat, recall_target_lng, recall_started_at）

### trips
- 行程資訊
- 起點/終點座標
- 價格（total_amount in MIST）
- 動態定價資訊（surge_multiplier, surge_reason）

## API 端點概覽

### 用戶
- `POST /api/v1/users/register` - 用戶註冊
- `POST /api/v1/users/login` - 用戶登入

### 車輛
- `GET /api/v1/vehicles/available` - 獲取可用車輛
- `POST /api/v1/vehicles` - 註冊車輛
- `GET /api/v1/vehicles/my` - 我的車輛

### 車輛召回（新）
- `GET /api/v1/vehicles/recall/available` - 可召回車輛列表
- `POST /api/v1/vehicles/recall/start` - 開始召回
- `POST /api/v1/vehicles/recall/complete` - 完成召回
- `POST /api/v1/vehicles/recall/cancel` - 取消召回
- `GET /api/v1/vehicles/recall/status/{vehicle_id}` - 召回狀態

### 行程
- `POST /api/v1/trips` - 創建行程
- `GET /api/v1/trips/available` - 可接單行程
- `POST /api/v1/trips/{trip_id}/accept` - 接受行程
- `POST /api/v1/trips/{trip_id}/cancel` - 取消行程

## 環境變量

主要配置（.env）：
- `DATABASE_URL` - PostgreSQL 連接字串
- `SUI_NODE_URL` - SUI 節點 URL
- `CONTRACT_PACKAGE_ID` - 智能合約包 ID
- `PLATFORM_WALLET_ADDRESS` - 平台錢包地址
- `OPERATOR_PRIVATE_KEY` - 操作錢包私鑰（僅用於 gas）

## 開發指令

```bash
# 啟動所有服務
docker-compose up -d

# 查看後端日誌
docker logs autodrive_platform-backend-1 -f

# 重啟後端
docker restart autodrive_platform-backend-1

# 執行數據庫遷移
docker exec autodrive_platform-db-1 psql -U autodrive -d autodrive_dev -f /path/to/migration.sql

# Flutter 開發
cd mobile
flutter run

# Flutter 分析
flutter analyze

# Flutter 構建
flutter build ios --debug --no-codesign
```

## 已知問題與注意事項

1. **Token 過期**: JWT token 有效期 24 小時，過期需重新登入
2. **地圖資源**: 使用 OpenStreetMap，需要網絡連接
3. **WebSocket 連接**: 司機端需手動初始化 WebSocket 連接
4. **車輛狀態**: 只有 'available' 狀態的車輛可被召回
5. **動態定價**: 每 5 分鐘刷新一次位置波動因子

## 最近更新

### 車輛召回系統 (2025-10-26)
- 新增車輛召回功能
- 司機可遠程召回空閒車輛
- 免費召回，預估到達時間
- 支持取消和狀態追蹤
