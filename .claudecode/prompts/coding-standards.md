# AutoDrive Platform 編碼規範

## 通用原則

1. **清晰優於簡潔** - 代碼可讀性優先
2. **文檔齊全** - 重要函數必須有文檔字串
3. **錯誤處理** - 所有外部調用都要有異常處理
4. **日誌記錄** - 關鍵操作需記錄日誌

## Python (FastAPI) 後端

### 命名規範

```python
# 文件名: snake_case
vehicle_recall_service.py

# 類名: PascalCase
class VehicleRecallService:
    pass

# 函數名: snake_case
async def start_recall():
    pass

# 常量: UPPER_SNAKE_CASE
MAX_RECALL_DISTANCE = 50.0

# 私有變量/方法: 單下劃線前綴
def _internal_helper():
    pass
```

### 類型註解

所有函數必須有類型註解：

```python
async def start_recall(
    self,
    driver_id: int,
    vehicle_id: int,
    target_lat: float,
    target_lng: float
) -> Dict[str, Any]:
    """
    開始召回車輛

    Args:
        driver_id: 司機 ID
        vehicle_id: 車輛 ID
        target_lat: 目標位置緯度
        target_lng: 目標位置經度

    Returns:
        召回信息字典

    Raises:
        ValueError: 驗證失敗時
    """
    pass
```

### 異步處理

- 所有數據庫操作使用 `async/await`
- 使用 `AsyncSession` 進行數據庫操作
- 正確處理異步上下文管理器

```python
async with get_async_session() as session:
    result = await session.execute(query)
```

### 錯誤處理

```python
try:
    result = await some_operation()
except ValueError as e:
    logger.error(f"業務邏輯錯誤: {e}")
    raise HTTPException(status_code=400, detail=str(e))
except Exception as e:
    logger.error(f"未預期錯誤: {e}")
    raise HTTPException(status_code=500, detail="內部服務器錯誤")
```

### 日誌規範

使用 emoji 標記不同類型的日誌：

```python
logger.info(f"✅ 操作成功")
logger.warning(f"⚠️ 警告信息")
logger.error(f"❌ 錯誤信息")
logger.debug(f"🔍 調試信息")
logger.info(f"🚗 車輛相關")
logger.info(f"📡 WebSocket 相關")
logger.info(f"💰 支付相關")
```

### API 端點規範

```python
@router.post("/recall/start")
async def start_vehicle_recall(
    vehicle_id: int,
    target_lat: float,
    target_lng: float,
    session: AsyncSession = Depends(get_async_session),
    current_user: User = Depends(get_current_user)
):
    """開始召回車輛"""
    service = VehicleRecallService(session)

    try:
        result = await service.start_recall(
            driver_id=current_user.id,
            vehicle_id=vehicle_id,
            target_lat=target_lat,
            target_lng=target_lng
        )
        return {"success": True, "data": result}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
```

## Dart (Flutter) 前端

### 命名規範

```dart
// 文件名: snake_case
vehicle_recall_page.dart

// 類名: PascalCase
class VehicleRecallPage extends StatefulWidget {
}

// 變量/方法: camelCase
void loadRecallableVehicles() {
}

// 私有變量/方法: 下劃線前綴
bool _isLoading = false;

// 常量: lowerCamelCase
const int maxRecallDistance = 50;
```

### Widget 結構

```dart
class VehicleRecallPage extends StatefulWidget {
  const VehicleRecallPage({super.key, required this.session});

  final UserSession session;

  @override
  State<VehicleRecallPage> createState() => _VehicleRecallPageState();
}

class _VehicleRecallPageState extends State<VehicleRecallPage> {
  // 1. 狀態變量
  bool _isLoading = false;
  List<Map<String, dynamic>> _vehicles = [];

  // 2. 生命週期方法
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  // 3. 業務邏輯方法
  Future<void> _loadData() async {
    // ...
  }

  // 4. UI 構建方法
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ...
    );
  }

  // 5. 輔助 Widget 方法
  Widget _buildVehicleCard(Map<String, dynamic> vehicle) {
    // ...
  }
}
```

### 異步處理

```dart
Future<void> _loadData() async {
  setState(() {
    _isLoading = true;
    _statusMessage = '正在加載...';
  });

  try {
    final response = await ApiService.get('/path');

    if (response['success'] == true) {
      setState(() {
        _data = response['data'];
      });
    }
  } catch (e) {
    setState(() {
      _statusMessage = '加載失敗: $e';
    });
  } finally {
    setState(() => _isLoading = false);
  }
}
```

### 生命週期管理

```dart
@override
void dispose() {
  // 1. 取消計時器
  _timer?.cancel();

  // 2. 釋放控制器
  _mapController.dispose();

  // 3. 清理監聽器
  _ws.off('event_name');

  // 4. 調用父類 dispose
  super.dispose();
}
```

### Mounted 檢查

```dart
if (!mounted) return;

setState(() {
  // 更新狀態
});
```

### 顏色規範

使用專案統一配色：

```dart
const Color backgroundColor = Color(0xFF121212);      // 深黑背景
const Color cardBackground = Color(0xFF1E1E1E);       // 卡片背景
const Color primaryGreen = Color(0xFF1DB954);         // 主要綠色（Spotify Green）
const Color textPrimary = Colors.white;               // 主要文字
const Color textSecondary = Colors.white70;           // 次要文字
const Color textTertiary = Colors.white54;            // 三級文字
```

## Git 提交規範

### 提交訊息格式

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Type 類型

- `feat`: 新功能
- `fix`: 修復 bug
- `refactor`: 重構代碼
- `docs`: 文檔更新
- `style`: 代碼格式調整
- `test`: 測試相關
- `chore`: 構建/工具配置

### 範例

```
feat(vehicle): 添加車輛召回功能

- 新增 VehicleRecallService 後端服務
- 實現召回 API 端點
- 創建前端召回頁面
- 數據庫添加召回相關欄位

Closes #123
```

## API 設計規範

### RESTful 原則

```
GET    /api/v1/vehicles              # 列表
GET    /api/v1/vehicles/{id}         # 詳情
POST   /api/v1/vehicles              # 創建
PUT    /api/v1/vehicles/{id}         # 更新
DELETE /api/v1/vehicles/{id}         # 刪除

# 子資源
POST   /api/v1/vehicles/recall/start  # 動作
```

### 響應格式

成功響應：
```json
{
  "success": true,
  "data": {
    "vehicle_id": 1,
    "status": "available"
  }
}
```

錯誤響應：
```json
{
  "success": false,
  "detail": "錯誤描述"
}
```

## 測試規範

### 後端測試

```python
async def test_start_recall():
    """測試開始召回功能"""
    # Arrange
    service = VehicleRecallService(db)

    # Act
    result = await service.start_recall(
        driver_id=1,
        vehicle_id=1,
        target_lat=25.0,
        target_lng=121.5
    )

    # Assert
    assert result['status'] == 'recall_in_progress'
```

### 前端測試

```dart
testWidgets('Vehicle recall page loads', (WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: VehicleRecallPage(session: mockSession),
    ),
  );

  expect(find.text('車輛召回'), findsOneWidget);
});
```

## 性能優化

### 後端
- 使用索引優化查詢
- 分頁處理大量數據
- 緩存頻繁查詢結果
- 異步處理耗時操作

### 前端
- 使用 `const` 構造函數
- 及時釋放資源（dispose）
- 圖片優化和緩存
- 列表使用 ListView.builder

## 安全規範

1. **絕不**在前端存儲私鑰
2. **絕不**在代碼中硬編碼密碼
3. **所有** API 端點需要驗證
4. **所有**用戶輸入需要驗證
5. **敏感**信息使用環境變量
