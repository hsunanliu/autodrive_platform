# AutoDrive Platform - Claude Code 提示詞庫

這個資料夾包含了 AutoDrive Platform 專案的各種提示詞和指南，幫助 Claude Code 更好地理解和協助開發工作。

## 文件說明

### 📚 [project-overview.md](project-overview.md)
專案整體概覽，包括：
- 技術棧介紹
- 核心功能說明
- 項目結構
- 數據庫架構
- API 端點列表
- 環境變量配置
- 開發指令

**使用時機**: 需要了解整個專案架構和技術選型時

### 📝 [coding-standards.md](coding-standards.md)
編碼規範和最佳實踐，包括：
- Python (FastAPI) 後端規範
- Dart (Flutter) 前端規範
- Git 提交規範
- API 設計規範
- 測試規範
- 性能優化建議
- 安全規範

**使用時機**: 編寫新代碼或重構現有代碼時

### 🛠️ [common-tasks.md](common-tasks.md)
常見開發任務的詳細步驟，包括：
- 開發環境設置
- 數據庫操作
- 添加新 API 端點
- 添加新服務
- Flutter 開發流程
- WebSocket 開發
- 測試方法
- 性能監控

**使用時機**: 執行具體開發任務時需要參考步驟

### 🔧 [troubleshooting.md](troubleshooting.md)
故障排除指南，包括：
- 常見錯誤及解決方案
- 後端錯誤處理
- 前端錯誤處理
- 數據庫問題
- 區塊鏈問題
- Docker 問題
- 調試技巧
- 緊急恢復方案

**使用時機**: 遇到錯誤或問題需要快速解決時

## 如何使用

### 在 Claude Code 中引用

當與 Claude Code 對話時，可以這樣引用：

```
請參考 project-overview.md 了解專案架構，然後幫我添加一個新的 API 端點
```

```
按照 coding-standards.md 中的規範，幫我重構這段代碼
```

```
參考 common-tasks.md，幫我設置開發環境
```

```
根據 troubleshooting.md，幫我解決這個錯誤: [錯誤信息]
```

### 快速查找

使用關鍵字搜索：
- 架構、技術棧 → `project-overview.md`
- 命名、風格、規範 → `coding-standards.md`
- 添加、創建、部署 → `common-tasks.md`
- 錯誤、失敗、問題 → `troubleshooting.md`

## 維護指南

### 更新時機

- **專案結構變化** → 更新 `project-overview.md`
- **新增編碼規範** → 更新 `coding-standards.md`
- **新增常見任務** → 更新 `common-tasks.md`
- **遇到新問題** → 更新 `troubleshooting.md`

### 更新原則

1. **保持簡潔** - 只記錄重要和常用的信息
2. **示例優先** - 盡量提供代碼示例
3. **及時更新** - 專案變化時同步更新文檔
4. **分類清晰** - 信息放在正確的文件中

## 專案特定術語

- **SUI** - Sui 區塊鏈
- **MIST** - SUI 的最小單位 (1 SUI = 1,000,000,000 MIST)
- **半自動配對** - 系統推送 + 司機手動選擇的混合匹配方式
- **動態定價** - 基於時間、天氣、供需的多因素定價
- **車輛召回** - 司機遠程召回空閒車輛的功能
- **雙幣種顯示** - 同時顯示 SUI 和 USD 價格

## 相關資源

### 官方文檔
- [FastAPI 文檔](https://fastapi.tiangolo.com/)
- [Flutter 文檔](https://flutter.dev/docs)
- [SUI 文檔](https://docs.sui.io/)
- [PostgreSQL 文檔](https://www.postgresql.org/docs/)

### 內部文檔
- API 文檔: http://localhost:8000/docs
- 管理後台: http://localhost:5173

## 版本歷史

### v1.0 (2025-10-26)
- 初始創建提示詞庫
- 添加專案概覽
- 添加編碼規範
- 添加常見任務指南
- 添加故障排除指南
- 記錄車輛召回功能實現

## 貢獻

如果發現文檔有誤或需要補充，請：
1. 直接更新相關文件
2. 保持格式一致
3. 添加示例代碼
4. 更新版本歷史

## 授權

這些文檔是 AutoDrive Platform 專案的一部分，遵循專案相同的授權協議。
