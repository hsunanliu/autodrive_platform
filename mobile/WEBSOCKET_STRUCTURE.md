# WebSocket 結構重構完成報告

## 📋 重構目標
- ✅ 統一 WebSocket 連接入口，避免到處重複呼叫 `connect()`
- ✅ 防止多個頁面同時建立連接導致的斷線問題
- ✅ 清晰的架構，易於維護和理解

## 🏗️ 新架構設計

### 1. 統一連接入口（只有兩處）

#### 入口 1: 登入成功時
**檔案**: `lib/pages/auth_page.dart`
**時機**: 用戶登入成功後
**程式碼位置**: Line 58-61

```dart
// ✅ 統一初始化 WebSocket 連接（登入成功後唯一入口）
print('🔌 登入成功，初始化 WebSocket 連接...');
await WebSocketService().connect();
print('✅ WebSocket 初始化完成');
```

#### 入口 2: App 啟動時（已登入用戶）
**檔案**: `lib/main.dart`
**時機**: App 啟動時檢測到已有 session
**程式碼位置**: Line 81-84

```dart
if (session != null) {
  ApiService.setToken(session.accessToken);
  // 如果用戶已登入，初始化 WebSocket 連接
  await WebSocketService().connect();
}
```

### 2. 防重複連接機制

**檔案**: `lib/services/websocket_service.dart`
**程式碼位置**: Line 23-37

```dart
/// 初始化並連接 WebSocket（只在未連接時才建立新連接）
Future<void> connect() async {
  // ✅ 如果已經有 socket 且正在連接或已連接，直接返回
  if (_socket != null && (_socket!.connected || _isConnected)) {
    print('✅ WebSocket: 已連接，無需重複連接');
    return;
  }

  // 如果有舊 socket 但未連接，清理它
  if (_socket != null && !_socket!.connected) {
    print('🔧 WebSocket: 清理舊的未連接 socket');
    _socket!.dispose();
    _socket = null;
    _isConnected = false;
  }

  // ... 繼續建立新連接
}
```

**改進說明**:
- ❌ **舊版**: 每次呼叫 `connect()` 都會先 `disconnect()`，導致正在建立的連接被中斷
- ✅ **新版**: 檢查是否已連接，如果已連接則直接返回，避免重複連接

### 3. 頁面只設置監聽器，不再主動連接

已移除以下檔案的 `connect()` 呼叫：

#### `lib/driver_home_page.dart` (Line 43-48)
```dart
/// 設置 WebSocket 監聽（不重複建立連接）
Future<void> _initializeWebSocket() async {
  final ws = WebSocketService();

  // ✅ 不再主動 connect()，由統一入口管理連接
  // WebSocket 應該在登入成功時統一初始化

  // 只設置事件監聽器
  ws.on('trip_cancelled', (data) { ... });
  ws.on('trip_completed', (data) { ... });
}
```

#### `lib/driver_home_page_new.dart` (Line 50-55)
```dart
/// 設置 WebSocket 監聽（不重複建立連接）
Future<void> _initializeWebSocket() async {
  final ws = WebSocketService();

  // ✅ 不再主動 connect()，由統一入口管理連接
  // WebSocket 應該在登入成功時或 app 啟動時統一初始化

  // 加入司機在線房間以接收新訂單通知
  ws.emit('join_drivers_room', {});
}
```

## 📊 WebSocket 使用情況總覽

### 使用 WebSocket 的頁面（共 9 個檔案）

| 檔案 | 監聽事件 | 發送事件 | 是否呼叫 connect() |
|------|---------|---------|-------------------|
| `driver_home_page.dart` | trip_cancelled, trip_completed | - | ❌ 已移除 |
| `driver_home_page_new.dart` | 多個 | join_drivers_room | ❌ 已移除 |
| `passenger_home_page.dart` | trip_accepted, trip_started, trip_completed, trip_cancelled, driver_location_update | joinTrip(), leaveTrip() | ❌ 無 |
| `pages/trip_in_progress_page.dart` | joined_trip, connection_status, trip_started, payment_completed, trip_completed, trip_cancelled | update_location | ❌ 無 |
| `pages/available_trips_page.dart` | joined_drivers_room, new_trip_available | join_drivers_room, leave_drivers_room | ❌ 無 |
| `pages/real_ride_page.dart` | driver_location_update | join_trip, leave_trip | ❌ 無 |
| `pages/vehicle_recall_page.dart` | vehicle_location_update, vehicle_recall_completed | join_trip | ❌ 已移除（使用輪詢） |
| `pages/auth_page.dart` | - | - | ✅ **登入成功時** |
| `main.dart` | - | - | ✅ **App 啟動時** |

### Backend 事件（共 10 個）

**接收的事件** (backend/app/websocket/events.py):
1. `connect` - 客戶端連接（含 token 認證）
2. `disconnect` - 客戶端斷線
3. `join_trip` - 加入行程房間
4. `leave_trip` - 離開行程房間
5. `update_location` - 更新司機位置
6. `send_message` - 發送聊天訊息
7. `join_drivers_room` - 加入司機在線房間
8. `leave_drivers_room` - 離開司機房間
9. `update_fcm_token` - 更新 FCM Token
10. `ping` - 心跳

**發送的事件** (backend/app/websocket/notifier.py):
1. `trip_accepted` - 司機接單
2. `trip_started` - 行程開始
3. `trip_arrived` - 司機到達
4. `trip_completed` - 行程完成
5. `trip_cancelled` - 行程取消
6. `driver_location_update` - 司機位置更新
7. `vehicle_location_update` - 車輛位置更新（召回）
8. `vehicle_recall_completed` - 車輛召回完成
9. `payment_processing` - 支付處理中
10. `payment_completed` - 支付完成
11. `payment_failed` - 支付失敗
12. `new_trip_available` - 新訂單通知（司機端）
13. `joined_trip` - 已加入行程房間確認
14. `left_trip` - 已離開行程房間確認
15. `joined_drivers_room` - 已加入司機房間確認
16. `new_message` - 新訊息（未來功能）

## 🔄 連接流程

```
用戶登入
  ↓
auth_page.dart: 登入成功
  ↓
WebSocketService().connect() ← 第一次連接
  ↓
└─ 檢查是否已連接
   ├─ 已連接 → 直接返回（不重複連接）
   └─ 未連接 → 建立新連接
      ↓
   Socket.IO 握手 (EIO v4)
      ↓
   後端 connect 事件處理器
      ├─ 驗證 token
      ├─ 儲存 user_id → sid 映射
      └─ 發送 'connected' 確認
      ↓
   前端收到 onConnect
      ↓
   設置 _isConnected = true
      ↓
各頁面只設置監聽器，不再呼叫 connect()
```

## ✅ 修改的檔案列表

1. ✅ `lib/services/websocket_service.dart` - 防止重複連接
2. ✅ `lib/pages/auth_page.dart` - 新增統一入口（登入成功）
3. ✅ `lib/driver_home_page.dart` - 移除 connect() 呼叫
4. ✅ `lib/driver_home_page_new.dart` - 移除 connect() 呼叫
5. ✅ `lib/main.dart` - 已存在的統一入口（App 啟動）

## 🧪 測試步驟

1. **Hot Restart** Flutter App
2. 登入後觀察 log，應該看到：
   ```
   🔌 登入成功，初始化 WebSocket 連接...
   🔌 WebSocket: 嘗試連接到 http://localhost:8000
   ✅ WebSocket: 已連接
   ✅ WebSocket 初始化完成
   ```
3. 進入各個頁面（司機首頁、乘客首頁等），應該看到：
   ```
   ✅ WebSocket: 已連接，無需重複連接
   ```
4. 後端 log 應該只看到一次連接：
   ```
   🔌 客戶端嘗試連接: <sid>
   ✅ WebSocket 認證成功: user_id=1
   ```

## 📝 結論

新架構的優勢：
- 🎯 **統一管理**: 只有兩個入口點，清晰明確
- 🛡️ **防止重複**: 自動檢測已連接狀態，避免重複連接
- 🧹 **代碼簡潔**: 各頁面只需設置監聽器，不需關心連接管理
- 🐛 **易於除錯**: 連接問題只需檢查兩個入口點
- 📖 **易於維護**: 結構清晰，新人容易理解

下一步：
- 測試 WebSocket 連接是否成功
- 測試各個功能（新訂單通知、位置更新、車輛召回等）
- 確認所有事件都能正常接收和發送
