# AutoDrive 腳本工具

本目錄包含 AutoDrive 專案的實用腳本工具。

## 📁 目錄結構

```
scripts/
├── README.md           # 本文件
├── dev/                # 開發工具
│   ├── run_flutter.sh      # Flutter 應用啟動腳本
│   └── monitor_logs.sh     # 日誌監控腳本
└── ops/                # 運維工具
    ├── cancel_stuck_trip.sh    # 取消卡住的行程
    └── report_error.sh         # 錯誤報告生成器
```

## 🛠️ 開發工具 (dev/)

### run_flutter.sh
Flutter 應用啟動腳本，支持多種啟動模式。

**使用方法：**
```bash
# 默認啟動
./scripts/dev/run_flutter.sh

# 在 iOS 模擬器上啟動
./scripts/dev/run_flutter.sh -d ios

# 在 Android 模擬器上啟動
./scripts/dev/run_flutter.sh -d android

# 啟動並記錄日誌
./scripts/dev/run_flutter.sh -l

# 清理後啟動並記錄日誌
./scripts/dev/run_flutter.sh -c -l

# 在特定設備上啟動
./scripts/dev/run_flutter.sh -d "iPhone 16 Plus"
```

**選項：**
- `-d, --device DEVICE` - 指定設備 (ios, android, 或設備 ID)
- `-l, --log` - 啟用日誌記錄到文件
- `-c, --clean` - 啟動前清理構建
- `-h, --help` - 顯示幫助信息

### monitor_logs.sh
日誌監控腳本，支持監控不同類型的日誌。

**使用方法：**
```bash
# 監控後端日誌
./scripts/dev/monitor_logs.sh backend

# 監控支付相關日誌
./scripts/dev/monitor_logs.sh payment

# 監控所有日誌
./scripts/dev/monitor_logs.sh all
```

**類型：**
- `backend` - 監控後端 API 日誌 (默認)
- `payment` - 監控支付相關日誌
- `all` - 監控所有服務日誌

## 🔧 運維工具 (ops/)

### cancel_stuck_trip.sh
取消卡住的行程工具，用於處理異常狀態的行程。

**使用方法：**
```bash
# 查看所有進行中的行程
./scripts/ops/cancel_stuck_trip.sh

# 取消特定行程
./scripts/ops/cancel_stuck_trip.sh <trip_id>

# 範例
./scripts/ops/cancel_stuck_trip.sh 4
```

**功能：**
- 列出所有進行中的行程
- 顯示行程詳細信息
- 安全取消卡住的行程
- 記錄取消原因

### report_error.sh
錯誤報告生成器，收集系統狀態和日誌信息。

**使用方法：**
```bash
./scripts/ops/report_error.sh
```

**生成內容：**
- Flutter 日誌（最後 100 行）
- 後端日誌（最後 50 行）
- 資料庫狀態
- 後端健康狀態

**輸出：**
生成 `error_report_YYYYMMDD_HHMMSS.txt` 文件

## 📝 其他腳本

### 合約部署
合約相關腳本位於 `contracts/` 目錄：
- `contracts/deploy_payment_escrow.sh` - 部署支付託管合約
- `contracts/tests/run_tests.sh` - 執行合約測試

### 後端初始化
後端相關腳本位於 `backend/docker/` 目錄：
- `backend/docker/init-test-db.sh` - 初始化測試資料庫

## 🚀 快速開始

### 開發環境啟動
```bash
# 1. 啟動後端服務
docker-compose up -d

# 2. 監控後端日誌
./scripts/dev/monitor_logs.sh backend

# 3. 啟動 Flutter 應用（新終端）
./scripts/dev/run_flutter.sh -d ios -l
```

### 問題排查
```bash
# 1. 生成錯誤報告
./scripts/ops/report_error.sh

# 2. 查看報告
cat error_report_*.txt

# 3. 如有卡住的行程，取消它
./scripts/ops/cancel_stuck_trip.sh
```

## 💡 提示

- 所有腳本都支持 `-h` 或 `--help` 參數查看詳細說明
- 腳本執行前請確保在專案根目錄
- 使用 `chmod +x` 給腳本添加執行權限（如果需要）

## 🤝 貢獻

如需添加新的腳本工具：
1. 將開發相關腳本放在 `dev/` 目錄
2. 將運維相關腳本放在 `ops/` 目錄
3. 更新本 README 文件
4. 確保腳本有適當的錯誤處理和幫助信息

---

最後更新：2025-10-21
