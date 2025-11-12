# 📦 IPFS 整合指南

**文檔類型**: 技術指南 / 部署文檔
**建立日期**: 2025-10-26
**版本**: v1.0

---

## 📋 概述

AutoDrive Platform 整合了 IPFS（InterPlanetary File System）用於存儲退款證據、服務證明等文件。鏈上僅保存 CID（Content Identifier），實際文件存儲在 IPFS 網絡中。

### 主要優勢

✅ **去中心化存儲**: 文件分散存儲，無單點故障
✅ **不可篡改**: 內容尋址確保文件完整性
✅ **降低鏈上成本**: 鏈上僅保存 CID（約 46 bytes）
✅ **永久保存**: 固定的文件不會被刪除
✅ **全球可訪問**: 通過任何 IPFS 節點或 Gateway 訪問

---

## 🎯 使用場景

### 1. 退款證據上傳
- 行程問題截圖
- 服務品質證明
- 溝通記錄
- 損壞照片

### 2. 服務證明
- 行程完成照片
- 乘客簽名
- GPS 軌跡記錄

### 3. 車輛文檔
- 車輛保險證明
- 駕駛執照
- 車輛檢驗報告

---

## 🚀 快速開始

### 方法 1: 使用本地 IPFS 節點（推薦）

#### 安裝 IPFS

**macOS**:
```bash
brew install ipfs
```

**Linux**:
```bash
wget https://dist.ipfs.io/go-ipfs/v0.15.0/go-ipfs_v0.15.0_linux-amd64.tar.gz
tar -xvzf go-ipfs_v0.15.0_linux-amd64.tar.gz
cd go-ipfs
sudo bash install.sh
```

**Windows**:
下載並執行：https://dist.ipfs.io/go-ipfs/v0.15.0/go-ipfs_v0.15.0_windows-amd64.zip

#### 初始化並啟動

```bash
# 初始化 IPFS 倉庫
ipfs init

# 啟動守護進程
ipfs daemon

# 驗證運行狀態
ipfs id
```

成功啟動後會看到：
```
Daemon is ready
API server listening on /ip4/127.0.0.1/tcp/5001
Gateway (readonly) server listening on /ip4/127.0.0.1/tcp/8080
```

---

### 方法 2: 使用公共 IPFS Gateway（測試用）

如果不想運行本地節點，可以使用公共 Gateway：

**修改配置** (`backend/app/services/ipfs_service.py`):
```python
ipfs_service = IPFSService(
    api_url="https://ipfs.infura.io:5001",  # Infura IPFS API
    gateway_url="https://ipfs.io"            # 公共 Gateway
)
```

⚠️ **注意**: 公共服務有速率限制，生產環境建議使用本地節點或專用服務（Pinata, Fleek）

---

## 🔧 後端整合

### API 端點

#### 1. 上傳文件到 IPFS

**端點**: `POST /api/v1/ipfs/upload`

**請求**:
```bash
curl -X POST "http://localhost:8000/api/v1/ipfs/upload" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "file=@refund_proof.jpg" \
  -F "purpose=refund_evidence" \
  -F "related_id=123"
```

**回應**:
```json
{
  "success": true,
  "cid": "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG",
  "size": 123456,
  "filename": "refund_proof.jpg",
  "hash": "sha256_hash_here",
  "ipfs_url": "http://localhost:8080/ipfs/QmYwAP...",
  "uploaded_at": "2025-10-26T12:00:00"
}
```

#### 2. 檢索文件

**端點**: `GET /api/v1/ipfs/retrieve/{cid}`

```bash
curl -X GET "http://localhost:8000/api/v1/ipfs/retrieve/QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -o downloaded_file.jpg
```

#### 3. 獲取文件資訊

**端點**: `GET /api/v1/ipfs/info/{cid}`

```bash
curl -X GET "http://localhost:8000/api/v1/ipfs/info/QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**回應**:
```json
{
  "success": true,
  "data": {
    "cid": "QmYwAP...",
    "size": 123456,
    "num_links": 0,
    "block_size": 123456
  }
}
```

#### 4. 驗證文件完整性

**端點**: `POST /api/v1/ipfs/verify/{cid}`

```bash
curl -X POST "http://localhost:8000/api/v1/ipfs/verify/QmYwAP..." \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "expected_hash=sha256_hash_here"
```

---

## 🔐 安全考量

### 1. 文件訪問控制

IPFS 本身不提供訪問控制，任何人只要知道 CID 就能訪問文件。

**解決方案**:
- **加密文件**: 上傳前使用 AES 加密
- **私有 IPFS 網絡**: 使用 swarm key 建立私有網絡
- **後端代理**: 通過後端 API 控制訪問權限

### 2. 文件加密示例

```python
from cryptography.fernet import Fernet

# 生成密鑰
key = Fernet.generate_key()
cipher = Fernet(key)

# 加密文件
encrypted_content = cipher.encrypt(file_content)

# 上傳加密文件
result = await ipfs_service.upload_file(encrypted_content, ...)

# 將密鑰安全存儲（不要放在 IPFS！）
# 例如：存儲在數據庫中，與用戶關聯
```

### 3. 文件大小限制

建議限制：
- 圖片：最大 10MB
- PDF：最大 20MB
- 視頻：最大 100MB

---

## 💾 數據庫 Schema

### RefundRequest 表更新

```sql
ALTER TABLE refund_requests
ADD COLUMN evidence_cid VARCHAR(100),
ADD COLUMN evidence_hash VARCHAR(64),
ADD COLUMN evidence_filename VARCHAR(255);
```

### 範例記錄

```json
{
  "refund_request_id": 123,
  "trip_id": 456,
  "requester_id": 789,
  "refund_amount": 100.5,
  "reason": "司機提前結束行程",
  "evidence_cid": "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG",
  "evidence_hash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "evidence_filename": "proof.jpg",
  "status": "pending"
}
```

---

## 📊 審計日誌

所有 IPFS 上傳都會記錄到審計日誌：`logs/ipfs_upload_audit.jsonl`

### 日誌格式

```json
{
  "timestamp": "2025-10-26T12:00:00",
  "cid": "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG",
  "filename": "refund_proof.jpg",
  "uploaded_by": 123,
  "purpose": "refund_evidence",
  "related_id": 456
}
```

### 查詢審計日誌

```bash
# 查看最近 10 筆上傳
tail -n 10 logs/ipfs_upload_audit.jsonl | jq

# 搜尋特定用戶的上傳
cat logs/ipfs_upload_audit.jsonl | jq 'select(.uploaded_by == 123)'

# 統計上傳總數
wc -l logs/ipfs_upload_audit.jsonl
```

---

## 🎨 前端整合

### React 上傳範例

```javascript
import { ipfsAPI } from '../services/api';

async function uploadRefundEvidence(file, refundRequestId) {
  const formData = new FormData();
  formData.append('file', file);
  formData.append('purpose', 'refund_evidence');
  formData.append('related_id', refundRequestId);

  try {
    const response = await ipfsAPI.upload(formData);

    console.log('上傳成功:', response.data.cid);
    console.log('IPFS URL:', response.data.ipfs_url);

    return response.data;
  } catch (error) {
    console.error('上傳失敗:', error);
    throw error;
  }
}

// 使用範例
<input
  type="file"
  accept="image/*,application/pdf"
  onChange={(e) => uploadRefundEvidence(e.target.files[0], 123)}
/>
```

### Flutter 上傳範例

```dart
import 'package:http/http.dart' as http;

Future<Map<String, dynamic>> uploadToIPFS(File file, int refundId) async {
  var request = http.MultipartRequest(
    'POST',
    Uri.parse('$apiUrl/api/v1/ipfs/upload'),
  );

  request.headers['Authorization'] = 'Bearer $token';
  request.fields['purpose'] = 'refund_evidence';
  request.fields['related_id'] = refundId.toString();
  request.files.add(await http.MultipartFile.fromPath('file', file.path));

  var response = await request.send();
  var responseData = await response.stream.bytesToString();

  return json.decode(responseData);
}
```

---

## 🌐 公共 Gateway 列表

如果本地節點不可用，可通過公共 Gateway 訪問文件：

| Gateway | URL 格式 | 速度 | 可靠性 |
|---------|----------|------|--------|
| **IPFS.io** | `https://ipfs.io/ipfs/{cid}` | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Cloudflare** | `https://cloudflare-ipfs.com/ipfs/{cid}` | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Infura** | `https://ipfs.infura.io/ipfs/{cid}` | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Pinata** | `https://gateway.pinata.cloud/ipfs/{cid}` | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

---

## 💰 成本分析

### 本地節點（免費）

- **硬碟空間**: 約 1GB - 100GB（取決於固定文件數量）
- **頻寬**: 上傳/下載使用本地頻寬
- **維護**: 需要運行與維護 IPFS 守護進程

### 商業服務（付費）

#### Pinata
- **免費方案**: 1GB 儲存空間
- **付費方案**: $20/月起（100GB）
- **優點**: 自動固定、CDN 加速、簡單易用

#### Fleek
- **免費方案**: 50GB 頻寬/月
- **付費方案**: $19/月起
- **優點**: 整合 CDN、自動備份

#### Infura IPFS
- **免費方案**: 5GB 儲存空間
- **付費方案**: 按用量計費
- **優點**: 可靠性高、與 Infura 其他服務整合

---

## 🐛 疑難排解

### 問題 1: IPFS 守護進程無法啟動

**錯誤訊息**: `Error: lock /Users/xxx/.ipfs/repo.lock: someone else has the lock`

**解決方法**:
```bash
# 刪除鎖文件
rm ~/.ipfs/repo.lock

# 重新啟動
ipfs daemon
```

### 問題 2: 無法連接到 IPFS API

**錯誤訊息**: `ConnectionError: Cannot connect to IPFS node`

**檢查步驟**:
```bash
# 1. 確認守護進程運行
ps aux | grep ipfs

# 2. 測試 API 端點
curl http://localhost:5001/api/v0/id

# 3. 檢查防火牆設置
```

### 問題 3: 文件上傳失敗（413 錯誤）

**原因**: 文件超過大小限制

**解決方法**:
- 壓縮文件
- 調整後端限制（`ipfs.py` 中的 `MAX_FILE_SIZE`）

### 問題 4: CID 無法訪問

**原因**:
- 文件未被固定
- 節點離線
- 網絡連接問題

**解決方法**:
```bash
# 檢查文件是否固定
ipfs pin ls | grep QmYwAP...

# 重新固定文件
ipfs pin add QmYwAP...

# 通過公共 Gateway 訪問
curl https://ipfs.io/ipfs/QmYwAP...
```

---

## 📚 最佳實踐

### 1. 文件命名

使用描述性文件名：
```
refund_request_123_proof_1.jpg
trip_456_completion_photo.png
vehicle_789_insurance.pdf
```

### 2. 元數據管理

在數據庫中保存完整元數據：
```json
{
  "cid": "QmYwAP...",
  "filename": "refund_proof.jpg",
  "content_type": "image/jpeg",
  "size": 123456,
  "hash": "sha256...",
  "uploaded_by": 123,
  "uploaded_at": "2025-10-26T12:00:00",
  "purpose": "refund_evidence",
  "related_id": 456
}
```

### 3. 定期備份

```bash
# 導出固定列表
ipfs pin ls > pinned_files.txt

# 備份 IPFS 倉庫
tar -czf ipfs_backup.tar.gz ~/.ipfs
```

### 4. 垃圾回收

定期清理未固定的文件：
```bash
# 運行垃圾回收
ipfs repo gc

# 查看倉庫統計
ipfs repo stat
```

---

## 🔗 參考資源

- [IPFS 官方文檔](https://docs.ipfs.io/)
- [IPFS HTTP API 參考](https://docs.ipfs.io/reference/http/api/)
- [Pinata 文檔](https://docs.pinata.cloud/)
- [Fleek 文檔](https://docs.fleek.co/)

---

**文檔維護者**: SUI Autonomous DApp Builder
**最後更新**: 2025-10-26
**版本**: v1.0
