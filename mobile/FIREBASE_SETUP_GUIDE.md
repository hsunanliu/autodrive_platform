# Firebase 推送通知設置指南

## 📋 前提條件

1. Google 帳號
2. Flutter 開發環境
3. Xcode（iOS）和 Android Studio

---

## 🔥 Firebase 項目設置

### 1. 創建 Firebase 項目

1. 前往 [Firebase Console](https://console.firebase.google.com/)
2. 點擊「添加項目」
3. 輸入項目名稱：`AutoDrive`
4. 選擇是否啟用 Google Analytics（可選）
5. 完成創建

### 2. 添加 iOS 應用

1. 在 Firebase 控制台點擊「添加應用」→「iOS」
2. 輸入 Bundle ID：`com.example.projectDapp`
   - 在 `mobile/ios/Runner.xcodeproj/project.pbxproj` 中查找 `PRODUCT_BUNDLE_IDENTIFIER`
3. 下載 `GoogleService-Info.plist`
4. 將文件放置到：`mobile/ios/Runner/GoogleService-Info.plist`

### 3. 添加 Android 應用

1. 在 Firebase 控制台點擊「添加應用」→「Android」
2. 輸入包名：`com.example.projectDapp`
   - 在 `mobile/android/app/build.gradle` 中查找 `applicationId`
3. 下載 `google-services.json`
4. 將文件放置到：`mobile/android/app/google-services.json`

---

## 📱 iOS 配置

### 1. 添加 GoogleService-Info.plist

```bash
# 確認文件位置
ls mobile/ios/Runner/GoogleService-Info.plist
```

### 2. 在 Xcode 中配置

1. 打開 `mobile/ios/Runner.xcworkspace`
2. 確認 `GoogleService-Info.plist` 已添加到項目中
3. 選中 `GoogleService-Info.plist` → 確認 Target Membership 包含 `Runner`

### 3. 啟用推送通知能力

1. 在 Xcode 中選擇 `Runner` 項目
2. 選擇 `Runner` Target
3. 點擊「Signing & Capabilities」
4. 點擊「+ Capability」
5. 添加「Push Notifications」
6. 添加「Background Modes」並勾選「Remote notifications」

### 4. 配置 APNs 證書（僅生產環境需要）

1. 前往 [Apple Developer](https://developer.apple.com/account)
2. 創建 APNs 證書
3. 在 Firebase Console → 項目設置 → Cloud Messaging → iOS 配置中上傳證書

---

## 🤖 Android 配置

### 1. 添加 google-services.json

```bash
# 確認文件位置
ls mobile/android/app/google-services.json
```

### 2. 修改 build.gradle

**`mobile/android/build.gradle`**（項目級別）：
```gradle
buildscript {
    dependencies {
        // 添加 Google Services plugin
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

**`mobile/android/app/build.gradle`**（應用級別）：
```gradle
// 在文件末尾添加
apply plugin: 'com.google.gms.google-services'
```

### 3. 設置最低 SDK 版本

**`mobile/android/app/build.gradle`**：
```gradle
android {
    defaultConfig {
        minSdkVersion 21  // Firebase Messaging 要求最低 21
    }
}
```

---

## 🧪 測試推送通知

### 方法 1: 使用應用內測試

```dart
// 在司機端主頁添加測試按鈕
ElevatedButton(
  onPressed: () async {
    await NotificationService().sendTestNotification();
  },
  child: Text('測試通知'),
)
```

### 方法 2: 使用 Firebase Console

1. 前往 Firebase Console → Cloud Messaging
2. 點擊「發送第一條消息」
3. 輸入通知標題和內容
4. 選擇目標：測試設備的 FCM Token
5. 發送

### 方法 3: 使用 REST API

```bash
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=YOUR_SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "DEVICE_FCM_TOKEN",
    "notification": {
      "title": "新訂單",
      "body": "從台北101到台北車站"
    },
    "data": {
      "type": "new_trip",
      "trip_id": "123"
    }
  }'
```

---

## 📝 獲取 FCM Token

### 在應用中查看

運行應用後，在日誌中查找：

```
✅ FCM Token: ePx... (很長的字符串)
```

### 在代碼中獲取

```dart
final token = NotificationService().fcmToken;
print('FCM Token: $token');
```

---

## 🔧 故障排除

### iOS 常見問題

**問題 1**: 收不到推送
```
解決方案:
1. 確認已添加 Push Notifications 能力
2. 確認已上傳 APNs 證書到 Firebase
3. 檢查設備是否允許通知權限
4. 使用真機測試（模擬器不支持推送）
```

**問題 2**: GoogleService-Info.plist 未找到
```
解決方案:
1. 確認文件在 ios/Runner/ 目錄下
2. 在 Xcode 中確認文件已添加到項目
3. Clean build folder 後重新編譯
```

### Android 常見問題

**問題 1**: google-services.json 未找到
```
解決方案:
1. 確認文件在 android/app/ 目錄下
2. 確認 build.gradle 中添加了 google-services plugin
3. 運行 flutter clean && flutter pub get
```

**問題 2**: Minimum SDK version 錯誤
```
解決方案:
在 android/app/build.gradle 中設置 minSdkVersion 21
```

---

## 🚀 生產環境配置

### 1. 獲取服務器密鑰

1. Firebase Console → 項目設置 → Cloud Messaging
2. 複製「服務器密鑰」
3. 將密鑰配置到後端環境變量：`FIREBASE_SERVER_KEY`

### 2. 配置後端推送邏輯

```python
# backend/app/services/fcm_service.py
import requests

class FCMService:
    def __init__(self, server_key: str):
        self.server_key = server_key
        self.url = "https://fcm.googleapis.com/fcm/send"

    def send_notification(self, token: str, title: str, body: str, data: dict):
        headers = {
            "Authorization": f"key={self.server_key}",
            "Content-Type": "application/json"
        }
        payload = {
            "to": token,
            "notification": {
                "title": title,
                "body": body
            },
            "data": data,
            "priority": "high"
        }
        response = requests.post(self.url, json=payload, headers=headers)
        return response.json()
```

---

## 📚 相關資源

- [Firebase 文檔](https://firebase.google.com/docs/flutter/setup)
- [FCM 文檔](https://firebase.google.com/docs/cloud-messaging)
- [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)

---

**最後更新**: 2025-11-12
**維護者**: AutoDrive Team
