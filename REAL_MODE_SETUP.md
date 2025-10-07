# 🔄 從 Mock 模式切換到實際模式指南

## 📋 準備工作清單

### 1. 🔐 錢包準備

#### A. 創建平台管理錢包
```bash
# 使用 IOTA CLI 或錢包應用創建新錢包
# 記錄以下信息:
- 錢包地址 (Address)
- 私鑰 (Private Key) - 需要安全保存
- 助記詞 (Mnemonic) - 備份用
```

#### B. 獲取測試網 IOTA
```bash
# 方法1: 使用 IOTA 測試網水龍頭
# 訪問: https://faucet.testnet.iota.org/
# 輸入錢包地址獲取測試幣

# 方法2: 使用 Discord 機器人
# 加入 IOTA Discord 並使用 !faucet 命令
```

#### C. 驗證錢包餘額
```bash
# 使用我們的檢查腳本驗證
curl -X POST "https://api.testnet.iota.cafe" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "iota_getBalance",
    "params": ["YOUR_WALLET_ADDRESS"]
  }'
```

### 2. 🔧 配置更新

#### A. 環境變量設置
```env
# 在 .env 文件中添加:
PLATFORM_WALLET_ADDRESS=0x你的錢包地址
PLATFORM_WALLET_PRIVATE_KEY=你的私鑰
MOCK_MODE=false
```

#### B. 安全配置
```python
# backend/app/config.py 更新:
class Settings(BaseSettings):
    # 現有配置...
    
    # 錢包配置 (生產環境從環境變量讀取)
    PLATFORM_WALLET: str = os.getenv("PLATFORM_WALLET_ADDRESS", "")
    PLATFORM_PRIVATE_KEY: str = os.getenv("PLATFORM_WALLET_PRIVATE_KEY", "")
    
    # 實際模式
    MOCK_MODE: bool = os.getenv("MOCK_MODE", "true").lower() == "false"
```

### 3. 🛠️ 代碼修改需求

#### A. 私鑰管理
```python
# backend/app/services/wallet_service.py (新文件)
import os
from cryptography.fernet import Fernet

class WalletService:
    def __init__(self):
        self.encryption_key = os.getenv("WALLET_ENCRYPTION_KEY")
        
    def get_platform_private_key(self) -> str:
        """安全獲取平台私鑰"""
        encrypted_key = os.getenv("PLATFORM_WALLET_PRIVATE_KEY")
        if self.encryption_key:
            f = Fernet(self.encryption_key)
            return f.decrypt(encrypted_key.encode()).decode()
        return encrypted_key
```

#### B. 交易簽名
```python
# backend/app/services/transaction_service.py (新文件)
class TransactionService:
    async def sign_and_execute_transaction(
        self,
        transaction_data: Dict[str, Any],
        private_key: str
    ) -> Dict[str, Any]:
        """簽名並執行交易"""
        try:
            # 使用 IOTA SDK 簽名交易
            signed_tx = await self.sign_transaction(transaction_data, private_key)
            
            # 提交到網絡
            result = await self.submit_transaction(signed_tx)
            
            return {
                "success": True,
                "transaction_hash": result["digest"],
                "gas_used": result["gas_used"]
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }
```

### 4. 🔍 風險評估

#### A. 安全風險
- ❌ **私鑰洩露**: 可能導致資金損失
- ❌ **Gas 費用**: 每次交易需要消耗真實 IOTA
- ❌ **交易失敗**: 可能因為網絡問題或合約錯誤

#### B. 緩解措施
- ✅ **私鑰加密**: 使用環境變量和加密存儲
- ✅ **測試網使用**: 只在測試網操作，無真實價值
- ✅ **錯誤處理**: 完善的錯誤處理和回滾機制
- ✅ **監控日誌**: 詳細記錄所有交易

### 5. 📊 切換步驟

#### 步驟 1: 準備錢包
```bash
# 1. 創建錢包並獲取測試幣
# 2. 驗證錢包餘額 > 1 IOTA
# 3. 記錄錢包信息
```

#### 步驟 2: 更新配置
```bash
# 1. 修改 backend/app/config.py
# 2. 設置環境變量
# 3. 重啟服務
```

#### 步驟 3: 測試驗證
```bash
# 1. 運行檢查腳本
# 2. 測試用戶註冊 (會產生真實交易)
# 3. 監控交易狀態
```

#### 步驟 4: 監控運行
```bash
# 1. 監控後端日誌
# 2. 檢查錢包餘額變化
# 3. 驗證鏈上交易
```

## ⚠️ 重要注意事項

### 安全警告
1. **永遠不要在代碼中硬編碼私鑰**
2. **使用環境變量存儲敏感信息**
3. **定期輪換錢包和密鑰**
4. **監控異常交易活動**

### 成本考量
1. **每次用戶註冊**: ~0.001 IOTA Gas 費
2. **每次車輛註冊**: ~0.001 IOTA Gas 費  
3. **每次支付交易**: ~0.002 IOTA Gas 費
4. **建議錢包餘額**: 至少 10 IOTA 用於測試

### 回滾計劃
如果遇到問題，可以快速切回 Mock 模式:
```bash
# 設置環境變量
export MOCK_MODE=true

# 或修改配置文件
MOCK_MODE: bool = True

# 重啟服務
docker-compose restart backend
```