#!/bin/bash
# tests/run_tests.sh

echo "🧪 執行完整測試套件..."

echo "1. 編譯智能合約..."
iota move build

echo "2. 執行單元測試..."
iota move test

echo "3. 檢查測試覆蓋率..."
iota move coverage

echo "4. 執行特定模組測試..."
echo "   - 常數模組測試"
iota move test --filter constants_test

echo "   - 用戶註冊模組測試"  
iota move test --filter user_registry_test

echo "   - 車輛註冊模組測試"
iota move test --filter vehicle_registry_test

echo "   - 配對服務模組測試"
iota move test --filter ride_matching_test

echo "5. 驗證所有依賴關係..."
iota move build --verbose

echo "✅ 測試完成！"
