# Scripts 腳本目錄

本目錄包含 AutoDrive 項目的實用腳本。

---

## 📁 目錄結構

```
scripts/
├── dev/              # 開發腳本
│   └── run_flutter.sh
├── testing/          # 測試腳本
│   ├── test_waypoints.py
│   └── test_dual_role_registration.sh
└── run_flutter.sh    # Flutter 快速啟動（主要腳本）
```

---

## 🚀 開發腳本 (dev/)

### run_flutter.sh - Flutter 應用啟動腳本

**使用方式**:
```bash
# 查看幫助
./scripts/dev/run_flutter.sh -h

# iOS 模擬器
./scripts/dev/run_flutter.sh -d ios

# 清理後啟動
./scripts/dev/run_flutter.sh -c -l
```

---

## 🧪 測試腳本 (testing/)

### test_waypoints.py - 多停靠點功能測試
```bash
python3 scripts/testing/test_waypoints.py
```

### test_dual_role_registration.sh - 雙角色註冊測試
```bash
./scripts/testing/test_dual_role_registration.sh
```

---

## 📚 相關文檔

- [Flutter Build 故障排除](../docs/guides/setup/FLUTTER_BUILD_TROUBLESHOOTING.md)
- [主文檔索引](../docs/INDEX.md)

**最後更新**: 2025-11-07
