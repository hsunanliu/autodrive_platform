# AutoDrive 專案狀態

> 最後更新：2025-10-21

## 📋 專案概述

AutoDrive 是一個基於區塊鏈的去中心化叫車平台，使用 Sui 區塊鏈進行支付和智能合約管理。

## 🏗️ 系統架構

### 後端 (Python + FastAPI)
- 業務邏輯處理
- 智能合約互動
- 統一 API 服務
- PostgreSQL 資料庫

### 前端
1. **Flutter App (行動端)** - 即時互動與核心交易
   - 叫車服務
   - 司機/車輛配對
   - 行程追蹤
   - 支付功能

2. **Dashboard (React)** - 管理後台
   - 數據查詢
   - 歷史紀錄
   - 退款管理
   - 用戶管理

### 智能合約 (Move on Sui)
- 支付託管
- 交易驗證
- 退款處理

## ✅ 已完成功能

### 用戶系統
- ✅ 註冊（連接錢包）
- ✅ 登入驗證
- ✅ Session 管理
- ✅ 用戶資料管理

### 叫車流程
- ✅ 地點選擇（Google Places API）
- ✅ 費用預估
- ✅ 行程創建
- ✅ 支付流程

### 支付系統
- ✅ 支付對話框
- ✅ 支付信息展示
- ✅ 支付狀態管理
- ✅ 交易驗證 API
- ✅ 智能合約整合

### 管理後台
- ✅ 管理員登入
- ✅ Dashboard 數據展示
- ✅ 退款管理
- ✅ 用戶管理
- ✅ 行程管理

### 資料庫
- ✅ 完整的表結構
- ✅ 支付狀態追蹤
- ✅ 交易記錄
- ✅ 退款記錄

## 🔧 當前配置

### 後端服務
- **URL**: `http://localhost:8000`
- **Database**: PostgreSQL (Docker)
- **API Docs**: `http://localhost:8000/docs`

### Flutter App
- **Platform**: iOS/Android
- **API Base URL**: 配置於 `mobile/lib/services/api_service.dart`

### Dashboard
- **URL**: `http://localhost:5173`
- **管理員帳號**: 
  - Email: `admin@example.com`
  - Password: `admin123456`

### 智能合約
- **Network**: Sui Testnet
- **Package ID**: 配置於環境變數

## 🚧 進行中的功能

### 退款流程
- 🔄 退款申請
- 🔄 責任歸屬判定
- 🔄 自動退款處理

### 司機功能
- 🔄 司機接單
- 🔄 行程狀態更新
- 🔄 實時位置追蹤

## 📝 待開發功能

### 高優先級
- [ ] 完整的司機端功能
- [ ] 實時位置追蹤
- [ ] 推送通知
- [ ] 自動支付驗證

### 中優先級
- [ ] 評分系統
- [ ] 行程歷史查詢
- [ ] 收入統計
- [ ] 多語言支持

### 低優先級
- [ ] 優惠券系統
- [ ] 推薦獎勵
- [ ] 進階數據分析

## 🎯 開發路線圖

### Phase 1: MVP (已完成 80%)
- ✅ 基礎用戶系統
- ✅ 叫車流程
- ✅ 支付整合
- ✅ 管理後台
- 🔄 退款流程

### Phase 2: 完善核心功能
- 司機端完整功能
- 實時追蹤
- 通知系統
- 完整的退款流程

### Phase 3: 生產就緒
- 性能優化
- 安全加固
- 完整測試覆蓋
- 部署自動化

## 📚 相關文檔

- [架構說明](./guides/architecture.md)
- [使用者指南](./guides/USER_GUIDE_叫車流程.md)
- [Google Places 設定](./setup/GOOGLE_PLACES_SETUP.md)
- [錢包配置](./setup/WALLET_CONFIGURATION.md)
- [合約文檔](../contracts/README.md)
- [合約部署指南](../contracts/DEPLOY.md)

## 🤝 貢獻指南

請參考各子專案的 README：
- [Backend README](../backend/README.md)
- [Mobile README](../mobile/README.md)
- [Dashboard README](../dashboard/README.md)
- [Contracts README](../contracts/README.md)

---

如有問題或建議，請開 Issue 討論。
