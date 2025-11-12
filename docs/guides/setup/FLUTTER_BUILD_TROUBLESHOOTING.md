# Flutter Build 故障排除指南

## 快速啟動

```bash
# 方法 1: 使用快速啟動腳本
./run_flutter.sh

# 方法 2: 直接運行
cd mobile && flutter run
```

---

## 常見問題和解決方案

### 問題 1: "No devices found"

**症狀**: Flutter 找不到設備

**解決方案**:
```bash
# 1. 檢查設備連接
flutter devices

# 2. 如果是實體 iOS 設備
#    - 解鎖設備
#    - 點擊"信任此電腦"
#    - 重新運行 flutter devices

# 3. 如果要使用模擬器
open -a Simulator  # 啟動 iOS 模擬器
flutter emulators  # 查看可用模擬器
```

---

### 問題 2: "Build failed" 或 "Xcode build error"

**症狀**: Xcode build 失敗

**解決方案**:
```bash
# 1. 清理構建緩存
cd mobile
flutter clean
rm -rf ios/Pods ios/Podfile.lock ios/.symlinks

# 2. 重新安裝依賴
flutter pub get
cd ios && pod install --repo-update && cd ..

# 3. 重新 build
flutter build ios --no-codesign
```

---

### 問題 3: CocoaPods 相關錯誤

**症狀**:
- `pod install` 失敗
- "Unable to find a specification for..."
- CocoaPods 版本錯誤

**解決方案**:
```bash
# 1. 更新 CocoaPods
sudo gem install cocoapods

# 2. 清理 CocoaPods 緩存
cd mobile/ios
pod cache clean --all
pod deintegrate
pod setup
pod install

# 3. 如果還有問題，更新 repo
pod repo update
pod install
```

---

### 問題 4: 簽名錯誤 (Provisioning profile)

**症狀**:
- "No valid code signing certificates found"
- Provisioning profile 錯誤

**解決方案**:

**選項 A: 開發測試（推薦）**
```bash
# 使用無簽名模式（只能在模擬器上運行）
flutter run --debug
```

**選項 B: 實體設備測試**
1. 打開 Xcode: `open ios/Runner.xcworkspace`
2. 選擇 Runner target
3. 在 "Signing & Capabilities" 中：
   - 勾選 "Automatically manage signing"
   - 選擇您的 Apple ID Team
   - 修改 Bundle Identifier（加上您的前綴，如 `com.yourname.autodrive`）

---

### 問題 5: 依賴版本衝突

**症狀**:
- `pub get` 失敗
- "version solving failed"

**解決方案**:
```bash
# 1. 查看過時的依賴
flutter pub outdated

# 2. 更新依賴（如果需要）
flutter pub upgrade

# 3. 如果特定依賴有問題，修改 pubspec.yaml
# 然後運行
flutter pub get
```

---

### 問題 6: 運行時崩潰或白屏

**症狀**:
- App 啟動後立即崩潰
- 顯示白屏或黑屏

**解決方案**:
```bash
# 1. 查看詳細日誌
flutter run --verbose

# 2. 檢查後端連接
# 確保 Docker 容器正在運行
cd /Users/hsuanliu/autodrive_platform
docker-compose ps

# 3. 檢查 constants.dart 中的 API URL
# mobile/lib/constants.dart
# 確保 API_BASE_URL 正確

# 4. 清理並重新安裝
flutter clean
flutter pub get
flutter run
```

---

### 問題 7: "withOpacity is deprecated" 警告

**症狀**: 大量 deprecated 警告

**解決方案**:
這些是警告，不影響運行。如果要修復：

```dart
// 舊代碼
Colors.white.withOpacity(0.1)

// 新代碼
Colors.white.withValues(alpha: 0.1)
```

---

## 完整清理流程

如果以上都不行，執行完整清理：

```bash
#!/bin/bash

echo "🧹 完整清理 Flutter 專案..."

cd mobile

# 1. Flutter 清理
flutter clean

# 2. 刪除生成的文件
rm -rf .dart_tool/
rm -rf build/
rm -rf ios/Pods
rm -rf ios/Podfile.lock
rm -rf ios/.symlinks
rm -rf .flutter-plugins
rm -rf .flutter-plugins-dependencies

# 3. 重新獲取依賴
flutter pub get

# 4. 重新安裝 iOS 依賴
cd ios
pod cache clean --all
pod install
cd ..

# 5. 運行
flutter run

echo "✅ 清理完成！"
```

---

## 檢查清單

在運行 Flutter 應用前，確保：

- [ ] Docker 容器正在運行 (`docker-compose ps`)
- [ ] 後端 API 可訪問 (`curl http://localhost:8000`)
- [ ] 設備已連接並信任 (`flutter devices`)
- [ ] Xcode 已安裝並更新到最新版本
- [ ] CocoaPods 已安裝 (`pod --version`)

---

## 獲取幫助

如果問題仍未解決，請提供以下信息：

```bash
# 1. Flutter 環境信息
flutter doctor -v > flutter_info.txt

# 2. 詳細錯誤日誌
flutter run --verbose > flutter_error.log 2>&1

# 3. 依賴信息
flutter pub deps > deps.txt
```

然後查看這些日誌文件以找到具體問題。

---

## 當前專案狀態

✅ **環境檢查結果** (2025-11-07):
- Flutter: v3.35.2 ✅
- Dart: v3.9.0 ✅
- Xcode: v16.3 ✅
- CocoaPods: v1.16.2 ✅
- iOS 設備: 已連接 ✅
- Build 測試: 成功 ✅

**如果您的環境配置不同，可能需要調整配置。**
