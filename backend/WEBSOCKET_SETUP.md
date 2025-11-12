# WebSocket 設定指南

## 概述

AutoDrive 平台現已整合 Socket.IO WebSocket 支援，實現即時雙向通訊功能。

## 已實現功能

### 後端功能

1. **連接管理** (`backend/app/websocket/manager.py`)
   - JWT Token 驗證
   - 用戶連接/斷開管理
   - 房間（Room）管理
   - 用戶在線狀態追蹤

2. **事件處理** (`backend/app/websocket/events.py`)
   - 連接/斷開事件
   - 加入/離開行程房間
   - 位置更新事件
   - 聊天訊息（預留）
   - 心跳檢測

3. **業務通知** (`backend/app/websocket/notifier.py`)
   - 司機接單通知
   - 行程開始/完成/取消通知
   - 支付處理/完成/失敗通知
   - 新行程廣播（給司機）

### 前端功能

1. **WebSocket 服務** (`mobile/lib/services/websocket_service.dart`)
   - 自動連接和重連
   - JWT Token 認證
   - 事件監聽器管理
   - 業務事件封裝

2. **整合到應用**
   - 登入時自動連接
   - 登出時自動斷開

## 啟動方式

### 1. 重建 Docker 容器

```bash
# 停止現有容器
docker-compose down

# 重建並啟動（會安裝 python-socketio）
docker-compose up -d --build

# 查看日誌確認 WebSocket 已初始化
docker-compose logs -f backend
```

你應該看到：
```
🚀 Starting AutoDrive API...
📡 WebSocket 伺服器已初始化
```

### 2. 安裝 Flutter 依賴

```bash
cd mobile
flutter pub get
```

### 3. 運行 Flutter 應用

```bash
flutter run
```

## 測試 WebSocket 連接

### 使用瀏覽器測試

1. 安裝 Socket.IO 客戶端測試工具（可選）：
```html
<!DOCTYPE html>
<html>
<head>
    <script src="https://cdn.socket.io/4.5.4/socket.io.min.js"></script>
</head>
<body>
    <h1>WebSocket 測試</h1>
    <script>
        const socket = io('http://localhost:8000', {
            auth: {
                token: 'YOUR_JWT_TOKEN_HERE'
            }
        });

        socket.on('connect', () => {
            console.log('已連接:', socket.id);
        });

        socket.on('connected', (data) => {
            console.log('連接確認:', data);
        });

        socket.on('trip_accepted', (data) => {
            console.log('收到 trip_accepted:', data);
        });
    </script>
</body>
</html>
```

### 使用 Python 測試腳本

創建 `test_websocket.py`：

```python
import socketio
import time

# 替換為真實的 JWT Token
TOKEN = "your_jwt_token_here"

sio = socketio.Client()

@sio.event
def connect():
    print("✅ 已連接到 WebSocket 伺服器")

@sio.on('connected')
def on_connected(data):
    print(f"📡 連接確認: {data}")
    # 加入行程房間
    sio.emit('join_trip', {'trip_id': 1})

@sio.on('trip_accepted')
def on_trip_accepted(data):
    print(f"📨 收到 trip_accepted: {data}")

@sio.event
def disconnect():
    print("🔌 已斷開連接")

if __name__ == '__main__':
    sio.connect('http://localhost:8000', auth={'token': TOKEN})

    # 保持連接
    try:
        sio.wait()
    except KeyboardInterrupt:
        sio.disconnect()
```

運行：
```bash
pip install python-socketio[client]
python test_websocket.py
```

## 事件列表

### 客戶端 → 伺服器

| 事件名稱 | 參數 | 描述 |
|---------|------|------|
| `join_trip` | `{trip_id: int}` | 加入行程房間 |
| `leave_trip` | `{trip_id: int}` | 離開行程房間 |
| `update_location` | `{trip_id: int, lat: float, lng: float, timestamp: int}` | 更新司機位置 |
| `send_message` | `{trip_id: int, message: str, timestamp: int}` | 發送聊天訊息 |
| `ping` | `{timestamp: int}` | 心跳檢測 |

### 伺服器 → 客戶端

| 事件名稱 | 數據結構 | 描述 |
|---------|---------|------|
| `connected` | `{user_id: int, message: str}` | 連接成功 |
| `trip_accepted` | `{trip_id: int, driver: {...}, message: str}` | 司機接單 |
| `trip_started` | `{trip_id: int, message: str}` | 行程開始 |
| `trip_arrived` | `{trip_id: int, message: str}` | 司機到達 |
| `trip_completed` | `{trip_id: int, message: str}` | 行程完成 |
| `trip_cancelled` | `{trip_id: int, cancelled_by: str, reason: str}` | 行程取消 |
| `driver_location_update` | `{trip_id: int, driver_id: int, lat: float, lng: float}` | 司機位置更新 |
| `payment_processing` | `{trip_id: int, message: str}` | 支付處理中 |
| `payment_completed` | `{trip_id: int, amount: float, message: str}` | 支付完成 |
| `payment_failed` | `{trip_id: int, reason: str}` | 支付失敗 |
| `new_trip_available` | `{trip_id: int, trip: {...}}` | 新行程通知（司機） |
| `pong` | `{timestamp: int}` | 心跳回應 |

## 使用範例

### 乘客端：監聽司機接單

```dart
// 在頁面初始化時
final ws = WebSocketService();

ws.on('trip_accepted', (data) {
  print('司機已接單: ${data['driver']}');
  // 更新 UI
  setState(() {
    _driverInfo = data['driver'];
    _tripStatus = 'accepted';
  });
});

// 加入行程房間
ws.joinTrip(tripId);
```

### 司機端：更新位置

```dart
// 每 5 秒更新一次位置
Timer.periodic(Duration(seconds: 5), (timer) {
  if (_tripStatus == 'in_progress') {
    final position = await getCurrentLocation();
    WebSocketService().updateLocation(
      tripId,
      position.latitude,
      position.longitude,
    );
  }
});
```

### 監聽支付完成

```dart
ws.on('payment_completed', (data) {
  print('支付成功: ${data['amount']}');
  // 跳轉到評價頁面
  Navigator.pushNamed(context, '/review');
});
```

## 連接狀態管理

```dart
// 監聽連接狀態
ws.on('connection_status', (data) {
  if (data['connected']) {
    print('✅ WebSocket 已連接');
  } else {
    print('❌ WebSocket 已斷開');
    // 顯示重連提示
  }
});

// 檢查是否在線
if (ws.isConnected) {
  // 執行需要 WebSocket 的操作
}
```

## 故障排除

### 問題 1：無法連接到 WebSocket

**症狀**：Flutter 應用無法連接到後端 WebSocket

**解決方案**：
1. 確認後端容器正在運行：`docker-compose ps`
2. 檢查後端日誌：`docker-compose logs backend | grep WebSocket`
3. 確認 `app.main:socket_app` 在 Dockerfile 中正確配置
4. 檢查 Flutter 中的 API URL 是否正確

### 問題 2：認證失敗

**症狀**：連接被拒絕，錯誤訊息「無效的認證 token」

**解決方案**：
1. 確認用戶已登入並有有效的 JWT Token
2. 檢查 Token 是否過期
3. 確認 Token 在連接時正確傳遞：`auth: {token: 'xxx'}`

### 問題 3：事件沒有收到

**症狀**：發送事件但沒有收到響應

**解決方案**：
1. 確認已加入正確的房間：`ws.joinTrip(tripId)`
2. 檢查事件監聽器是否正確註冊：`ws.on('event_name', callback)`
3. 查看後端日誌確認事件是否發送
4. 使用 `ping/pong` 測試連接是否正常

### 問題 4：Docker 重建後連接失敗

**解決方案**：
```bash
# 完全清理並重建
docker-compose down -v
docker-compose build --no-cache
docker-compose up -d
```

## 開發建議

### 1. 錯誤處理

所有 WebSocket 操作都應該包含錯誤處理：

```dart
try {
  ws.updateLocation(tripId, lat, lng);
} catch (e) {
  print('發送位置失敗: $e');
  // 降級到 HTTP API
}
```

### 2. 重連機制

Socket.IO 自動處理重連，但建議在應用層也處理：

```dart
ws.on('connection_status', (data) {
  if (!data['connected'] && _wasConnected) {
    // 重新加入房間
    if (_currentTripId != null) {
      Future.delayed(Duration(seconds: 1), () {
        ws.joinTrip(_currentTripId!);
      });
    }
  }
  _wasConnected = data['connected'];
});
```

### 3. 內存管理

記得在頁面銷毀時移除監聽器：

```dart
@override
void dispose() {
  ws.off('trip_accepted');
  ws.off('driver_location_update');
  super.dispose();
}
```

## 效能優化

### 位置更新頻率

建議：
- 行程進行中：每 3-5 秒
- 待機狀態：不更新
- 網路不穩定時：降低頻率到 10 秒

### 房間管理

- 行程結束後立即離開房間：`ws.leaveTrip(tripId)`
- 避免同時加入過多房間

## 安全注意事項

1. **Token 保護**：JWT Token 只在連接時傳遞，不在事件中發送
2. **房間權限**：後端會驗證用戶是否有權限加入該房間
3. **CORS 配置**：生產環境務必修改 `cors_allowed_origins`
4. **HTTPS**：生產環境使用 `wss://` 而不是 `ws://`

## 未來改進

- [ ] 實現聊天功能
- [ ] 添加推送通知服務
- [ ] 多伺服器部署（使用 Redis Adapter）
- [ ] 實現已讀回執
- [ ] 添加離線訊息隊列

## 相關文件

- [Socket.IO 官方文檔](https://socket.io/docs/v4/)
- [socket_io_client (Flutter)](https://pub.dev/packages/socket_io_client)
- [python-socketio](https://python-socketio.readthedocs.io/)
