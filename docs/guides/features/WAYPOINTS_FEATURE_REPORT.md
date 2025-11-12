# 多停靠點（Waypoints）功能實現報告

**日期**: 2025-11-07
**功能**: 支持乘客在叫車時添加多個中繼停靠點

---

## ✅ 已完成的工作

### 1. 後端實現

#### 數據庫層
- ✅ 創建 `trip_waypoints` 表
  - 字段：`id`, `trip_id`, `sequence`, `lat`, `lng`, `address`, `arrival_time`
  - 外鍵約束：關聯到 `trips` 表，級聯刪除
  - 索引：`trip_id` 和 `(trip_id, sequence)` 複合索引

- ✅ 修改 `Trip` 模型添加 `waypoints` 關聯
  - 使用 SQLAlchemy relationship
  - 配置為 eager loading 以避免 N+1 查詢問題

#### API Schema
- ✅ 添加 `WaypointCreate` 和 `WaypointResponse` schema
- ✅ 修改 `TripCreate` schema 支持 `waypoints` 字段（最多5個）
- ✅ 修改 `TripResponse` schema 返回 `waypoints` 列表

#### 業務邏輯
- ✅ 修改 `TripService.create_trip_request()` 方法
  - 支持接收 waypoints 參數
  - **距離計算優化**：計算總距離時考慮所有停靠點
    - 起點 → 停靠點1 → 停靠點2 → ... → 終點
  - 創建行程時同時創建關聯的 waypoint 記錄
  - 使用 `selectinload` 預加載關聯避免異步問題

- ✅ 修改 `_get_trip_by_id()` 方法
  - 預加載 waypoints 關聯

- ✅ 修改 `_build_trip_response()` 方法
  - 返回 waypoints 數據，按 sequence 排序

#### 路線服務
- ✅ `DirectionsService` 已支持 waypoints
  - 使用 Google Directions API 的 waypoints 參數
  - 支持 `optimize:true` 自動優化停靠順序

### 2. 前端實現 (Flutter Mobile)

#### API Service
- ✅ 修改 `ApiService.createTripRequest()` 方法
  - 添加可選的 `waypoints` 參數
  - 正確序列化為 JSON

#### UI 組件
- ✅ `RealRidePage` 停靠點管理功能
  - 停靠點輸入框
  - 停靠點列表顯示（含序號、地址）
  - 添加/刪除停靠點按鈕
  - 停靠點數量限制（最多5個）

- ✅ 地圖標記
  - 起點：藍色人形圖標
  - 停靠點：橘色圓圈標記（帶序號）
  - 終點：紅色定位圖標

---

## 🧪 測試結果

### 測試場景：創建帶有 2 個停靠點的行程

**測試數據**:
```json
{
  "pickup": "台北市中心 (25.0340, 121.5645)",
  "waypoint_1": "西門町 (25.0420, 121.5071)",
  "waypoint_2": "信義區 (25.0330, 121.5654)",
  "dropoff": "台北車站 (25.0478, 121.5173)"
}
```

**測試步驟**:
1. ✅ 登入測試用戶
2. ✅ 創建帶有 2 個停靠點的行程
3. ✅ 驗證響應中包含 waypoints 數據
4. ✅ 查詢行程詳情確認 waypoints 已正確存儲

**測試結果**:
```
✅ 行程創建成功!
   行程 ID: 40
   距離: 16.93 km  (考慮了所有停靠點的總距離)
   預估時間: 34 分鐘
   總金額: 5612576510 micro SUI

✅ 找到 2 個停靠點:
   1. 停靠點 1：西門町 (25.042, 121.5071)
   2. 停靠點 2：信義區 (25.033, 121.5654)

✅ 查詢行程詳情:
   停靠點已正確儲存並按順序返回
```

**數據庫驗證**:
```sql
SELECT * FROM trip_waypoints WHERE trip_id = 40;
```
```
 id | trip_id | sequence |  lat   |   lng    |     address
----+---------+----------+--------+----------+------------------
  3 |      40 |        1 | 25.042 | 121.5071 | 停靠點 1：西門町
  4 |      40 |        2 | 25.033 | 121.5654 | 停靠點 2：信義區
```

---

## 🎯 功能特性

### 用戶體驗
- 🎨 **直觀的 UI**: 停靠點以序號標記，清晰顯示行程路線
- ➕ **簡單添加**: 輸入地址後按 Enter 或點擊 + 按鈕
- ❌ **輕鬆刪除**: 每個停靠點旁有刪除按鈕
- 🔢 **數量限制**: 最多5個停靠點，防止過度複雜的行程
- 📍 **地圖可視化**: 所有停靠點在地圖上清晰標記

### 後端優化
- 💰 **精確費用計算**: 距離計算考慮所有停靠點，費用更準確
- ⚡ **性能優化**: 使用 eager loading 避免 N+1 查詢
- 🔒 **數據完整性**: 外鍵約束和級聯刪除確保數據一致性
- 🗺️ **路線優化**: 支持 Google Maps API 自動優化停靠順序

---

## 📋 未來改進建議

### 短期 (1-2 週)
- [ ] 添加停靠點拖拽排序功能
- [ ] 顯示每段路程的預估時間
- [ ] 支持編輯已添加的停靠點地址

### 中期 (1-2 月)
- [ ] 記錄每個停靠點的實際到達時間
- [ ] 支持停靠點的停留時長設置
- [ ] 添加常用停靠點快捷選擇

### 長期 (3-6 月)
- [ ] 停靠點推薦（基於歷史數據）
- [ ] 多人拼車時的智能停靠點規劃
- [ ] 停靠點照片上傳（便於司機識別）

---

## 🚀 部署清單

- [x] 數據庫遷移文件已創建 (`migrations/add_trip_waypoints.sql`)
- [x] 後端代碼已更新並測試通過
- [x] 前端代碼已更新
- [x] API 向後兼容（不帶 waypoints 的請求仍正常工作）

---

## 📝 技術文檔

### API 使用示例

**創建帶停靠點的行程**:
```bash
POST /api/v1/trips/
Content-Type: application/json
Authorization: Bearer <token>

{
  "pickup_lat": 25.0340,
  "pickup_lng": 121.5645,
  "pickup_address": "起點",
  "dropoff_lat": 25.0478,
  "dropoff_lng": 121.5173,
  "dropoff_address": "終點",
  "waypoints": [
    {
      "lat": 25.0420,
      "lng": 121.5071,
      "address": "西門町"
    },
    {
      "lat": 25.0330,
      "lng": 121.5654,
      "address": "信義區"
    }
  ],
  "passenger_count": 1
}
```

**響應示例**:
```json
{
  "trip_id": 40,
  "distance_km": 16.93,
  "waypoints": [
    {
      "id": 3,
      "sequence": 1,
      "lat": 25.042,
      "lng": 121.5071,
      "address": "西門町",
      "arrival_time": null
    },
    {
      "id": 4,
      "sequence": 2,
      "lat": 25.033,
      "lng": 121.5654,
      "address": "信義區",
      "arrival_time": null
    }
  ]
}
```

---

## ✅ 結論

多停靠點功能已成功實現並測試通過。該功能為乘客提供了更靈活的叫車選項，同時保持了系統的性能和數據完整性。
