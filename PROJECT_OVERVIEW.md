# AutoDrive 專案架構與需求總覽

**更新日期**: 2025-10-24
**專案狀態**: 動態定價系統整合完成，待測試

---

## 🎯 專案定位

**AutoDrive** 是一個基於 **Sui 區塊鏈**的去中心化叫車平台，結合 Web3 技術實現透明、安全的共享經濟服務。

### 核心價值
1. **去中心化支付** - 使用 Sui 區塊鏈智能合約管理託管支付
2. **透明定價** - 動態定價機制公開透明，用戶可選擇
3. **即時通訊** - WebSocket 實現低延遲的即時通知
4. **跨平台** - Flutter 移動端 + React 管理後台

---

## 🏗️ 技術架構

### 系統分層

```
┌─────────────────────────────────────────────────────────┐
│                  使用者層 (User Layer)                    │
├──────────────────────┬──────────────────────────────────┤
│  Flutter Mobile App  │     React Admin Dashboard        │
│  - 乘客端             │     - 平台管理                    │
│  - 司機端             │     - 數據分析                    │
└──────────────────────┴──────────────────────────────────┘
                          ↕ HTTP + WebSocket
┌─────────────────────────────────────────────────────────┐
│            業務邏輯層 (Business Logic Layer)              │
│              FastAPI Backend (Python 3.11)               │
│  - RESTful API                                          │
│  - WebSocket Server (Socket.IO)                         │
│  - 動態定價引擎                                           │
│  - 自動升級任務                                           │
└─────────────────────────────────────────────────────────┘
          ↕                                ↕
┌──────────────────────┐      ┌──────────────────────────┐
│   資料層 (Data)       │      │   區塊鏈層 (Blockchain)   │
│   PostgreSQL         │      │   Sui Blockchain         │
│   - 用戶資料          │      │   - Move 智能合約         │
│   - 行程記錄          │      │   - 支付託管             │
│   - 車輛資訊          │      │   - 交易驗證             │
│   - 定價配置          │      │   - 錢包管理             │
└──────────────────────┘      └──────────────────────────┘
```

---

## 💰 區塊鏈整合 - Sui

### 使用 Sui 區塊鏈的原因
1. **高性能** - 低延遲、高吞吐量
2. **Move 語言** - 安全的智能合約編程語言
3. **並行處理** - 支持大規模並發交易
4. **低 Gas 費** - 適合小額支付場景

### 代幣與單位
- **原生代幣**: SUI
- **最小單位**: MIST
- **換算**: 1 SUI = 1,000,000,000 MIST (10^9)
- **後端儲存**: micro SUI (實際上就是 MIST)
- **前端顯示**: SUI (需除以 10^9)

### 智能合約功能
```move
// contracts/sources/
- user_registry.move      // 用戶註冊與驗證
- vehicle_registry.move   // 車輛註冊
- ride_escrow.move        // 行程託管支付
- payment.move            // 支付處理
```

---

## 🚀 核心功能模組

### 1. 動態定價系統 (Dynamic Pricing)

#### 定價策略
```python
# 時段因素
- 尖峰時段 (7-9am, 5-7pm): 1.5x
- 深夜時段 (11pm-5am): 1.3x
- 週末白天 (10am-8pm): 1.2x

# 供需因素
- 需求/供給 ≥ 3.0: 2.5x
- 需求/供給 ≥ 2.0: 2.0x
- 需求/供給 ≥ 1.5: 1.5x
- 需求/供給 < 1.0: 1.0x

# 天氣因素 (Phase 2)
- 預留接口，尚未整合
```

#### 用戶選擇機制
| 選項 | 價格 | 優先級 | 特性 |
|------|------|--------|------|
| 🚗 標準叫車 | 固定價格 | Priority 2 | 可能等待較久 |
| ⚡ 快速叫車 | 動態定價 | Priority 1 | 優先媒合司機 |

**重要**：
- 所有訂單都**立即推送**給司機，無人為延遲
- 差異僅在司機端的**顯示順序** (Priority 1 在上方)
- Priority 2 訂單等待 15 分鐘後**自動升級**為 Priority 1（維持原價）

---

### 2. WebSocket 即時通訊

#### 事件類型
**乘客端監聽**:
- `trip_accepted` - 司機已接單
- `trip_started` - 行程開始
- `trip_completed` - 行程完成
- `trip_cancelled` - 行程取消
- `driver_location_update` - 司機位置更新

**司機端監聽**:
- `new_trip_available` - 新訂單通知
- `trip_cancelled` - 乘客取消

#### 技術實作
- **協議**: Socket.IO
- **認證**: JWT Token
- **重連**: 自動重連機制
- **房間**: 每個行程一個房間 (trip_id)

#### 效能提升
| 指標 | 輪詢 (舊) | WebSocket (新) | 改善 |
|------|----------|---------------|------|
| 延遲 | 10 秒 | <1 秒 | ⬇️ 90% |
| 網路請求/分鐘 | 6 次 | 0 次 | ⬇️ 100% |
| 電池消耗 | 高 | 低 | ⬇️ 50% |

---

### 3. 自動升級機制

#### 背景任務
```python
# backend/app/tasks/auto_upgrade.py
執行週期: 每 5 分鐘
觸發條件: Priority 2 訂單等待 > 15 分鐘
升級動作: Priority 2 → Priority 1 (維持原價)
```

#### 運作邏輯
```sql
-- 查找符合條件的訂單
SELECT trip_id FROM trips
WHERE priority = 2
  AND status = 'requested'
  AND requested_at < NOW() - INTERVAL '15 minutes';

-- 升級為 Priority 1
UPDATE trips
SET priority = 1,
    estimated_wait_minutes = EXTRACT(EPOCH FROM (NOW() - requested_at)) / 60
WHERE trip_id IN (...);
```

---

## 📊 資料庫設計

### 核心表結構

#### trips 表 (行程)
```sql
trip_id                  SERIAL PRIMARY KEY
passenger_id             INTEGER NOT NULL
driver_id                INTEGER
status                   VARCHAR(20) -- requested, matched, completed, etc.
fare                     FLOAT
total_amount             BIGINT      -- micro SUI
distance_km              FLOAT

-- 動態定價欄位 (新增)
surge_multiplier         FLOAT DEFAULT 1.0
surge_reason             VARCHAR(200)
price_type               VARCHAR(20) DEFAULT 'standard'  -- standard/dynamic
priority                 INTEGER DEFAULT 2                -- 1=快速, 2=標準
estimated_wait_minutes   INTEGER
actual_wait_minutes      INTEGER

-- 時間戳
requested_at             TIMESTAMP
matched_at               TIMESTAMP
completed_at             TIMESTAMP
```

#### users 表 (用戶)
```sql
user_id                  SERIAL PRIMARY KEY
username                 VARCHAR(50) UNIQUE
user_type                VARCHAR(10)  -- passenger/driver
wallet_address           VARCHAR(66) UNIQUE
total_earnings_micro_sui VARCHAR(100)
```

#### vehicles 表 (車輛)
```sql
vehicle_id               VARCHAR(50) PRIMARY KEY
owner_id                 INTEGER
status                   VARCHAR(20)  -- available, busy, offline
current_lat              FLOAT
current_lng              FLOAT
total_earnings_micro_sui VARCHAR(100)
```

---

## 🎨 前端架構 (Flutter)

### 頁面結構
```
lib/
├── main.dart                        // 應用入口
├── passenger_home_page.dart         // 乘客首頁 ✅ 已整合動態定價
├── driver_home_page.dart            // 司機首頁
├── pages/
│   ├── available_trips_page.dart    // 司機待接單 ✅ 已顯示優先級
│   ├── trip_history_page.dart       // 行程歷史
│   └── payment_page.dart            // 支付頁面
├── services/
│   ├── api_service.dart             // API 呼叫 ✅ 已加入動態定價參數
│   └── websocket_service.dart       // WebSocket 連接 ✅ 已整合
└── widgets/
    └── google_place_search_field.dart
```

### 狀態管理
- 使用 `StatefulWidget` 管理頁面狀態
- WebSocket 事件觸發 `setState()` 更新 UI
- Session 管理: `SessionManager` 儲存用戶登入資訊

---

## 📡 API 端點

### 行程相關
```
POST   /api/v1/trips/estimate        估算行程價格 (返回雙價格)
POST   /api/v1/trips/                創建行程 (含 use_dynamic_pricing)
GET    /api/v1/trips/                查詢用戶行程
GET    /api/v1/trips/available       司機端查詢待接單 (按 priority 排序)
POST   /api/v1/trips/{id}/accept     司機接單
PUT    /api/v1/trips/{id}/complete   完成行程
PUT    /api/v1/trips/{id}/cancel     取消行程
```

### 用戶相關
```
POST   /api/v1/users/register        用戶註冊
POST   /api/v1/users/login           用戶登入
GET    /api/v1/users/{id}            查詢用戶資料
```

### 支付相關
```
POST   /api/v1/payment/process-payment      處理支付
GET    /api/v1/payment/temp-escrow-address  獲取託管地址
```

---

## 🧪 測試狀態

### 後端測試 ✅
- **測試報告**: `TEST_REPORT_2025_10_24.md`
- **通過率**: 100% (5/5)
- **測試項目**:
  1. ✅ 行程預估 API - 返回雙價格
  2. ✅ 創建快速叫車（動態定價）
  3. ✅ 創建標準叫車（固定價格）
  4. ✅ 司機查詢待接訂單 - 優先級排序
  5. ✅ 自動升級機制驗證

### 前端整合 ✅ (程式碼完成)
- **整合報告**: `FRONTEND_INTEGRATION_2025_10_24.md`
- **完成項目**:
  1. ✅ 乘客頁面顯示兩種價格選項
  2. ✅ 司機頁面顯示優先級標籤
  3. ✅ 移除 Timer.periodic 輪詢
  4. ✅ 整合 WebSocket 事件監聽
  5. ⏳ **前端測試待進行**

---

## 📋 當前任務清單

### 立即執行（本週）
- [ ] **前端功能測試** - 最高優先級
  - [ ] 乘客端價格選項顯示測試
  - [ ] 司機端優先級標籤測試
  - [ ] WebSocket 即時通知測試
  - [ ] 端到端流程測試

### 短期優化（下週）
- [ ] 確認 WebSocket 自動連接（登入後）
- [ ] UI/UX 優化（動畫、間距、顏色）
- [ ] 錯誤處理優化
- [ ] 即時位置追蹤地圖整合

### 中期規劃（本月）
- [ ] 天氣 API 整合 (Phase 2)
- [ ] 推送通知 (FCM)
- [ ] 行程評價系統
- [ ] 司機-乘客聊天功能

### 長期規劃（下個月）
- [ ] 多語言支援
- [ ] 性能優化（圖片快取、地圖渲染）
- [ ] 多伺服器部署（Redis Adapter）
- [ ] 負載平衡

---

## 🔧 開發環境設定

### 後端啟動
```bash
cd backend
docker-compose up -d          # 啟動 PostgreSQL + Redis
python -m app.main            # 啟動 FastAPI (含 WebSocket)
```

### 前端啟動
```bash
cd mobile
flutter pub get               # 安裝依賴
flutter run                   # 啟動應用
```

### 測試執行
```bash
# 後端 API 測試
cd backend
python test_api.py

# 前端測試（待實作）
cd mobile
flutter test
```

---

## 📝 重要配置

### 後端環境變數 (.env)
```env
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/autodrive_dev
SECRET_KEY=your-secret-key
SUI_NETWORK=testnet
SUI_RPC_URL=https://fullnode.testnet.sui.io:443
```

### 前端 API 端點
```dart
// mobile/lib/services/api_service.dart
static const String baseUrl = 'http://192.168.66.54:8000/api/v1';
```

### WebSocket 端點
```
ws://192.168.66.54:8000/
```

---

## 🎯 專案目標與成功指標

### 短期目標 (Q4 2024)
- ✅ 動態定價系統上線
- ✅ WebSocket 即時通訊
- ⏳ 前端 UI 整合完成
- ⏳ Beta 測試

### 中期目標 (Q1 2025)
- 天氣因素整合
- 用戶數 > 100
- 日均訂單 > 50

### 長期目標 (2025)
- 多城市擴展
- 主網上線
- 去中心化治理

---

## 📞 技術支援與文檔

### 核心文檔
- **專案總覽**: `README.md`
- **功能文檔**: `FEATURES.md`
- **變更日誌**: `CHANGELOG_2025_10_22.md`
- **WebSocket 實作**: `WEBSOCKET_IMPLEMENTATION.md`
- **後端測試報告**: `TEST_REPORT_2025_10_24.md`
- **前端整合報告**: `FRONTEND_INTEGRATION_2025_10_24.md`

### API 文檔
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

### 區塊鏈資源
- Sui 文檔: https://docs.sui.io
- Sui Explorer: https://suiexplorer.com
- Move 教程: https://examples.sui.io

---

## 🤝 團隊與貢獻

### 核心開發
- **後端開發**: Python + FastAPI + SQLAlchemy
- **前端開發**: Flutter + Dart
- **智能合約**: Move Language
- **DevOps**: Docker + PostgreSQL

### 貢獻指南
1. Fork 專案
2. 創建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交變更 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 開啟 Pull Request

---

**最後更新**: 2025-10-24
**版本**: v1.0 (動態定價整合完成)
**狀態**: ✅ 後端完成 | ✅ 前端整合完成 | ⏳ 測試待進行
