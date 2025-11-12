# Deep Link 開發進度報告

**報告日期**: 2025-10-27
**專案**: AutoDrive - Slush Wallet 整合
**目標**: 實現 App 與 Slush Wallet 之間的 Deep Link 跳轉

---

## 📊 整體進度概況

### 完成度: 40% ⚠️

```
[████████░░░░░░░░░░░░] 40%

✅ 已完成 (4/10)
⚠️  進行中 (0/10)
❌ 未開始 (6/10)
```

---

## ✅ 已完成項目

### 1. Deep Link 邏輯實作 ✅
**位置**: `mobile/lib/services/sui_wallet_connector.dart`

**已實作功能**:
- Deep Link URL 生成
- 錢包連接請求 (`connectWallet`)
- 交易簽署請求 (`signTransaction`)
- 回調處理邏輯 (`handleWalletCallback`)

**Deep Link Scheme**:
```dart
// 連接錢包
suiet://connect?callback=autodrive%3A%2F%2Fwallet-callback

// 簽署交易
suiet://sign?data=<base64>&callback=autodrive%3A%2F%2Fsign-callback

// 回調格式
autodrive://wallet-callback?address=0x...
autodrive://sign-callback?signature=...&digest=...
```

**程式碼位置**:
- 生成連接 URL: `sui_wallet_connector.dart:89-96`
- 生成簽署 URL: `sui_wallet_connector.dart:185-191`
- 處理回調: `sui_wallet_connector.dart:193-220`

---

### 2. UI 整合 ✅
**位置**: `mobile/lib/pages/register_with_wallet_connect_page.dart`

**已整合功能**:
- 連接 Slush Wallet 按鈕 (line 182)
- 手動輸入錢包地址 (line 195-207)
- 錢包連接狀態顯示 (line 209-263)
- 錯誤提示訊息

**用戶流程**:
```
註冊頁面 → 點擊「連接 Slush Wallet」→ 跳轉至 Slush Wallet
          ↓ (用戶授權)
        ❌ 目前無法返回 AutoDrive (Deep Link 回調未配置)
```

---

### 3. 依賴套件安裝 ✅
**位置**: `mobile/pubspec.yaml`

已安裝必要套件:
```yaml
url_launcher: ^6.2.0          # 用於打開 Deep Link
flutter_secure_storage: ^9.0.0 # 用於儲存錢包地址
```

**狀態**: ✅ 套件已正確安裝

---

### 4. 品牌更新 ✅
所有 UI 文字已從 "Suiet Wallet" 更新為 "Slush Wallet"

**修改檔案**:
- `sui_wallet_connector.dart`
- `register_with_wallet_connect_page.dart`
- `payment_dialog.dart`

---

## ❌ 未完成項目 (關鍵阻塞)

### 1. iOS URL Scheme 配置 ❌ (最高優先級)
**問題**: iOS `Info.plist` 未配置 `autodrive://` URL Scheme

**當前狀態**:
```xml
<!-- Info.plist 缺少 CFBundleURLTypes 配置 -->
❌ 無 URL Scheme 定義
```

**需要新增**:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key>
    <string>com.autodrive.app</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>autodrive</string>
    </array>
  </dict>
</array>
```

**影響**: 🚫 Slush Wallet 無法回調至 AutoDrive

---

### 2. Android Intent Filter 配置 ❌ (最高優先級)
**問題**: Android `AndroidManifest.xml` 未配置 Intent Filter

**當前狀態**:
```
❌ AndroidManifest.xml 檔案不存在或未配置
```

**需要新增** (在 `<activity android:name=".MainActivity">` 內):
```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />

  <!-- 錢包連接回調 -->
  <data
    android:scheme="autodrive"
    android:host="wallet-callback" />

  <!-- 交易簽署回調 -->
  <data
    android:scheme="autodrive"
    android:host="sign-callback" />
</intent-filter>
```

**影響**: 🚫 Android 系統無法識別 `autodrive://` URL

---

### 3. Deep Link 監聽器 ❌ (高優先級)
**問題**: `main.dart` 未實作 Deep Link 監聽

**當前狀態**:
```dart
// main.dart:25-34
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = await SessionManager.loadSession();
  // ❌ 缺少 Deep Link 監聽邏輯
  runApp(ProjectDappApp(initialSession: session));
}
```

**需要新增套件**:
```yaml
# pubspec.yaml
dependencies:
  uni_links: ^0.5.1  # 或 app_links: ^3.4.0 (推薦)
```

**需要實作**:
```dart
import 'package:uni_links/uni_links.dart';
import 'dart:async';

StreamSubscription? _linkSubscription;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 處理應用啟動時的 Deep Link
  try {
    final initialUri = await getInitialUri();
    if (initialUri != null) {
      _handleDeepLink(initialUri);
    }
  } catch (e) {
    print('Failed to get initial URI: $e');
  }

  // 2. 監聽應用運行時的 Deep Link
  _linkSubscription = uriLinkStream.listen((Uri? uri) {
    if (uri != null) {
      _handleDeepLink(uri);
    }
  }, onError: (err) {
    print('Deep link error: $err');
  });

  runApp(ProjectDappApp(initialSession: session));
}

void _handleDeepLink(Uri uri) {
  print('Received deep link: $uri');

  // 3. 將 URI 傳遞給 SuiWalletConnector 處理
  final walletConnector = SuiWalletConnector();
  walletConnector.handleWalletCallback(uri);
}
```

**影響**: 🚫 無法接收 Slush Wallet 的回調

---

### 4. 全域 WalletConnector 實例 ❌ (中優先級)
**問題**: 無全域共享的 `SuiWalletConnector` 實例

**當前問題**:
- 每個頁面各自創建 `SuiWalletConnector()`
- Deep Link 回調無法通知正確的頁面
- 狀態無法跨頁面共享

**建議解決方案**:
```dart
// 方案 1: 使用 Provider (推薦)
void main() async {
  runApp(
    ChangeNotifierProvider(
      create: (_) => SuiWalletConnector(),
      child: ProjectDappApp(),
    ),
  );
}

// 方案 2: 使用 GetIt (依賴注入)
final getIt = GetIt.instance;
getIt.registerSingleton<SuiWalletConnector>(SuiWalletConnector());

// 方案 3: 簡單的 Singleton
class SuiWalletConnector {
  static final SuiWalletConnector instance = SuiWalletConnector._internal();
  factory SuiWalletConnector() => instance;
  SuiWalletConnector._internal();
}
```

---

### 5. 回調狀態通知機制 ❌ (中優先級)
**問題**: 回調成功後無法通知 UI 更新

**需要實作**:
- 使用 Stream/EventBus 廣播回調事件
- 或使用 `ChangeNotifier` 通知監聽者

**建議實作** (已在 `SuiWalletConnector` 中使用 `ChangeNotifier`):
```dart
class SuiWalletConnector extends ChangeNotifier {
  // ... existing code

  Future<void> handleWalletCallback(Uri uri) async {
    // 處理回調
    if (path == '/wallet-callback') {
      final address = params['address'];
      if (address != null) {
        await setWalletAddress(address);
        notifyListeners(); // ✅ 已實作
      }
    }
  }
}
```

**頁面監聽**:
```dart
// 註冊頁面需要監聽變化
class _RegisterPageState extends State<RegisterPage> {
  late SuiWalletConnector _walletConnector;

  @override
  void initState() {
    super.initState();
    _walletConnector = context.read<SuiWalletConnector>();
    _walletConnector.addListener(_onWalletChanged);
  }

  void _onWalletChanged() {
    if (_walletConnector.isConnected) {
      setState(() {
        _connectedAddress = _walletConnector.walletAddress;
      });
    }
  }

  @override
  void dispose() {
    _walletConnector.removeListener(_onWalletChanged);
    super.dispose();
  }
}
```

---

### 6. Deep Link 測試 ❌ (低優先級)
**問題**: 無測試流程驗證 Deep Link 是否正常運作

**需要測試項目**:
1. iOS 模擬器測試
   ```bash
   xcrun simctl openurl booted "autodrive://wallet-callback?address=0x123..."
   ```

2. Android 模擬器測試
   ```bash
   adb shell am start -W -a android.intent.action.VIEW \
     -d "autodrive://wallet-callback?address=0x123..." \
     com.example.project_dapp
   ```

3. 真機測試 (需實際安裝 Slush Wallet)

---

## 🔍 技術債務與風險

### 高風險項目
1. **URL Scheme 衝突**
   - 風險: `autodrive://` 可能與其他 App 衝突
   - 建議: 使用更具體的 scheme (如 `autodrive-sui://`)
   - 或使用 Universal Links (iOS) / App Links (Android)

2. **Slush Wallet 兼容性**
   - 風險: Slush Wallet 可能不支援 `suiet://` scheme
   - 建議: 測試確認或聯繫 Slush 官方確認
   - 備案: 使用 Universal Links

3. **安全性**
   - 風險: Deep Link 可被偽造
   - 建議: 驗證回調來源
   - 實作 nonce/challenge 機制

---

## 📋 實施計劃

### 階段 1: 基礎配置 (1-2 小時) - 最高優先級
- [ ] 安裝 `uni_links` 或 `app_links` 套件
- [ ] 配置 iOS `Info.plist`
- [ ] 配置 Android `AndroidManifest.xml`
- [ ] 實作 `main.dart` 中的 Deep Link 監聽器

### 階段 2: 狀態管理 (1 小時) - 高優先級
- [ ] 實作全域 `SuiWalletConnector` 實例
- [ ] 整合 Provider 或 GetIt
- [ ] 確保回調能通知正確的頁面

### 階段 3: 測試驗證 (2-3 小時) - 中優先級
- [ ] 模擬器測試 (iOS + Android)
- [ ] 真機測試 (需 Slush Wallet)
- [ ] 錯誤情境測試 (取消、超時等)

### 階段 4: 優化 (1-2 小時) - 低優先級
- [ ] 添加載入動畫
- [ ] 改善錯誤提示
- [ ] 實作超時機制
- [ ] 安全性強化

---

## 🎯 下一步行動

### 立即行動 (今日完成)
1. **安裝 Deep Link 套件**
   ```bash
   cd /Users/hsuanliu/autodrive_platform/mobile
   flutter pub add uni_links
   # 或
   flutter pub add app_links
   ```

2. **配置 iOS**
   - 編輯 `ios/Runner/Info.plist`
   - 加入 `CFBundleURLTypes` 配置

3. **配置 Android**
   - 找到 `android/app/src/main/AndroidManifest.xml`
   - 在 MainActivity 中加入 `<intent-filter>`

4. **實作監聽器**
   - 修改 `main.dart`
   - 加入 Deep Link 監聽邏輯

### 本週完成
- 完成基礎配置與測試
- 確保模擬器測試通過
- 準備真機測試環境

---

## 📚 參考資源

### 官方文檔
- **uni_links**: https://pub.dev/packages/uni_links
- **app_links**: https://pub.dev/packages/app_links (推薦)
- **Flutter Deep Linking**: https://docs.flutter.dev/ui/navigation/deep-linking
- **iOS Universal Links**: https://developer.apple.com/ios/universal-links/
- **Android App Links**: https://developer.android.com/training/app-links

### 專案內部文檔
- **Slush 整合分析**: `SLUSH_INTEGRATION_ANALYSIS.md` (第 261-295 行)
- **任務完成總結**: `TASK_COMPLETION_SUMMARY_2025_10_27.md`

---

## ✅ 驗收標準

### 功能驗收
- [ ] 點擊「連接 Slush Wallet」能跳轉至 Slush Wallet
- [ ] Slush Wallet 授權後能返回 AutoDrive
- [ ] 錢包地址正確傳遞並儲存
- [ ] UI 顯示錢包連接狀態

### 技術驗收
- [ ] iOS 模擬器測試通過
- [ ] Android 模擬器測試通過
- [ ] 真機測試通過 (如有條件)
- [ ] 錯誤情境處理正常

### 用戶體驗驗收
- [ ] 跳轉流程順暢，無卡頓
- [ ] 錯誤提示清晰易懂
- [ ] 載入狀態有視覺反饋
- [ ] 取消操作能正常返回

---

## 🔧 故障排除指南

### 問題 1: iOS Deep Link 不工作
**檢查清單**:
- [ ] `Info.plist` 配置正確
- [ ] Bundle ID 與配置一致
- [ ] 重新編譯安裝應用
- [ ] 使用 `xcrun simctl openurl` 測試

### 問題 2: Android Deep Link 不工作
**檢查清單**:
- [ ] `AndroidManifest.xml` 配置正確
- [ ] Package name 與配置一致
- [ ] 使用 `adb shell am start` 測試
- [ ] 檢查 Logcat 輸出

### 問題 3: 回調無反應
**檢查清單**:
- [ ] `main.dart` 有監聽 `uriLinkStream`
- [ ] `handleWalletCallback` 被正確調用
- [ ] 檢查 console 輸出
- [ ] 確認 `notifyListeners()` 被調用

---

## 📊 進度追蹤

### 本週目標 (Week 1)
```
階段 1: 基礎配置  [░░░░░░░░░░] 0%
階段 2: 狀態管理  [░░░░░░░░░░] 0%
階段 3: 測試驗證  [░░░░░░░░░░] 0%
階段 4: 優化      [░░░░░░░░░░] 0%
```

### 總體完成度
```
當前: 40% [████████░░░░░░░░░░░░]
目標: 90% [██████████████████░░]
```

---

**報告結束**
**下次更新**: 完成階段 1 後
**負責人**: 開發團隊
**審核人**: 技術主管
