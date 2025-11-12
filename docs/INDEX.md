# AutoDrive 文檔索引

本文檔提供項目所有文檔和腳本的快速索引。

---

## 📁 目錄結構

```
autodrive_platform/
├── docs/
│   ├── guides/           # 使用指南
│   │   ├── setup/        # 設置指南
│   │   ├── features/     # 功能說明
│   │   └── testing/      # 測試指南
│   └── reports/          # 開發報告
├── scripts/              # 實用腳本
│   ├── dev/             # 開發腳本
│   └── testing/         # 測試腳本
└── PROJECT_OVERVIEW.md   # 項目概覽
```

---

## 📖 使用指南

### 設置指南 (`docs/guides/setup/`)

| 文檔 | 說明 |
|------|------|
| [Flutter Build 故障排除](guides/setup/FLUTTER_BUILD_TROUBLESHOOTING.md) | Flutter 編譯問題完整解決方案 |
| [退款設置指南](guides/setup/REFUND_SETUP_GUIDE.md) | 退款功能配置說明 |
| [退款批次設置](guides/setup/REFUND_BATCH_SETUP.md) | 批次退款功能設置 |
| [錢包解決方案](guides/setup/WALLET_SOLUTIONS.md) | 錢包整合方案說明 |

### 功能說明 (`docs/guides/features/`)

| 文檔 | 說明 |
|------|------|
| [多停靠點功能報告](guides/features/WAYPOINTS_FEATURE_REPORT.md) | 最新實現的多停靠點功能完整說明 ⭐ |
| [WebSocket 實現](guides/features/WEBSOCKET_IMPLEMENTATION.md) | 實時通訊功能說明 |
| [Deep Link 實現完成](guides/features/DEEP_LINK_IMPLEMENTATION_COMPLETE.md) | Deep Link 功能實現 |
| [Deep Link 狀態報告](guides/features/DEEP_LINK_STATUS_REPORT.md) | Deep Link 功能狀態 |
| [功能清單](guides/features/FEATURES.md) | 所有已實現功能清單 |

### 用戶指南 (`docs/guides/`)

| 文檔 | 說明 |
|------|------|
| [叫車流程用戶指南](guides/USER_GUIDE_叫車流程.md) | 乘客使用叫車功能的完整指南 |

---

## 📊 開發報告 (`docs/reports/`)

### 進度報告

| 文檔 | 日期 | 說明 |
|------|------|------|
| [開發進度報告](reports/DEVELOPMENT_PROGRESS_REPORT.md) | - | 整體開發進度 |
| [任務完成總結](reports/TASK_COMPLETION_SUMMARY_2025_10_27.md) | 2025-10-27 | 10月27日任務總結 |

### 技術報告

| 文檔 | 日期 | 說明 |
|------|------|------|
| [前端整合報告](reports/FRONTEND_INTEGRATION_2025_10_24.md) | 2025-10-24 | 前端整合狀態 |
| [測試報告](reports/TEST_REPORT_2025_10_24.md) | 2025-10-24 | 測試結果報告 |
| [Bug 修復報告](reports/BUG_FIX_2025_10_24.md) | 2025-10-24 | Bug 修復記錄 |
| [更新日誌](reports/CHANGELOG_2025_10_22.md) | 2025-10-22 | 功能更新日誌 |
| [Slush 整合分析](reports/SLUSH_INTEGRATION_ANALYSIS.md) | - | Slush 整合技術分析 |

---

## 🛠️ 腳本 (`scripts/`)

### 開發腳本 (`scripts/dev/`)

| 腳本 | 說明 | 使用方式 |
|------|------|----------|
| `run_flutter.sh` | Flutter 應用啟動腳本 | `./scripts/dev/run_flutter.sh [選項]` |

**快速使用**:
```bash
# 查看幫助
./scripts/dev/run_flutter.sh -h

# iOS 模擬器啟動
./scripts/dev/run_flutter.sh -d ios

# Android 模擬器啟動
./scripts/dev/run_flutter.sh -d android

# 清理後啟動並記錄日誌
./scripts/dev/run_flutter.sh -c -l
```

### 測試腳本 (`scripts/testing/`)

| 腳本 | 說明 | 使用方式 |
|------|------|----------|
| `test_waypoints.py` | 多停靠點功能 API 測試 | `python3 scripts/testing/test_waypoints.py` |
| `test_dual_role_registration.sh` | 雙角色註冊測試 | `./scripts/testing/test_dual_role_registration.sh` |

---

## 🚀 快速啟動腳本 (根目錄)

為了方便使用，根目錄也提供了快速啟動腳本：

```bash
# Flutter 應用快速啟動
./run_flutter.sh

# 注意：此腳本是 scripts/run_flutter.sh 的副本
```

---

## 📝 根目錄重要文檔

| 文檔 | 說明 |
|------|------|
| [PROJECT_OVERVIEW.md](../PROJECT_OVERVIEW.md) | 項目整體概覽和架構說明 ⭐ |
| [README.md](../README.md) | 項目入口文檔 |

---

## 🔍 如何使用此索引

### 按需求查找

**我想知道如何...**
- 🏗️ 設置開發環境？→ [Flutter Build 故障排除](guides/setup/FLUTTER_BUILD_TROUBLESHOOTING.md)
- 📱 運行 Flutter 應用？→ 使用 `scripts/run_flutter.sh` 或查看上方快速啟動
- 🧪 測試某個功能？→ 查看 `scripts/testing/` 下的測試腳本
- 🎯 了解某個功能如何實現？→ 查看 `docs/guides/features/` 下的對應文檔
- 📊 查看項目進度？→ 查看 `docs/reports/` 下的報告

### 按時間查找

**我想查看...**
- 最新功能：[多停靠點功能報告](guides/features/WAYPOINTS_FEATURE_REPORT.md) (2025-11-07)
- 最近的報告：[任務完成總結](reports/TASK_COMPLETION_SUMMARY_2025_10_27.md) (2025-10-27)

---

## 📚 推薦閱讀順序

### 新成員入門

1. [PROJECT_OVERVIEW.md](../PROJECT_OVERVIEW.md) - 了解項目整體
2. [Flutter Build 故障排除](guides/setup/FLUTTER_BUILD_TROUBLESHOOTING.md) - 設置開發環境
3. [功能清單](guides/features/FEATURES.md) - 了解已實現功能
4. [叫車流程用戶指南](guides/USER_GUIDE_叫車流程.md) - 了解核心業務流程

### 開發人員

1. [開發進度報告](reports/DEVELOPMENT_PROGRESS_REPORT.md) - 了解當前進度
2. [多停靠點功能報告](guides/features/WAYPOINTS_FEATURE_REPORT.md) - 最新功能實現
3. [WebSocket 實現](guides/features/WEBSOCKET_IMPLEMENTATION.md) - 實時通訊架構
4. 測試腳本 (`scripts/testing/`) - 功能測試

---

## 🔄 文檔維護

**文檔更新規範**:
- 新增功能時，在 `docs/guides/features/` 添加功能說明文檔
- 重要變更時，在 `docs/reports/` 添加變更記錄
- 新增腳本時，在 `scripts/` 對應目錄添加並更新此索引

**最後更新**: 2025-11-07
