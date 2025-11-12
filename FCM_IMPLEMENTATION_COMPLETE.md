# Firebase Cloud Messaging (FCM) 推送通知實現完成報告

**日期**: 2025-11-12
**狀態**: 後端與前端代碼實現完成，等待配置和測試

---

## ✅ 已完成的工作

### 1. Flutter 前端實現

#### 1.1 依賴添加
- ✅ 添加 `firebase_core: ^3.4.0`
- ✅ 添加 `firebase_messaging: ^15.1.0`
- ✅ 添加 `flutter_local_notifications: ^19.5.0`

#### 1.2 推送通知服務
**文件**: `mobile/lib/services/notification_service.dart`

功能：
- FCM Token 管理（獲取、刷新、存儲）
- 前台消息處理（顯示本地通知）
- 背景消息處理（應用在背景時）
- 終止狀態消息處理（應用完全關閉時）
- 通知點擊處理（導航邏輯）
- 測試通知功能

#### 1.3 主應用集成
**文件**: `mobile/lib/main.dart`

改動：
- Firebase 初始化（帶錯誤處理）
- 背景消息處理器註冊
- 通知服務初始化
- Deep Link 處理（錢包連接）

#### 1.4 司機端集成
**文件**: `mobile/lib/driver_home_page_new.dart`

改動：
- WebSocket 連接時發送 FCM Token
- 加入司機在線房間
- 接收新訂單 WebSocket 事件
- 移除輪詢邏輯（改用 WebSocket）

#### 1.5 iOS 配置
**文件**: `mobile/ios/Podfile`

改動：
- 設置 iOS 部署目標為 13.0
- 啟用 `use_frameworks!`
- 添加非模塊化頭文件支持配置

---

### 2. 後端實現

#### 2.1 數據庫模型
**文件**: `backend/app/models/user.py`

改動：
- 添加 `fcm_token` 字段到 User 模型

**遷移文件**: `backend/migrations/add_fcm_token_to_users.sql`
```sql
ALTER TABLE users ADD COLUMN fcm_token VARCHAR(255);
CREATE INDEX idx_users_fcm_token ON users(fcm_token);
```

#### 2.2 WebSocket 事件處理
**文件**: `backend/app/websocket/events.py`

新增事件：
- `update_fcm_token`: 更新用戶的 FCM Token

功能：
- 接收前端發送的 FCM Token
- 更新數據庫中的用戶記錄
- 返回成功/失敗狀態

#### 2.3 FCM 推送服務
**文件**: `backend/app/services/fcm_service.py`

功能：
- 發送通用推送通知
- 發送新訂單通知給司機
- 發送行程狀態更新通知
- 發送司機到達通知給乘客

配置：
- 使用 Firebase HTTP v1 API
- 支持 Android 和 iOS 平台
- 高優先級推送（確保即時送達）

#### 2.4 行程 API 集成
**文件**: `backend/app/api/v1/trips.py`

改動：
- 創建新訂單時發送 WebSocket 通知
- 創建新訂單時發送 FCM 推送通知給所有在線司機
- 記錄推送成功/失敗日誌

#### 2.5 配置文件
**文件**: `backend/app/config.py`

新增配置：
- `FCM_SERVER_KEY`: Firebase 服務器密鑰（從環境變量讀取）

---

## 📋 待完成的配置步驟

### 步驟 1: 執行數據庫遷移

```bash
cd backend
docker-compose exec backend psql -U autodrive -d autodrive_dev -f migrations/add_fcm_token_to_users.sql
```

或者直接在 PostgreSQL 中執行：
```sql
ALTER TABLE users ADD COLUMN fcm_token VARCHAR(255);
CREATE INDEX idx_users_fcm_token ON users(fcm_token);
```

---

### 步驟 2: 配置 Firebase Console

#### 2.1 創建 Firebase 項目
1. 前往 [Firebase Console](https://console.firebase.google.com/)
2. 創建新項目或選擇現有項目
3. 項目名稱：`AutoDrive`

#### 2.2 配置 iOS 應用
1. 點擊「添加應用」→「iOS」
2. 輸入 Bundle ID: `com.example.projectDapp`
3. 下載 `GoogleService-Info.plist`
4. 將文件放到：`mobile/ios/Runner/GoogleService-Info.plist`
5. 在 Xcode 中打開項目，確認文件已添加

#### 2.3 配置 Android 應用
1. 點擊「添加應用」→「Android」
2. 輸入包名: `com.example.projectDapp`
3. 下載 `google-services.json`
4. 將文件放到：`mobile/android/app/google-services.json`

#### 2.4 獲取服務器密鑰
1. Firebase Console → 項目設置 → Cloud Messaging
2. 複製「服務器密鑰」
3. 添加到後端環境變量：

```bash
# backend/.env
FCM_SERVER_KEY=你的服務器密鑰
```

或在 `docker-compose.yml` 中添加：
```yaml
services:
  backend:
    environment:
      - FCM_SERVER_KEY=你的服務器密鑰
```

---

### 步驟 3: iOS 特定配置

#### 3.1 在 Xcode 中啟用推送通知
1. 打開 `mobile/ios/Runner.xcworkspace`
2. 選擇 `Runner` 項目 → `Runner` Target
3. 點擊「Signing & Capabilities」
4. 點擊「+ Capability」
5. 添加「Push Notifications」
6. 添加「Background Modes」並勾選：
   - ✅ Remote notifications
   - ✅ Background fetch

#### 3.2 配置 APNs 證書（生產環境）
1. 前往 [Apple Developer](https://developer.apple.com/account)
2. 創建 APNs 證書或密鑰
3. 在 Firebase Console 上傳證書/密鑰

詳細步驟請參考：`mobile/FIREBASE_SETUP_GUIDE.md`

---

### 步驟 4: 修復 iOS 編譯問題（已知問題）

**問題**: Firebase iOS pod 非模塊化頭文件錯誤

**狀態**: 已配置解決方案，但可能需要額外步驟

**解決方法**:

1. 清理並重新安裝 pods：
```bash
cd mobile/ios
rm -rf Pods Podfile.lock
pod install
```

2. 在 Xcode 中清理構建：
```
Product → Clean Build Folder (Shift + Cmd + K)
```

3. 如果仍然失敗，嘗試在 Xcode 中手動設置：
   - 選擇 `Pods` 項目
   - 選擇 `firebase_messaging` target
   - Build Settings → `Allow Non-modular Includes In Framework Modules` → YES

---

## 🧪 測試步驟

### 測試 1: 本地通知測試

在司機端主頁添加測試按鈕：
```dart
ElevatedButton(
  onPressed: () async {
    await NotificationService().sendTestNotification();
  },
  child: Text('測試本地通知'),
)
```

### 測試 2: FCM Token 驗證

查看應用日誌，確認 FCM Token 已生成：
```
✅ FCM Token: ePxW8... (很長的字符串)
✅ 用戶 1 FCM Token 更新成功: ePxW8...
```

### 測試 3: WebSocket + FCM 集成測試

1. 啟動後端：
```bash
docker-compose up
```

2. 以司機身份登入 Flutter 應用
3. 檢查日誌確認：
   - WebSocket 連接成功
   - 加入司機在線房間
   - FCM Token 發送成功

4. 以乘客身份創建新訂單
5. 確認司機收到：
   - WebSocket 即時通知（應用內）
   - FCM 推送通知（系統通知欄）

### 測試 4: 使用 Firebase Console 測試

1. 前往 Firebase Console → Cloud Messaging
2. 點擊「發送第一條消息」
3. 輸入通知內容
4. 在「目標」中選擇「FCM 註冊令牌」
5. 粘貼從應用日誌中獲取的 FCM Token
6. 發送並確認收到通知

---

## 🔧 故障排除

### 問題 1: iOS 編譯失敗 - 非模塊化頭文件

**錯誤**:
```
Include of non-modular header inside framework module 'firebase_messaging.FLTFirebaseMessagingPlugin'
```

**解決方案**:
1. 確認 Podfile 配置正確
2. 運行 `pod install`
3. 在 Xcode 中清理構建文件夾
4. 手動設置 Build Settings（見上面步驟 4）

### 問題 2: Firebase 未初始化

**錯誤**:
```
⚠️ Firebase 初始化失敗（可能未配置）
```

**解決方案**:
1. 確認 `GoogleService-Info.plist` (iOS) 和 `google-services.json` (Android) 已添加
2. 確認文件在正確的位置
3. 重新運行 `flutter clean && flutter pub get`

### 問題 3: 收不到推送通知

**排查步驟**:
1. 檢查 FCM Token 是否已生成並上傳到後端
2. 檢查後端日誌是否顯示「FCM 推送成功」
3. 確認設備允許應用的通知權限
4. iOS 真機測試（模擬器不支持推送）
5. 檢查 `FCM_SERVER_KEY` 是否配置正確

### 問題 4: Android 構建失敗

**解決方案**:
1. 確認 `google-services.json` 在 `android/app/` 目錄下
2. 確認 `android/build.gradle` 包含 Google Services plugin
3. 確認最低 SDK 版本 >= 21

---

## 📊 系統架構

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│   乘客端    │         │   後端 API   │         │   司機端    │
│  (Flutter)  │         │  (FastAPI)  │         │  (Flutter)  │
└─────────────┘         └─────────────┘         └─────────────┘
      │                        │                        │
      │ 1. 創建訂單            │                        │
      │───────────────────────>│                        │
      │                        │                        │
      │                        │ 2. WebSocket 廣播      │
      │                        │ (即時，應用內)          │
      │                        │───────────────────────>│
      │                        │                        │
      │                        │ 3. FCM 推送通知        │
      │                        │ (系統級，離線可達)      │
      │                        │───────────────────────>│
      │                        │        ↓               │
      │                        │   Firebase FCM         │
      │                        │        ↓               │
      │                        │───────────────────────>│
      │                        │                        │
      │                        │                   顯示通知
```

---

## 📝 相關文件

| 文件路徑 | 說明 |
|---------|------|
| `mobile/lib/services/notification_service.dart` | Flutter FCM 推送通知服務 |
| `mobile/lib/main.dart` | Firebase 初始化 |
| `mobile/lib/driver_home_page_new.dart` | 司機端 FCM Token 發送 |
| `mobile/FIREBASE_SETUP_GUIDE.md` | Firebase 詳細配置指南 |
| `backend/app/models/user.py` | User 模型（含 fcm_token） |
| `backend/app/services/fcm_service.py` | 後端 FCM 推送服務 |
| `backend/app/websocket/events.py` | WebSocket FCM Token 更新事件 |
| `backend/app/api/v1/trips.py` | 訂單創建時發送通知 |
| `backend/migrations/add_fcm_token_to_users.sql` | 數據庫遷移文件 |

---

## 🎯 下一步

1. **配置 Firebase Console**（必須）
   - 創建 Firebase 項目
   - 下載配置文件
   - 獲取服務器密鑰

2. **執行數據庫遷移**（必須）
   - 添加 `fcm_token` 欄位

3. **修復 iOS 編譯問題**（如果需要）
   - 按照故障排除步驟操作

4. **測試推送通知**
   - 本地通知測試
   - WebSocket + FCM 集成測試
   - Firebase Console 手動測試

5. **生產環境配置**（部署前）
   - 配置 APNs 證書
   - 設置環境變量
   - 測試不同場景（前台、背景、終止）

---

**實現者**: Claude Code
**參考文檔**: [Firebase 文檔](https://firebase.google.com/docs/flutter/setup)
**最後更新**: 2025-11-12
