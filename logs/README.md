# 日誌目錄

此目錄用於存放 AutoDrive 專案的所有日誌檔案。

## 📁 日誌檔案類型

### 後端日誌
- **backend.log** - 後端 API 主日誌
  - 包含所有 API 請求、錯誤和系統事件
  - 自動輪轉，最大 10MB，保留 5 個備份
  - 位置：`logs/backend.log`

### 前端日誌
- **flutter_debug.log** - Flutter 應用除錯日誌
  - 包含 Flutter 應用的運行日誌
  - 使用 `./scripts/dev/run_flutter.sh -l` 啟動時自動記錄
  - 位置：`logs/flutter_debug.log`

### 錯誤報告
- **error_report_YYYYMMDD_HHMMSS.txt** - 錯誤報告檔案
  - 使用 `./scripts/ops/report_error.sh` 生成
  - 包含系統狀態快照和相關日誌
  - 格式：`logs/error_report_20251021_143022.txt`

## 🔧 配置

### 後端日誌配置
在 `.env` 檔案中設置：

```bash
# 日誌級別: DEBUG, INFO, WARNING, ERROR, CRITICAL
LOG_LEVEL=INFO

# 是否輸出到檔案: true, false
LOG_TO_FILE=true
```

### 日誌輪轉
後端日誌使用 Python 的 `RotatingFileHandler`：
- 單個檔案最大：10MB
- 保留備份數：5 個
- 總計最大：50MB

## 📝 使用範例

### 查看後端日誌
```bash
# 查看最新日誌
tail -f logs/backend.log

# 查看最後 100 行
tail -100 logs/backend.log

# 搜尋錯誤
grep ERROR logs/backend.log

# 搜尋特定關鍵字
grep "payment" logs/backend.log
```

### 查看 Flutter 日誌
```bash
# 查看最新日誌
tail -f logs/flutter_debug.log

# 查看最後 50 行
tail -50 logs/flutter_debug.log
```

### 生成錯誤報告
```bash
# 生成完整的錯誤報告
./scripts/ops/report_error.sh

# 查看最新的錯誤報告
ls -lt logs/error_report_* | head -1
```

## 🧹 日誌清理

### 手動清理
```bash
# 清理所有日誌（保留 .gitkeep）
rm -f logs/*.log logs/*.txt

# 清理舊的錯誤報告（保留最近 5 個）
ls -t logs/error_report_* | tail -n +6 | xargs rm -f

# 清理 7 天前的日誌
find logs -name "*.log" -mtime +7 -delete
```

### 自動清理腳本
可以設置 cron job 定期清理：

```bash
# 每週日凌晨 2 點清理 7 天前的日誌
0 2 * * 0 find /path/to/autodrive_platform/logs -name "*.log" -mtime +7 -delete
```

## ⚠️ 注意事項

1. **不要提交日誌到 Git**
   - 所有 `.log` 和 `.txt` 檔案已在 `.gitignore` 中排除
   - 只有 `.gitkeep` 和 `README.md` 會被追蹤

2. **生產環境建議**
   - 使用專業的日誌管理系統（如 ELK Stack, Grafana Loki）
   - 設置日誌告警機制
   - 定期備份重要日誌

3. **敏感資訊**
   - 確保日誌中不包含密碼、私鑰等敏感資訊
   - 定期檢查日誌內容

4. **磁碟空間**
   - 定期監控日誌目錄大小
   - 設置適當的日誌輪轉策略

## 🔍 日誌分析

### 常見問題排查

**API 錯誤：**
```bash
grep "ERROR" logs/backend.log | tail -20
```

**支付問題：**
```bash
grep -i "payment\|escrow" logs/backend.log | tail -50
```

**資料庫問題：**
```bash
grep -i "database\|sqlalchemy" logs/backend.log | tail -30
```

**性能問題：**
```bash
grep -i "slow\|timeout" logs/backend.log
```

## 📊 日誌統計

### 錯誤統計
```bash
# 統計錯誤數量
grep -c "ERROR" logs/backend.log

# 按錯誤類型分組
grep "ERROR" logs/backend.log | awk '{print $NF}' | sort | uniq -c | sort -rn
```

### 請求統計
```bash
# 統計 API 請求數
grep "GET\|POST\|PUT\|DELETE" logs/backend.log | wc -l

# 統計最常訪問的端點
grep "GET\|POST\|PUT\|DELETE" logs/backend.log | awk '{print $6}' | sort | uniq -c | sort -rn | head -10
```

---

最後更新：2025-10-21
