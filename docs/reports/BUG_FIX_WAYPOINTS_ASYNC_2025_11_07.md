# Bug 修復報告：司機獲取進行中行程異步錯誤

**日期**: 2025-11-07
**嚴重性**: 🔴 高（阻塞司機端核心功能）
**狀態**: ✅ 已修復

---

## 🐛 問題描述

### 錯誤信息
```
API 請求失敗:
  狀態碼: 500
  響應: {
    detail: 獲取進行中行程失敗: greenlet_spawn has not been called;
    can't call await_only() here. Was IO attempted in an unexpected place?
  }
```

### 影響範圍
- **受影響功能**: 司機端獲取進行中行程
- **API 端點**: `GET /api/v1/trips/my-active`
- **觸發條件**: 司機端啟動時或刷新進行中行程時
- **用戶影響**: 司機無法查看當前正在進行的行程

---

## 🔍 根本原因分析

### SQLAlchemy 異步加載問題

**問題根源**: 在異步上下文中使用了懶加載（lazy loading）關聯數據

**詳細說明**:
1. `GET /api/v1/trips/my-active` 端點查詢 Trip 對象
2. 返回的 Trip 對象包含 `waypoints` 關聯
3. 在 `_build_trip_response()` 中訪問 `trip.waypoints` 時觸發懶加載
4. 懶加載在異步上下文中無法正常工作，導致 `greenlet_spawn` 錯誤

**錯誤的代碼** (trips.py:346-353):
```python
query = select(Trip).where(
    Trip.driver_id == current_user.id,
    or_(
        Trip.status == 'accepted',
        Trip.status == 'picked_up',
        Trip.status == 'in_progress'
    )
).order_by(Trip.requested_at.desc()).limit(1)
# ❌ 沒有預加載 waypoints 關聯
```

---

## ✅ 解決方案

### 修復方法：預加載關聯數據

使用 SQLAlchemy 的 `selectinload` 在查詢時預加載 waypoints 關聯。

**修復後的代碼**:
```python
from sqlalchemy.orm import selectinload

query = select(Trip).where(
    Trip.driver_id == current_user.id,
    or_(
        Trip.status == 'accepted',
        Trip.status == 'picked_up',
        Trip.status == 'in_progress'
    )
).options(selectinload(Trip.waypoints)).order_by(Trip.requested_at.desc()).limit(1)
# ✅ 預加載 waypoints 關聯
```

### 修改的文件

**文件**: `backend/app/api/v1/trips.py`

**修改位置**: `get_my_active_trip()` 函數 (第 331-370 行)

**修改內容**:
1. 導入 `selectinload`
2. 在查詢語句中添加 `.options(selectinload(Trip.waypoints))`

---

## 🧪 測試驗證

### 測試方法

**後端日誌驗證**:
```bash
docker logs autodrive_platform-backend-1 --tail 50
```

**預期日誌**:
```sql
-- 1. 主查詢
SELECT trips.* FROM trips WHERE trips.driver_id = ? ...

-- 2. 預加載 waypoints（修復後新增）
SELECT trip_waypoints.* FROM trip_waypoints
WHERE trip_waypoints.trip_id IN (?)
ORDER BY trip_waypoints.sequence
```

### 測試結果

✅ **成功**:
- API 返回 HTTP 200
- waypoints 被正確預加載
- 沒有異步錯誤

**測試日誌片段**:
```
2025-11-07 15:40:27 - SELECT trips.* FROM trips WHERE ...
2025-11-07 15:40:27 - SELECT trip_waypoints.* FROM trip_waypoints ...
INFO: ... "GET /api/v1/trips/my-active HTTP/1.1" 200 OK
```

---

## 🔄 相關修復

這個問題在之前實現多停靠點功能時也出現過，已經在以下地方修復：

1. ✅ `TripService._get_trip_by_id()` - 已修復
2. ✅ `TripService.create_trip_request()` - 已修復
3. ✅ `GET /api/v1/trips/my-active` - **本次修復** ⭐
4. ✅ `GET /api/v1/trips/{trip_id}` - 通過 `_get_trip_by_id()` 間接修復

### 潛在需要檢查的端點

建議檢查以下端點是否也需要類似修復：
- [ ] `GET /api/v1/trips/` (獲取用戶行程列表)
- [ ] `GET /api/v1/trips/available` (獲取可接單行程)

---

## 📝 經驗教訓

### 最佳實踐

1. **始終預加載關聯數據**
   ```python
   # ✅ 好的做法
   query = select(Model).options(
       selectinload(Model.relationship)
   )

   # ❌ 避免懶加載
   query = select(Model)  # 會在訪問 relationship 時觸發懶加載
   ```

2. **一致性很重要**
   - 在添加新關聯時，檢查所有查詢該模型的地方
   - 確保所有查詢都預加載新關聯

3. **測試異步場景**
   - 在異步 API 中測試所有關聯數據的訪問
   - 確保沒有懶加載觸發

### 檢查清單（添加新關聯時）

當給模型添加新的關聯時：
- [ ] 更新所有查詢該模型的 `select()` 語句
- [ ] 添加 `selectinload()` 預加載新關聯
- [ ] 在 `_get_by_id()` 方法中添加預加載
- [ ] 測試所有使用該模型的 API 端點
- [ ] 檢查日誌確認沒有懶加載查詢

---

## 🚀 部署說明

### 修改已部署

```bash
# 1. 確認修改
git diff backend/app/api/v1/trips.py

# 2. 重啟後端服務
docker-compose restart backend

# 3. 驗證修復
# 在 Flutter 應用中測試司機端功能
```

### 驗證步驟

1. ✅ 後端日誌顯示預加載查詢
2. ✅ API 返回 200 OK
3. ✅ Flutter 應用中司機可以正常查看進行中行程
4. ✅ 包含停靠點的行程正常顯示

---

## 🔗 相關文檔

- [多停靠點功能報告](../guides/features/WAYPOINTS_FEATURE_REPORT.md)
- [SQLAlchemy 異步最佳實踐](https://docs.sqlalchemy.org/en/20/orm/extensions/asyncio.html)

---

## 📊 影響統計

- **修復時間**: < 10 分鐘
- **受影響用戶**: 所有司機用戶
- **修復難度**: 低（模式化問題）
- **回歸風險**: 極低（只是預加載數據，不改變邏輯）

---

**修復人**: Claude Code
**審查人**: -
**部署時間**: 2025-11-07 15:40
**驗證狀態**: ✅ 已驗證
