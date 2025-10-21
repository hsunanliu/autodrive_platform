# AutoDrive Platform

> 基於 Sui 區塊鏈的去中心化叫車平台

## 📖 專案簡介

AutoDrive 是一個創新的去中心化叫車平台，利用區塊鏈技術實現透明、安全的交易和支付系統。

### 核心特色

- 🔐 **區塊鏈支付** - 使用 Sui 區塊鏈進行安全的點對點交易
- 📱 **跨平台應用** - Flutter 開發的 iOS/Android 應用
- 🎛️ **管理後台** - React 開發的 Web 管理系統
- 🤖 **智能合約** - Move 語言編寫的自動化合約邏輯
- 🔄 **即時追蹤** - 實時行程狀態更新

## 🏗️ 系統架構

```
┌─────────────────────────────────────────────────────────┐
│                    Frontend Layer                        │
├──────────────────────┬──────────────────────────────────┤
│   Flutter App        │      React Dashboard             │
│   (iOS/Android)      │      (Web Admin)                 │
└──────────────────────┴──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│              Backend API (Python + FastAPI)              │
│  - 業務邏輯處理                                           │
│  - 智能合約互動                                           │
│  - 資料庫管理                                             │
└─────────────────────────────────────────────────────────┘
                           │
          ┌────────────────┴────────────────┐
          ▼                                  ▼
┌──────────────────────┐        ┌──────────────────────┐
│   PostgreSQL DB      │        │   Sui Blockchain     │
│   - 用戶資料          │        │   - 智能合約          │
│   - 行程記錄          │        │   - 支付託管          │
│   - 交易記錄          │        │   - 交易驗證          │
└──────────────────────┘        └──────────────────────┘
```

### 技術棧

**後端**
- Python 3.11+
- FastAPI
- SQLAlchemy
- PostgreSQL
- Sui SDK

**前端 (Mobile)**
- Flutter 3.x
- Dart
- Google Maps API

**前端 (Dashboard)**
- React 18
- Vite
- Axios
- Recharts

**智能合約**
- Move Language
- Sui Framework

## 🚀 快速開始

### 環境需求

- Python 3.11+
- Node.js 18+
- Flutter 3.x
- Docker & Docker Compose
- PostgreSQL 15+

### 安裝步驟

1. **Clone 專案**
```bash
git clone <repository-url>
cd autodrive_platform
```

2. **啟動後端服務**
```bash
cd backend
pip install -r requirements.txt
docker-compose up -d  # 啟動 PostgreSQL
python -m app.main    # 啟動 API 服務
```

3. **啟動 Dashboard**
```bash
cd dashboard
npm install
npm run dev
```

4. **啟動 Mobile App**
```bash
cd mobile
flutter pub get
flutter run
```

### 配置說明

詳細配置請參考：
- [Google Places API 設定](docs/setup/GOOGLE_PLACES_SETUP.md)
- [錢包配置說明](docs/setup/WALLET_CONFIGURATION.md)
- [智能合約部署](contracts/DEPLOY.md)

## 📱 功能說明

### 乘客端 (Flutter App)

- ✅ 註冊/登入（錢包連接）
- ✅ 地點搜尋與選擇
- ✅ 費用預估
- ✅ 叫車請求
- ✅ 支付流程
- ✅ 行程追蹤
- 🔄 歷史記錄

### 司機端 (Flutter App)

- ✅ 註冊/登入
- ✅ 車輛註冊
- 🔄 接單功能
- 🔄 行程管理
- 🔄 收入統計

### 管理後台 (Dashboard)

- ✅ 管理員登入
- ✅ 數據統計
- ✅ 用戶管理
- ✅ 行程管理
- ✅ 退款管理
- ✅ 車輛審核

## 📚 文檔

- [專案狀態](docs/PROJECT_STATUS.md) - 當前開發進度
- [架構說明](docs/guides/architecture.md) - 系統架構詳解
- [使用者指南](docs/guides/USER_GUIDE_叫車流程.md) - 使用說明
- [API 文檔](http://localhost:8000/docs) - 後端 API 文檔
- [合約文檔](contracts/docs/) - 智能合約文檔

## 🧪 測試

### 後端測試
```bash
cd backend
pytest
```

### 前端測試
```bash
cd mobile
flutter test
```

### 合約測試
```bash
cd contracts
sui move test
```

## 🛠️ 開發工具

專案提供了一系列實用腳本工具，詳見 [scripts/README.md](scripts/README.md)

### 快速啟動
```bash
# 啟動 Flutter 應用
./scripts/dev/run_flutter.sh -d ios

# 監控後端日誌
./scripts/dev/monitor_logs.sh backend
```

### 運維工具
```bash
# 取消卡住的行程
./scripts/ops/cancel_stuck_trip.sh

# 生成錯誤報告
./scripts/ops/report_error.sh
```

## 📊 日誌管理

所有日誌檔案統一存放在 `logs/` 目錄，詳見 [logs/README.md](logs/README.md)

### 日誌類型
- **backend.log** - 後端 API 日誌（自動輪轉）
- **flutter_debug.log** - Flutter 應用除錯日誌
- **error_report_*.txt** - 錯誤報告檔案

### 查看日誌
```bash
# 查看後端日誌
tail -f logs/backend.log

# 查看 Flutter 日誌
tail -f logs/flutter_debug.log

# 生成錯誤報告
./scripts/ops/report_error.sh
```

## 🔐 安全性

- 所有敏感資料使用環境變數管理
- API 使用 JWT 進行身份驗證
- 支付透過智能合約託管
- 資料庫連接加密
- 日誌檔案不包含敏感資訊

## 🤝 貢獻

歡迎提交 Issue 和 Pull Request！

### 開發流程

1. Fork 專案
2. 創建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交變更 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 開啟 Pull Request

## 📄 授權

本專案採用 MIT 授權 - 詳見 [LICENSE](LICENSE) 文件

## 📞 聯絡方式

如有問題或建議，請開 Issue 討論。

---

**注意**: 本專案目前處於開發階段，部分功能仍在完善中。
