# AutoDrive Platform 故障排除指南

## 常見錯誤及解決方案

### 後端錯誤

#### 1. ImportError: cannot import name 'X' from 'app.models'

**症狀**: 後端無法啟動，報告模型導入錯誤

**原因**:
- 模型不存在
- 模型未在 `__init__.py` 中導出
- 循環導入

**解決方案**:
```bash
# 1. 檢查模型是否存在
ls backend/app/models/

# 2. 檢查 __init__.py 導出
cat backend/app/models/__init__.py

# 3. 修正導入
# 使用正確的模型名稱
from app.models import User  # 而不是 Driver
```

#### 2. asyncpg.exceptions.UndefinedColumnError

**症狀**: 查詢時報告列不存在

**原因**: 數據庫遷移未執行或失敗

**解決方案**:
```bash
# 1. 檢查表結構
docker exec autodrive_platform-db-1 psql -U autodrive -d autodrive_dev -c "\d vehicles"

# 2. 執行遷移
docker exec autodrive_platform-db-1 psql -U autodrive -d autodrive_dev -f /tmp/migration.sql

# 3. 驗證列存在
docker exec autodrive_platform-db-1 psql -U autodrive -d autodrive_dev -c "\d+ vehicles" | grep column_name
```

#### 3. WebSocket Connection Failed

**症狀**: WebSocket 無法連接或斷開

**原因**:
- WebSocket 未正確初始化
- 用戶未認證
- 網絡問題

**解決方案**:
```python
# 後端確保 WebSocket 已啟動
# 檢查 main.py 中的 Socket.IO 配置

# 前端確保連接初始化
final ws = WebSocketService();
if (!ws.isConnected) {
  await ws.connect();
}
```

#### 4. JWT Token Invalid

**症狀**: API 返回 401 Unauthorized

**原因**:
- Token 過期
- Token 格式錯誤
- Secret key 不匹配

**解決方案**:
```dart
// 前端重新登入
final response = await ApiService.loginUser(
  identifier: username,
  password: password,
);

if (response['success'] == true) {
  final token = response['data']['access_token'];
  ApiService.setToken(token);
  await SessionManager.saveSession(response['data']);
}
```

#### 5. Database Connection Timeout

**症狀**: 數據庫連接超時

**原因**:
- 數據庫服務未啟動
- 連接池耗盡
- 網絡問題

**解決方案**:
```bash
# 1. 檢查數據庫狀態
docker ps | grep db

# 2. 重啟數據庫
docker restart autodrive_platform-db-1

# 3. 檢查連接
docker exec autodrive_platform-db-1 psql -U autodrive -d autodrive_dev -c "SELECT 1;"

# 4. 檢查連接池配置
# backend/app/core/database.py
```

### 前端錯誤

#### 1. The method 'get' isn't defined for the type 'ApiService'

**症狀**: Flutter 編譯錯誤

**原因**: ApiService 缺少通用 HTTP 方法

**解決方案**:
```dart
// 確保 ApiService 有以下方法
static Future<Map<String, dynamic>> get(String path) async { }
static Future<Map<String, dynamic>> post(String path, Map body) async { }
static Future<Map<String, dynamic>> put(String path, Map body) async { }
static Future<Map<String, dynamic>> delete(String path) async { }
```

#### 2. FlutterMapInternalController was used after being disposed

**症狀**: 地圖操作錯誤

**原因**: 在 Widget dispose 後仍在操作 MapController

**解決方案**:
```dart
@override
void dispose() {
  _mapController.dispose();
  super.dispose();
}

// 在操作前檢查 mounted
if (mounted) {
  try {
    _mapController.move(position, zoom);
  } catch (e) {
    print('⚠️ 地圖移動錯誤: $e');
  }
}
```

#### 3. Black Screen After Navigation

**症狀**: 導航後出現黑屏

**原因**:
- 使用 `pushReplacementNamed` 在 TabBar 結構中
- 雙重 `Navigator.pop()`

**解決方案**:
```dart
// 使用 pushNamed 而不是 pushReplacementNamed
Navigator.pushNamed(context, '/route');

// 防止雙重 pop
bool _isPopping = false;

void _handleBack() {
  if (_isPopping) return;
  _isPopping = true;
  Navigator.pop(context);
}
```

#### 4. Timer Still Active After Widget Disposed

**症狀**: Timer 在 Widget 銷毀後仍在運行

**原因**: dispose 時未取消 Timer

**解決方案**:
```dart
Timer? _timer;

@override
void dispose() {
  _timer?.cancel();
  _timer = null;
  super.dispose();
}

// 在 Timer 回調中檢查 mounted
_timer = Timer.periodic(Duration(seconds: 1), (timer) {
  if (!mounted) {
    timer.cancel();
    return;
  }
  // 執行操作
});
```

#### 5. Network Connection Error

**症狀**: 無法連接後端 API

**原因**:
- baseUrl 配置錯誤
- 後端服務未啟動
- 防火牆阻擋

**解決方案**:
```dart
// 1. 檢查 baseUrl
// mobile/lib/services/api_service.dart
static const String baseUrl = 'http://YOUR_IP:8000/api/v1';

// 2. iOS 模擬器使用 localhost
static const String baseUrl = 'http://localhost:8000/api/v1';

// 3. Android 模擬器使用
static const String baseUrl = 'http://10.0.2.2:8000/api/v1';

// 4. 實機使用 Mac IP
static const String baseUrl = 'http://192.168.x.x:8000/api/v1';
```

### 數據庫錯誤

#### 1. FATAL: role "X" does not exist

**症狀**: 數據庫連接失敗

**原因**: 用戶名錯誤

**解決方案**:
```bash
# 檢查 .env 文件
cat .env | grep POSTGRES_USER

# 使用正確的用戶名
docker exec autodrive_platform-db-1 psql -U autodrive -d autodrive_dev
```

#### 2. relation "X" does not exist

**症狀**: 表不存在

**原因**:
- 數據庫未初始化
- 遷移未執行

**解決方案**:
```bash
# 1. 檢查表是否存在
docker exec autodrive_platform-db-1 psql -U autodrive -d autodrive_dev -c "\dt"

# 2. 執行初始化腳本
docker exec autodrive_platform-db-1 psql -U autodrive -d autodrive_dev -f /docker-entrypoint-initdb.d/init.sql

# 3. 或重建數據庫
docker-compose down -v
docker-compose up -d
```

#### 3. duplicate key value violates unique constraint

**症狀**: 插入重複數據失敗

**原因**: 違反唯一約束

**解決方案**:
```python
# 插入前檢查是否存在
result = await session.execute(
    select(Model).where(Model.unique_field == value)
)
existing = result.scalar_one_or_none()

if existing:
    raise HTTPException(status_code=409, detail="記錄已存在")
```

### 區塊鏈錯誤

#### 1. SUI RPC Connection Failed

**症狀**: 無法連接 SUI 節點

**原因**:
- 節點 URL 錯誤
- 網絡問題
- 節點服務中斷

**解決方案**:
```bash
# 1. 檢查 .env 配置
cat .env | grep SUI_NODE_URL

# 2. 測試連接
curl https://fullnode.testnet.sui.io:443

# 3. 嘗試其他節點
SUI_NODE_URL=https://fullnode.testnet.sui.io:443
```

#### 2. Insufficient Gas

**症狀**: 交易失敗，gas 不足

**原因**: 操作錢包餘額不足

**解決方案**:
```bash
# 1. 檢查錢包餘額
sui client gas

# 2. 從水龍頭獲取測試幣
curl --location --request POST 'https://faucet.testnet.sui.io/gas' \
  --header 'Content-Type: application/json' \
  --data-raw '{"FixedAmountRequest":{"recipient":"YOUR_ADDRESS"}}'
```

### Docker 錯誤

#### 1. Container Already in Use

**症狀**: 容器名稱衝突

**解決方案**:
```bash
# 停止並移除舊容器
docker stop autodrive_platform-backend-1
docker rm autodrive_platform-backend-1

# 或使用 docker-compose
docker-compose down
docker-compose up -d
```

#### 2. Port Already Allocated

**症狀**: 端口被占用

**解決方案**:
```bash
# 1. 查找占用端口的進程
lsof -i :8000

# 2. 停止進程
kill -9 <PID>

# 3. 或更改端口
# 修改 docker-compose.yml
ports:
  - "8001:8000"
```

## 調試技巧

### 啟用詳細日誌

```python
# backend/app/main.py
import logging

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)
```

### 使用 pdb 調試

```python
import pdb; pdb.set_trace()
```

### Flutter DevTools

```bash
flutter pub global activate devtools
flutter pub global run devtools
```

### 查看完整錯誤堆棧

```bash
# 後端
docker logs autodrive_platform-backend-1 --tail 200

# 數據庫
docker logs autodrive_platform-db-1 --tail 100
```

## 性能問題

### 慢查詢優化

```sql
-- 查看慢查詢
SELECT query, calls, total_time, mean_time
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;

-- 添加索引
CREATE INDEX idx_name ON table_name(column_name);

-- 分析查詢計劃
EXPLAIN ANALYZE SELECT * FROM table_name WHERE condition;
```

### 前端性能優化

```dart
// 使用 const 構造函數
const Text('Hello');

// 避免在 build 中創建對象
class _State extends State<Widget> {
  final TextStyle style = const TextStyle(color: Colors.white);

  @override
  Widget build(BuildContext context) {
    return Text('Hello', style: style);
  }
}

// 使用 ListView.builder
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemWidget(items[index]),
)
```

## 緊急恢復

### 回滾數據庫

```bash
# 1. 備份當前狀態
docker exec autodrive_platform-db-1 pg_dump -U autodrive autodrive_dev > backup.sql

# 2. 恢復備份
docker exec -i autodrive_platform-db-1 psql -U autodrive -d autodrive_dev < backup.sql
```

### 重置開發環境

```bash
# 完全重置
docker-compose down -v
docker-compose up -d --build

# 等待服務啟動
sleep 10

# 檢查狀態
docker ps
curl http://localhost:8000/health
```

## 尋求幫助

如果以上方法無法解決問題：

1. 收集完整錯誤信息
2. 記錄重現步驟
3. 檢查相關日誌
4. 查看 GitHub Issues
5. 諮詢團隊成員
