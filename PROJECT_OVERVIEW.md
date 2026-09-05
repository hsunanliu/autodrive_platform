# ChainSUI（AutoDrive）專案架構與需求總覽

**更新日期**: 2026-07-12
**專案狀態**: 生產級安全加固完成；Agent 委託 / Walrus / ZKP 已導入（`sui move test` 13/13 PASS）
**專案定位**: side project，目標是做到生產級品質（原定參加 Sui Overflow 2026，已於 2026-09 取消參賽）

> 📌 生產級加固的完整進度、問題清單、驗證方式見 **[`docs/PRODUCTION_HARDENING_ROADMAP.md`](docs/PRODUCTION_HARDENING_ROADMAP.md)**（單一事實來源）。

---

## 🎯 專案定位

**ChainSUI** 是一個基於 **Sui 區塊鏈**的去中心化 DePIN 叫車平台，含能為乘客/司機自動報價、搓合、並在受限授權下代發交易的 AI Agent。

### 核心價值
1. **Agent 能力委託（Agentic Web）** - 用戶以 `OperatorCap` 授權 Agent 在額度/時效/動作白名單內代發交易；私鑰留在用戶端。
2. **去中心化支付** - Sui 智能合約託管支付；釋放需乘客簽章或 Agent 的 OperatorCap。
3. **去中心化存儲（Walrus）** - GPS 軌跡、評價、退款佐證存 Walrus，鏈上只錨定 blob_id + 雜湊。
4. **ZKP / DID 身分** - `sui::groth16` 原生驗證年齡/駕照，不揭露個資。
5. **透明定價 + 即時通訊** - 動態定價、Socket.IO 低延遲通知。
6. **跨平台** - Flutter 移動端 + React 管理後台。

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

### 智能合約模組（實際）
```
// contracts/sources/
agent/agent_registry.move          // OperatorCap 委託（額度/時效/動作白名單/撤銷）
financial/payment_escrow.move      // 託管鎖定/釋放/退款；釋放需乘客或 OperatorCap；複合原子結算
financial/refund_module_v2.move    // 退款池，出金需 RefundCapability
identity/credential_verifier.move  // sui::groth16 原生 ZKP 驗證 + AdminCap
identity/did_registry.move         // DID（內嵌位址綁定 controller）
identity/user_registry.move        // 用戶（信譽由 admin 把關，防自我提權）
identity/vehicle_registry.move     // 車輛
identity/trusted_issuers.move      // 受信任 VC 簽發者
business/trip_receipt.move         // 行程收據（錨定 Walrus 軌跡 blob）
business/rating_proof.move         // 評價存證（綁行程；錨定 Walrus 內容 blob）
utils/{constants,events}.move      // 常數（含 2.5% 平台費率）、事件
```

> 安全設計：資金移動/狀態變更皆有存取控管（Capability 或 sender/witness 斷言）；
> 合約安全測試見 `contracts/tests/security_tests.move`（13 tests）。

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
完整範例見 `backend/.env.example`。關鍵變數（非 DEBUG 模式缺少會 fail-fast）：
```env
DEBUG=false
DATABASE_URL=postgresql+asyncpg://USER:PASSWORD@HOST:5432/autodrive
SECRET_KEY=            # openssl rand -hex 32
CORS_ALLOW_ORIGINS=http://localhost:3000
SUI_NODE_URL=https://fullnode.testnet.sui.io:443
CONTRACT_PACKAGE_ID=  # 由 scripts/ops/deploy_and_init.sh 取得
OPERATOR_PRIVATE_KEY= # Agent/平台金鑰，由 secret manager 注入，勿落地
MOCK_MODE=false
WALRUS_PUBLISHER_URL=https://publisher.walrus-testnet.walrus.space
WALRUS_AGGREGATOR_URL=https://aggregator.walrus-testnet.walrus.space
```
> ⚠️ 切勿把真實私鑰/金鑰提交或落地 `.env`；生產請用 secret manager。

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

**最後更新**: 2026-07-12
**版本**: v2.0（生產級安全加固 + Agent 委託 + Walrus + ZKP）
**狀態**: ✅ 合約安全加固完成（13 tests PASS）| ✅ 後端安全加固 | 🟡 Agent/Walrus 部署後接續（見路線圖）
