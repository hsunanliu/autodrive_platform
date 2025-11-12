# AutoDrive Platform 常見任務指南

## 開發環境設置

### 啟動開發環境

```bash
# 1. 啟動所有服務
cd /Users/hsuanliu/autodrive_platform
docker-compose up -d

# 2. 檢查服務狀態
docker ps

# 3. 查看後端日誌
docker logs autodrive_platform-backend-1 -f

# 4. 檢查健康狀態
curl http://localhost:8000/health
```

### 停止開發環境

```bash
docker-compose down
```

## 數據庫操作

### 連接數據庫

```bash
# 方法 1: 直接連接
docker exec -it autodrive_platform-db-1 psql -U autodrive -d autodrive_dev

# 方法 2: 執行單個查詢
docker exec autodrive_platform-db-1 psql -U autodrive -d autodrive_dev -c "SELECT * FROM users LIMIT 5;"
```

### 執行遷移

```bash
# 1. 創建遷移 SQL 文件
# 文件路徑: backend/migrations/xxx.sql

# 2. 複製到容器
docker cp backend/migrations/xxx.sql autodrive_platform-db-1:/tmp/

# 3. 執行遷移
docker exec autodrive_platform-db-1 psql -U autodrive -d autodrive_dev -f /tmp/xxx.sql

# 4. 驗證遷移
docker exec autodrive_platform-db-1 psql -U autodrive -d autodrive_dev -c "\d table_name"
```

### 常用查詢

```sql
-- 查看所有用戶
SELECT id, username, user_type, wallet_address FROM users;

-- 查看所有車輛
SELECT vehicle_id, owner_id, status, license_plate FROM vehicles;

-- 查看進行中的行程
SELECT trip_id, user_id, driver_id, status FROM trips WHERE status = 'in_progress';

-- 查看召回中的車輛
SELECT vehicle_id, recall_target_lat, recall_target_lng, recall_started_at
FROM vehicles
WHERE recall_started_at IS NOT NULL;
```

## 後端開發

### 添加新 API 端點

```python
# 1. 在 app/api/v1/your_module.py 添加端點
@router.post("/your-endpoint")
async def your_function(
    param: str,
    session: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """端點描述"""
    # 業務邏輯
    return {"success": True, "data": result}

# 2. 在 app/main.py 註冊路由（如果是新模塊）
from app.api.v1 import your_module
app.include_router(your_module.router, prefix="/api/v1")

# 3. 重啟後端
docker restart autodrive_platform-backend-1
```

### 添加新服務

```python
# 1. 創建服務文件: app/services/your_service.py
class YourService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def your_method(self, param: str) -> Dict[str, Any]:
        """方法描述"""
        # 實現邏輯
        return result

# 2. 在 API 中使用
from app.services.your_service import YourService

@router.post("/endpoint")
async def endpoint(session: AsyncSession = Depends(get_async_session)):
    service = YourService(session)
    result = await service.your_method(param)
    return {"success": True, "data": result}
```

### 調試後端

```bash
# 查看實時日誌
docker logs autodrive_platform-backend-1 -f

# 查看錯誤日誌
docker logs autodrive_platform-backend-1 --tail 100 | grep -i error

# 進入容器
docker exec -it autodrive_platform-backend-1 bash

# 重啟後端（應用代碼更改）
docker restart autodrive_platform-backend-1
```

## 前端開發

### 運行 Flutter 應用

```bash
cd mobile

# 1. 獲取依賴
flutter pub get

# 2. 運行應用（iOS 模擬器）
flutter run

# 3. 熱重載
# 在運行中按 'r' 鍵

# 4. 完全重啟
# 在運行中按 'R' 鍵
```

### 添加新頁面

```dart
// 1. 創建頁面文件: lib/pages/your_page.dart
class YourPage extends StatefulWidget {
  const YourPage({super.key, required this.session});

  final UserSession session;

  @override
  State<YourPage> createState() => _YourPageState();
}

class _YourPageState extends State<YourPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Page')),
      body: Container(),
    );
  }
}

// 2. 在導航中使用
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => YourPage(session: session),
  ),
);
```

### 添加 API 方法

```dart
// 方法 1: 使用通用方法（推薦）
final response = await ApiService.get('/your/endpoint');
final response = await ApiService.post('/your/endpoint', {'key': 'value'});

// 方法 2: 添加專用方法到 ApiService
static Future<Map<String, dynamic>> yourMethod({
  required String param,
}) async {
  return _handleRequest(() {
    return http.post(
      Uri.parse('$baseUrl/your/endpoint'),
      headers: _headers,
      body: jsonEncode({'param': param}),
    );
  });
}
```

### Flutter 分析與構建

```bash
# 代碼分析
flutter analyze

# 格式化代碼
flutter format lib/

# 構建 iOS（debug）
flutter build ios --debug --no-codesign

# 構建 Android（debug）
flutter build apk --debug

# 清理構建緩存
flutter clean
flutter pub get
```

## WebSocket 開發

### 後端發送事件

```python
from app.websocket.dependencies import get_notifier

notifier = get_notifier()
await notifier.manager.emit_to_user(
    user_id=user_id,
    event='event_name',
    data={
        'message': 'Hello',
        'timestamp': datetime.utcnow().isoformat()
    }
)
```

### 前端監聽事件

```dart
final ws = WebSocketService();

// 確保連接
if (!ws.isConnected) {
  await ws.connect();
}

// 監聽事件
ws.on('event_name', (data) {
  print('收到事件: $data');
  if (!mounted) return;

  setState(() {
    // 更新狀態
  });
});

// 清理監聽器（在 dispose 中）
ws.off('event_name');
```

## 測試

### 測試 API 端點

```bash
# 1. 登入獲取 token
TOKEN=$(curl -X POST "http://localhost:8000/api/v1/users/login" \
  -H "Content-Type: application/json" \
  -d '{"identifier": "username", "password": "password"}' \
  | jq -r '.access_token')

# 2. 使用 token 調用 API
curl -X GET "http://localhost:8000/api/v1/your/endpoint" \
  -H "Authorization: Bearer $TOKEN" \
  | jq .

# 3. POST 請求
curl -X POST "http://localhost:8000/api/v1/your/endpoint" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"key": "value"}' \
  | jq .
```

### 測試 WebSocket

```bash
# 使用 websocat（需要安裝）
brew install websocat

# 連接 WebSocket
websocat ws://localhost:8000/socket.io/?transport=websocket
```

## 常見問題排查

### 後端無法啟動

```bash
# 1. 檢查日誌
docker logs autodrive_platform-backend-1

# 2. 檢查數據庫連接
docker exec autodrive_platform-db-1 psql -U autodrive -d autodrive_dev -c "SELECT 1;"

# 3. 檢查端口占用
lsof -i :8000

# 4. 重建容器
docker-compose down
docker-compose up -d --build backend
```

### 前端無法連接後端

```dart
// 1. 檢查 baseUrl 配置
// mobile/lib/services/api_service.dart
static const String baseUrl = 'http://192.168.68.124:8000/api/v1';

// 2. 使用模擬器時改為 localhost
static const String baseUrl = 'http://localhost:8000/api/v1';

// 3. 檢查網絡連接
ping 192.168.68.124
```

### Token 過期

```dart
// 前端重新登入
final response = await ApiService.loginUser(
  identifier: username,
  password: password,
);

if (response['success'] == true) {
  final token = response['data']['access_token'];
  ApiService.setToken(token);
}
```

### 數據庫遷移失敗

```bash
# 1. 檢查 SQL 語法
cat backend/migrations/xxx.sql

# 2. 手動執行 SQL 查看錯誤
docker exec -it autodrive_platform-db-1 psql -U autodrive -d autodrive_dev

# 3. 回滾遷移（如果有 DOWN 腳本）
```

## 性能監控

### 後端性能

```bash
# 查看 CPU/內存使用
docker stats autodrive_platform-backend-1

# 查看慢查詢（PostgreSQL）
docker exec autodrive_platform-db-1 psql -U autodrive -d autodrive_dev -c "
SELECT query, calls, total_time, mean_time
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;
"
```

### 前端性能

```dart
// 使用 Flutter DevTools
flutter pub global activate devtools
flutter pub global run devtools

// 性能分析
// 1. 運行應用: flutter run
// 2. 打開 DevTools
// 3. 使用 Performance 標籤分析
```

## 部署檢查清單

- [ ] 更新環境變量（.env）
- [ ] 執行數據庫遷移
- [ ] 測試所有 API 端點
- [ ] 檢查 WebSocket 連接
- [ ] 前端構建成功
- [ ] 更新 API baseUrl
- [ ] 檢查區塊鏈連接
- [ ] 備份數據庫
- [ ] 查看日誌無錯誤
