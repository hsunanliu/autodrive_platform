# 應用配置說明

## 快速開始

當你的網路 IP 改變時，只需要修改 `app_config.local.dart` 文件即可，不需要改動其他代碼。

### 1. 創建本地配置（首次使用）

如果 `app_config.local.dart` 不存在，複製示例文件：

```bash
cp lib/config/app_config.local.dart.example lib/config/app_config.local.dart
```

### 2. 查看你的 Mac IP 地址

在終端執行：

```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
```

你會看到類似：
```
inet 192.168.50.143 netmask 0xffffff00 broadcast 192.168.50.255
```

其中 `192.168.50.143` 就是你的 IP 地址。

### 3. 修改本地配置

編輯 `app_config.local.dart`，將 IP 改為你的實際 IP：

```dart
String get localBackendUrl => 'http://192.168.50.143:8000/api/v1';
```

### 4. 重新運行 app

```bash
flutter run
```

或使用快速啟動腳本：

```bash
./run_flutter.sh
```

## 文件說明

- **app_config.dart** - 配置類（提交到 git）
- **app_config.local.dart** - 本地配置（不提交到 git）⚠️
- **app_config.local.dart.example** - 配置示例（提交到 git）

## 為什麼這樣設計？

### 問題
每次網路 IP 改變（WiFi 切換、DHCP 重新分配等），都需要修改多個文件中的 IP 地址，然後提交到 git，非常麻煩。

### 解決方案
- `app_config.local.dart` 只在本地使用，不提交到 git
- 其他開發者 clone 專案後，複製 `.example` 文件並修改自己的 IP
- 每個人可以有自己的本地配置，互不干擾

## 常見問題

### Q: 為什麼運行時報錯 "localBackendUrl not found"？

A: 你需要創建 `app_config.local.dart` 文件。執行：

```bash
cp lib/config/app_config.local.dart.example lib/config/app_config.local.dart
```

然後修改裡面的 IP 地址。

### Q: 如何查看當前使用的配置？

A: 在 app 啟動時會打印 WebSocket 連接的 URL，可以在日誌中查看。

### Q: 可以使用域名嗎？

A: 可以！如果你設置了本地 DNS 或使用 mDNS，可以用：

```dart
String get localBackendUrl => 'http://my-mac.local:8000/api/v1';
```

## 其他解決方案

### 方案 A：使用固定 IP（推薦給長期開發）

在路由器設置中給你的 Mac 分配固定 IP，這樣就不用每次改了。

### 方案 B：使用 mDNS/Bonjour

macOS 支援 `.local` 域名：

```dart
String get localBackendUrl => 'http://你的電腦名稱.local:8000/api/v1';
```

查看電腦名稱：**系統設置 > 共享 > 本機名稱**

例如：`MacBook-Pro.local`
