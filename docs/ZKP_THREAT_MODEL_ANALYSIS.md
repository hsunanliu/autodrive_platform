# AutoDrive 隱私威脅模型分析與 DID+ZKP 方案

## 核心問題：為什麼需要保護隱私？

你的質疑非常正確：**如果自駕車不知道用戶的具體位置，怎麼接送客人？**

答案是：**不是「不讓司機知道」，而是「不讓不該知道的人知道」**

---

## 一、威脅模型分析（P0-P2）

### 威脅分類

| 威脅來源 | 動機 | 能力 | 風險等級 |
|---------|------|------|---------|
| **平台管理員** | 數據販賣、內部腐敗 | 完全訪問數據庫 | 🔴 高 |
| **黑客** | 勒索、身份盜竊 | 數據庫入侵 | 🔴 高 |
| **配對司機/乘客** | 跟蹤、騷擾 | 看到對方實時位置 | 🟡 中 |
| **政府監控** | 追蹤異議人士 | 法律強制 | 🟡 中 |
| **競爭對手** | 商業間諜 | 公開鏈上數據分析 | 🟢 低 |
| **廣告商** | 精準投放 | 購買數據 | 🟢 低 |

---

## 二、場景分析（P0-P2）

### P0-1: 位置隱私 ⭐⭐⭐⭐⭐

#### ❓ 問題：為什麼需要保護位置？

**你的質疑**：司機不知道位置怎麼接客人？

**答案**：不是讓司機不知道，而是：

| 誰 | 需要知道什麼 | 當前狀況 | 應該怎樣 |
|----|------------|---------|---------|
| **配對司機** | 上車點精確位置 | ✅ 知道（必要） | ✅ 知道（必要） |
| **其他司機** | 無關 | ❌ 不知道 | ✅ 不知道 |
| **平台後端** | 區域即可（匹配用） | ❌ 記錄完整坐標 | ✅ 只記錄 Geohash |
| **區塊鏈** | 無需知道 | ❌ 哈希但可暴力破解 | ✅ ZKP 證明到達 |
| **未來的平台** | 無關 | ❌ 永久存儲 | ✅ 行程結束後刪除 |

#### 🎯 威脅場景 1: 平台數據洩露

**真實案例**：
- 2022 年 Uber 數據洩露：5700 萬用戶行程記錄外洩
- 可推斷用戶住址、工作地點、醫院就診記錄

**當前系統風險**：
```sql
-- 黑客入侵後可執行
SELECT user_id, pickup_address, pickup_lat, pickup_lng, requested_at
FROM trips
WHERE user_id = 12345
ORDER BY requested_at;

-- 結果：
-- 每天早上 8:30 從「台北市大安區復興南路一段 100 號」出發
-- → 推斷出用戶住址
-- 每天晚上 18:00 到「台北市信義區松仁路 100 號」
-- → 推斷出用戶公司

-- 週末到「台北市萬華區」
-- → 推斷娛樂習慣

-- 頻繁到「台大醫院」
-- → 推斷健康狀況
```

**影響**：
- 個人安全：被跟蹤、入室盜竊（知道何時不在家）
- 保險歧視：健康記錄被保險公司獲取
- 社會工程：針對性詐騙（"我知道你住哪"）

#### 🎯 威脅場景 2: 司機騷擾乘客

**問題**：配對後，司機知道乘客住址（上車點通常是家）

**當前系統**：
```javascript
// WebSocket 廣播（mobile/lib/services/websocket_service.dart）
_socket.emit('update_location', {
  'trip_id': tripId,
  'lat': 25.033964,  // 精確到 11 公分
  'lng': 121.565171,
});

// 乘客收到司機實時位置 → 合理
// 但行程結束後，雙方仍可查歷史記錄 → 不合理
```

**真實風險**：
- 司機記住乘客住址，後續騷擾
- 乘客給低評分後遭報復（司機知道住哪）

**解決方案不是 ZKP**（司機確實需要知道），而是：
1. **行程結束後模糊化位置**（保留區域，刪除精確坐標）
2. **雙向匿名**（只顯示「大安區」而非完整地址）
3. **臨時 ID**（行程中使用一次性 ID，結束後解綁）

#### 🎯 威脅場景 3: 鏈上位置追蹤

**當前合約**：
```move
// contracts/sources/business/trip_receipt.move
public struct TripReceipt {
    pickup_hash: vector<u8>,   // SHA256("25.033964,121.565171")
    dropoff_hash: vector<u8>,
}
```

**問題**：哈希可暴力破解（台北市只有幾萬個坐標點）

```python
# 攻擊者可以這樣做
import hashlib

taipei_coords = generate_all_taipei_coordinates()  # ~50,000 個
for coord in taipei_coords:
    hash = hashlib.sha256(f"{coord[0]},{coord[1]}".encode()).digest()
    if hash == pickup_hash:
        print(f"找到了！用戶從 {coord} 上車")
```

**影響**：
- 所有歷史行程位置可被還原
- 無法真正匿名

**ZKP 方案**：
```circom
// 不存哈希，而是證明「我到了上車點」
template ArrivalProof() {
    signal input actual_lat;      // 私密
    signal input actual_lng;
    signal input target_lat;      // 公開（粗略區域）
    signal input max_distance_m;  // 100 米

    signal output arrived;  // 布爾值
    // ... 計算距離
}

// 鏈上只記錄：
// arrived: true（司機確實到了）
// 但不記錄具體坐標
```

#### ✅ 平衡方案：分層隱私

| 階段 | 誰知道 | 精度 | 存儲位置 | 保留時間 |
|------|-------|------|---------|---------|
| **匹配階段** | 附近司機 | 區域（Geohash 6） | 內存（Redis） | 10 分鐘 |
| **配對後** | 配對司機 | 精確坐標 | 加密內存 | 行程期間 |
| **行程中** | 雙方 | 實時位置 | 臨時存儲 | 行程期間 |
| **行程結束** | 無人 | - | ❌ 刪除 | - |
| **爭議處理** | 仲裁者 | 區域 | 加密備份 | 30 天後刪除 |
| **鏈上記錄** | 公開 | ZKP 證明 | 永久 | 永久 |

**關鍵改進**：
1. ✅ 司機仍然能接客（配對後知道精確位置）
2. ✅ 平台無法長期追蹤（數據定期刪除）
3. ✅ 鏈上無法還原（ZKP 而非哈希）
4. ✅ 保留爭議處理能力（加密備份 30 天）

---

### P0-2: 支付隱私 ⭐⭐⭐⭐

#### ❓ 問題：為什麼需要保護支付金額？

**你的質疑**：司機不知道能賺多少錢，怎麼接單？

**答案**：司機需要知道，但**不需要讓全世界都知道**

#### 當前問題：鏈上完全透明

```move
// contracts/sources/financial/payment_escrow.move
public struct Escrow {
    passenger: 0x1a2b3c4d...,     // 🔴 公開
    driver: 0x5e6f7g8h...,        // 🔴 公開
    total_amount: 250000000000,   // 🔴 公開：250 SUI = $500
    platform_fee: 25000000000,    // 🔴 公開：平台抽 10%
}
```

**任何人都可以查詢**：
```bash
# 區塊鏈瀏覽器
$ curl https://explorer.sui.io/address/0x1a2b3c4d...

{
  "total_spent": 125000 SUI,  # 總支出 $250,000
  "avg_trip": 250 SUI,        # 平均每次 $500
  "frequency": "每天 2 次",
  "pattern": "早晚高峰"
}
```

#### 🎯 威脅場景 1: 財富推斷

**攻擊者分析**：
```python
# 找出高消費用戶
high_spenders = query_blockchain(
    "SELECT address, SUM(amount) FROM escrows GROUP BY address HAVING SUM(amount) > 10000"
)

# 結果：0x1a2b... 已花費 125,000 SUI
# → 推斷：高淨值用戶
# → 針對性詐騙、綁架威脅
```

**真實案例**：
- 2021 年 DeFi 用戶因鏈上暴露大額交易被綁架
- 攻擊者通過地址關聯追蹤到真實身份

#### 🎯 威脅場景 2: 商業間諜

**競爭對手可以**：
```python
# 分析司機收入
driver_earnings = analyze_driver_income("0x5e6f...")
# → 某司機月入 50,000 SUI = $100,000
# → 挖角策略

# 分析平台總交易量
platform_revenue = sum_all_platform_fees()
# → 推斷平台市值、用戶規模
```

#### ✅ 平衡方案：選擇性公開

| 對象 | 需要知道 | 實現方式 |
|------|---------|---------|
| **配對司機** | 確切金額 | ✅ 鏈下加密通訊（司機簽名後解密） |
| **平台** | 確切金額（結算用） | ✅ 後端數據庫（加密存儲） |
| **智能合約** | 範圍即可 | ✅ Bulletproofs 範圍證明 |
| **公眾** | 無需知道 | ✅ 只看到「支付已完成」 |
| **審計者** | 總量統計 | ✅ 聚合數據（無個人信息） |

**技術方案**：
```move
// 新的私密託管合約
public struct PrivateEscrow {
    trip_id: u64,                    // 公開
    amount_commitment: vector<u8>,   // Pedersen 承諾
    range_bucket: u8,                // 範圍：0=<$50, 1=$50-100, ...
    range_proof: vector<u8>,         // Bulletproof

    // 實際金額只在鏈下傳遞
    // 司機通過簽名解密獲得確切金額
}

// 司機解密流程（鏈下）
// 1. 平台用司機公鑰加密：encrypted_amount = encrypt(250 SUI, driver_pubkey)
// 2. 司機本地解密：actual_amount = decrypt(encrypted_amount, driver_privkey)
// 3. 鏈上只記錄範圍：range_bucket = 3 ($200-500)
```

**結果**：
- ✅ 司機知道能賺 250 SUI（鏈下解密）
- ✅ 公眾只知道「$200-500 範圍」
- ✅ 無法精確追蹤消費習慣

---

### P1-1: 身份隱私（年齡、駕照）⭐⭐⭐⭐⭐

**這是最適合 DID + ZKP 的場景！**

#### ❓ 問題：為什麼不能直接上傳身份證？

**當前 KYC 問題**：
```
用戶上傳：
- 身份證正反面照片
- 姓名：劉小明
- 身份證號：A123456789
- 生日：1990-05-15
- 地址：台北市大安區...
- 駕照號碼：12-345678
- 發照日期：2020-03-10

平台存儲：所有信息明文存數據庫
```

**風險**：
1. **數據洩露**：黑客入侵 → 完整身份信息外洩
2. **過度收集**：平台只需驗證「年滿 18 歲」，不需要知道具體生日
3. **無法撤銷**：身份證號碼一輩子不變，洩露後無法更改
4. **中心化信任**：必須信任平台不會濫用

#### ✅ DID + ZKP 方案

**核心理念**：用戶控制自己的身份，選擇性披露

```
┌─────────────────────────────────────────────────────────────────┐
│                    DID + ZKP 身份系統架構                          │
└─────────────────────────────────────────────────────────────────┘

[用戶錢包]
    │
    ├─ DID: did:sui:0x1a2b3c4d5e6f...
    │   └─ 控制私鑰（用戶自持）
    │
    ├─ 可驗證憑證 (Verifiable Credentials)
    │   ├─ 政府簽發：身份證 VC
    │   │   - 簽發者：內政部 DID
    │   │   - 聲明：持有者年滿 18 歲
    │   │   - 簽名：政府私鑰
    │   │
    │   ├─ 監理站簽發：駕照 VC
    │   │   - 簽發者：監理站 DID
    │   │   - 聲明：持有 B 類駕照，駕齡 ≥ 2 年
    │   │   - 簽名：監理站私鑰
    │   │
    │   └─ 平台簽發：信譽 VC
    │       - 簽發者：AutoDrive DID
    │       - 聲明：信譽分數 87 分
    │       - 簽名：平台私鑰
    │
    └─ ZKP 生成器
        └─ 根據 VC 生成零知識證明

[AutoDrive 平台]
    │
    ├─ 不存儲身份證信息
    ├─ 只存儲 DID
    └─ 驗證 ZKP 證明

[智能合約]
    │
    ├─ DID Registry（鏈上）
    │   - did:sui:0x1a2b... → {publicKey, serviceEndpoint}
    │
    └─ ZKP Verifier
        - 驗證年齡證明
        - 驗證駕照證明
```

#### 實施細節

**1. 用戶註冊流程**

```typescript
// 傳統方式（不好）
async function registerTraditional() {
  // ❌ 上傳身份證照片
  await uploadIDCard("id_front.jpg", "id_back.jpg");

  // ❌ 平台存儲所有信息
  await platform.saveUser({
    name: "劉小明",
    idNumber: "A123456789",
    birthDate: "1990-05-15",
    address: "台北市...",
  });
}

// DID + ZKP 方式（好）
async function registerWithDID() {
  // 1. 創建 DID
  const did = await createDID();
  // did:sui:0x1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p

  // 2. 獲取政府簽發的可驗證憑證（線下一次性）
  const idVC = await getGovernmentVC({
    did: did,
    idNumber: "A123456789",  // 只在政府系統驗證，不給平台
  });
  // VC 內容：
  // {
  //   "@context": "https://www.w3.org/2018/credentials/v1",
  //   "type": ["VerifiableCredential", "AgeCredential"],
  //   "issuer": "did:gov:moi",  // 內政部
  //   "issuanceDate": "2025-01-27T00:00:00Z",
  //   "credentialSubject": {
  //     "id": "did:sui:0x1a2b...",
  //     "birthDate": "1990-05-15",  // 加密存儲在用戶錢包
  //     "ageOver18": true
  //   },
  //   "proof": {
  //     "type": "Ed25519Signature2020",
  //     "created": "2025-01-27T00:00:00Z",
  //     "verificationMethod": "did:gov:moi#key-1",
  //     "proofValue": "z3F4h8..."  // 政府簽名
  //   }
  // }

  // 3. 用戶在本地生成 ZKP 證明（不洩露生日）
  const ageProof = await generateAgeProof(idVC, {
    claim: "ageOver18",
    currentDate: new Date()
  });

  // 4. 提交到平台（只有證明，沒有生日）
  await platform.register({
    did: did,
    ageProof: ageProof,  // 只有證明
    // ❌ 沒有 birthDate
    // ❌ 沒有 idNumber
    // ❌ 沒有 name
  });

  // 5. 平台驗證證明
  const verified = await verifyAgeProof(ageProof, {
    issuerDID: "did:gov:moi",  // 信任政府簽發的 VC
    minAge: 18
  });

  if (verified) {
    // ✅ 用戶通過驗證
    // ✅ 平台只知道「年滿 18 歲」
    // ✅ 平台不知道具體生日
  }
}
```

**2. 司機駕照驗證**

```typescript
async function verifyDriverLicense() {
  // 1. 獲取監理站簽發的駕照 VC
  const licenseVC = await getDMVCredential({
    did: userDID,
    licenseNumber: "12-345678",  // 只在監理站驗證
  });
  // VC 聲明：
  // - licenseType: "B"（普通小客車）
  // - issueDate: "2020-03-10"
  // - expiryDate: "2030-03-10"

  // 2. 生成駕照有效性證明
  const licenseProof = await generateLicenseProof(licenseVC, {
    claims: [
      { type: "licenseType", value: "B" },  // 公開聲明
      { type: "validUntil", operator: ">", value: new Date() },
      { type: "drivingYears", operator: ">=", value: 2 }
    ]
  });

  // 3. 提交證明
  await platform.verifyDriver({
    did: userDID,
    licenseProof: licenseProof,
    // ❌ 沒有 licenseNumber
    // ❌ 沒有 issueDate（只證明駕齡 ≥ 2 年）
  });
}
```

**3. Circom 電路**

```circom
// zkp/circuits/age_credential_proof.circom
pragma circom 2.0.0;

include "circomlib/poseidon.circom";
include "circomlib/comparators.circom";
include "circomlib/eddsaposeidon.circom";  // 驗證政府簽名

template AgeCredentialProof() {
    // === 私密輸入 ===
    signal input birthDate;         // 1990-05-15（時間戳）
    signal input credentialHash;    // VC 的哈希
    signal input issuerSignature[2]; // 政府簽名（R, S）

    // === 公開輸入 ===
    signal input issuerPublicKey[2]; // 政府公鑰
    signal input currentDate;        // 2025-01-27
    signal input minAge;             // 18

    // === 公開輸出 ===
    signal output isValid;           // 是否有效
    signal output didCommitment;     // DID 承諾（防止重複註冊）

    // 1. 驗證政府簽名
    component sigVerifier = EdDSAPoseidonVerifier();
    sigVerifier.enabled <== 1;
    sigVerifier.Ax <== issuerPublicKey[0];
    sigVerifier.Ay <== issuerPublicKey[1];
    sigVerifier.R8x <== issuerSignature[0];
    sigVerifier.R8y <== issuerSignature[1];
    sigVerifier.S <== issuerSignature[2];
    sigVerifier.M <== credentialHash;
    // 如果簽名無效，電路會失敗

    // 2. 計算年齡
    signal ageSeconds;
    ageSeconds <== currentDate - birthDate;

    signal ageYears;
    ageYears <== ageSeconds / (365 * 24 * 60 * 60);

    // 3. 檢查是否成年
    component cmp = GreaterEqThan(7);
    cmp.in[0] <== ageYears;
    cmp.in[1] <== minAge;
    isValid <== cmp.out;

    // 4. 生成 DID 承諾（防止同一身份多次註冊）
    component hasher = Poseidon(2);
    hasher.inputs[0] <== birthDate;
    hasher.inputs[1] <== credentialHash;
    didCommitment <== hasher.out;
}

component main {public [issuerPublicKey, currentDate, minAge]} = AgeCredentialProof();
```

**4. 智能合約**

```move
// contracts/sources/identity/did_registry.move
module autodrive::did_registry {
    use sui::object::{Self, UID};
    use sui::table::{Self, Table};
    use std::string::String;

    // DID 文檔
    struct DIDDocument has key, store {
        id: UID,
        did: String,  // "did:sui:0x1a2b..."
        controller: address,  // 控制者（用戶錢包）
        public_key: vector<u8>,
        service_endpoints: vector<String>,
        created_at: u64,
        updated_at: u64,
    }

    // 可驗證憑證註冊表（記錄承諾，防止重複使用）
    struct CredentialRegistry has key {
        id: UID,
        used_commitments: Table<vector<u8>, bool>,  // commitment → used?
    }

    // 信任的簽發者列表
    struct TrustedIssuers has key {
        id: UID,
        issuers: Table<String, vector<u8>>,  // issuerDID → publicKey
        // 例如：
        // "did:gov:moi" → 0x1234...（內政部公鑰）
        // "did:gov:dmv" → 0x5678...（監理站公鑰）
    }

    // 註冊用戶（使用 ZKP 年齡證明）
    public fun register_user_with_age_proof(
        did: String,
        age_proof: vector<u8>,
        age_public_signals: vector<u64>,  // [isValid, didCommitment]
        issuer_did: String,
        registry: &mut CredentialRegistry,
        trusted_issuers: &TrustedIssuers,
        age_vk: &groth16::VerificationKey,
        ctx: &mut TxContext
    ): DIDDocument {
        let sender = tx_context::sender(ctx);

        // 1. 檢查簽發者是否受信任
        assert!(
            table::contains(&trusted_issuers.issuers, issuer_did),
            EUntrustedIssuer
        );

        // 2. 驗證 ZKP 證明
        assert!(
            groth16::verify(age_vk, &age_proof, &age_public_signals),
            EInvalidAgeProof
        );

        // 3. 檢查 isValid == 1（年齡符合）
        assert!(age_public_signals[0] == 1, EAgeNotMet);

        // 4. 防止憑證重複使用
        let commitment = encode_u64_to_bytes(age_public_signals[1]);
        assert!(
            !table::contains(&registry.used_commitments, commitment),
            ECredentialAlreadyUsed
        );
        table::add(&mut registry.used_commitments, commitment, true);

        // 5. 創建 DID 文檔
        DIDDocument {
            id: object::new(ctx),
            did: did,
            controller: sender,
            public_key: vector::empty(),  // 從 DID 解析
            service_endpoints: vector::empty(),
            created_at: tx_context::epoch(ctx),
            updated_at: tx_context::epoch(ctx),
        }
    }

    // 驗證司機駕照
    public fun verify_driver_license(
        did_doc: &DIDDocument,
        license_proof: vector<u8>,
        license_public_signals: vector<u64>,  // [isValid, hasExp, licenseCommitment]
        issuer_did: String,
        registry: &mut CredentialRegistry,
        trusted_issuers: &TrustedIssuers,
        license_vk: &groth16::VerificationKey,
    ): bool {
        // 1. 驗證簽發者（監理站）
        assert!(table::contains(&trusted_issuers.issuers, issuer_did), 0);

        // 2. 驗證證明
        assert!(groth16::verify(license_vk, &license_proof, &license_public_signals), 0);

        // 3. 檢查駕照有效 && 駕齡足夠
        let is_valid = license_public_signals[0] == 1;
        let has_experience = license_public_signals[1] == 1;

        // 4. 記錄承諾
        let commitment = encode_u64_to_bytes(license_public_signals[2]);
        assert!(!table::contains(&registry.used_commitments, commitment), 0);
        table::add(&mut registry.used_commitments, commitment, true);

        is_valid && has_experience
    }
}
```

---

### P1-2: 評分系統 ⭐⭐⭐

#### ❓ 為什麼需要保護信譽分數？

**問題**：分數公開可能導致歧視

**場景**：
```
司機 A：信譽 95 分
司機 B：信譽 70 分

乘客：只願意選 95 分司機
→ 司機 B 永遠接不到單
→ 形成馬太效應
```

#### ✅ 解決方案：閾值證明

**不公開具體分數，只證明「達標」**：

```typescript
// 司機設置接單條件
driver.setPreference({
  minPassengerReputation: 80  // 只接受 ≥ 80 分乘客
});

// 乘客生成證明
const proof = await passenger.generateReputationProof({
  actualScore: 87,  // 私密
  threshold: 80     // 公開
});

// 司機驗證
if (verifyProof(proof)) {
  // ✅ 知道乘客 ≥ 80 分
  // ❌ 不知道是 87 還是 95
  acceptRide();
}
```

**結合 DID**：
```move
// 平台簽發信譽 VC
struct ReputationCredential {
    issuer: "did:platform:autodrive",
    subject: "did:sui:0x1a2b...",
    claim: {
        reputationScore: 87,  // 加密，只在用戶錢包
        updatedAt: "2025-01-27"
    },
    proof: {
        type: "Ed25519Signature2020",
        signature: "0xabcd..."  // 平台簽名
    }
}

// 用戶生成閾值證明
// 電路驗證：
// 1. 平台簽名有效
// 2. actualScore >= threshold
// 輸出：meetsThreshold = true
```

---

### P2: 行程模式 ⭐⭐

**為什麼保護**：防止推斷生活習慣

**威脅**：
```sql
-- 分析用戶行為
SELECT
    EXTRACT(HOUR FROM requested_at) as hour,
    COUNT(*) as trips
FROM trips
WHERE user_id = 12345
GROUP BY hour;

-- 結果：
-- 08:00-09:00: 200 次（通勤）
-- 18:00-19:00: 180 次（下班）
-- 23:00-00:00: 50 次（夜生活）

→ 可推斷作息時間、娛樂習慣
```

**解決方案**：
1. **聚合統計**（不公開個人數據）
2. **差分隱私**（添加噪聲）
3. **行程結束後刪除時間戳**（只保留日期）

---

## 三、DID + ZKP 核心架構

### 系統設計

```
┌──────────────────────────────────────────────────────────────────┐
│                  AutoDrive DID + ZKP 身份系統                      │
└──────────────────────────────────────────────────────────────────┘

[Layer 1: DID 層（身份標識）]
    │
    ├─ 用戶 DID：did:sui:0x1a2b3c4d...
    │   └─ 控制：用戶私鑰（自持）
    │
    ├─ 平台 DID：did:platform:autodrive
    │   └─ 控制：平台私鑰（HSM 保護）
    │
    └─ 政府 DID：did:gov:moi, did:gov:dmv
        └─ 控制：政府私鑰（離線冷存儲）

[Layer 2: VC 層（可驗證憑證）]
    │
    ├─ 身份憑證（政府簽發）
    │   - 聲明：年滿 18 歲
    │   - 簽名：政府私鑰
    │   - 存儲：用戶錢包（加密）
    │
    ├─ 駕照憑證（監理站簽發）
    │   - 聲明：持有 B 照，駕齡 ≥ 2 年
    │   - 簽名：監理站私鑰
    │   - 存儲：用戶錢包
    │
    └─ 信譽憑證（平台簽發）
        - 聲明：信譽分數 87
        - 簽名：平台私鑰
        - 存儲：用戶錢包

[Layer 3: ZKP 層（零知識證明）]
    │
    ├─ 年齡證明電路
    │   - 輸入：birthDate（私密）+ VC 簽名
    │   - 輸出：isAdult（公開）
    │
    ├─ 駕照證明電路
    │   - 輸入：issueDate（私密）+ VC 簽名
    │   - 輸出：hasValidLicense, drivingYears >= 2
    │
    └─ 信譽證明電路
        - 輸入：actualScore（私密）
        - 輸出：meetsThreshold

[Layer 4: 智能合約層（驗證）]
    │
    ├─ DID Registry
    │   - 註冊 DID 文檔
    │   - 解析 DID → 公鑰
    │
    ├─ Trusted Issuers Registry
    │   - 信任的簽發者列表
    │   - 簽發者公鑰管理
    │
    └─ ZKP Verifiers
        - 驗證年齡證明
        - 驗證駕照證明
        - 驗證信譽證明
```

### 文件結構

```
autodrive_platform/
├── identity/
│   ├── did/
│   │   ├── resolver.ts          # DID 解析器
│   │   ├── creator.ts           # DID 創建器
│   │   └── registry.move        # 鏈上 DID 註冊表
│   │
│   ├── vc/
│   │   ├── issuer.ts            # VC 簽發器（平台用）
│   │   ├── holder.ts            # VC 持有者（用戶錢包）
│   │   ├── verifier.ts          # VC 驗證器
│   │   └─� schemas/
│   │       ├── age_credential.json
│   │       ├── license_credential.json
│   │       └── reputation_credential.json
│   │
│   └── zkp/
│       ├── circuits/
│       │   ├── age_credential_proof.circom
│       │   ├── license_credential_proof.circom
│       │   └── reputation_threshold_proof.circom
│       │
│       └── provers/
│           ├── age_prover.ts
│           └── license_prover.ts
│
├── contracts/sources/identity/
│   ├── did_registry.move
│   ├── trusted_issuers.move
│   ├── credential_registry.move  # 防止 VC 重複使用
│   └── zkp_verifiers/
│       ├── age_verifier.move
│       └── license_verifier.move
│
└── mobile/lib/identity/
    ├── did_manager.dart
    ├── vc_wallet.dart
    └── zkp_prover.dart
```

---

## 四、總結與建議

### 核心要點

1. **隱私保護不是「完全隱藏」**
   - 司機需要知道上車點 ✅
   - 但平台不需要永久記錄 ❌
   - 公眾不需要知道 ❌

2. **DID + ZKP 最適合身份場景**
   - 年齡驗證：只證明「≥18 歲」
   - 駕照驗證：只證明「有效且駕齡足夠」
   - 信譽驗證：只證明「≥ 門檻」

3. **位置和支付需要混合方案**
   - 位置：分層隱私（配對時精確，結束後模糊）
   - 支付：鏈下加密 + 鏈上範圍證明

### 優先級調整

| 場景 | 優先級 | 技術方案 | 時間 |
|------|-------|---------|------|
| **身份驗證（DID+ZKP）** | P0 | VC + Circom | 2 月 |
| **位置分層隱私** | P1 | Geohash + 定期刪除 | 2 週 |
| **支付範圍證明** | P1 | Bulletproofs | 1 月 |
| **評分閾值** | P2 | Circom | 2 週 |

### 立即行動

**階段 1：DID 基礎設施（1 個月）**
1. 實現 DID 創建和解析
2. 建立信任的簽發者註冊表
3. 部署 DID Registry 合約

**階段 2：VC + ZKP 身份驗證（2 個月）**
1. 實現年齡驗證電路和 VC
2. 實現駕照驗證電路和 VC
3. 前端整合（用戶錢包）

**階段 3：其他隱私增強（1 個月）**
1. 位置數據分層處理
2. 支付範圍證明（如果 Sui 支持）

---

**文檔版本**: v2.0
**最後更新**: 2025-01-27
**重點**: DID + ZKP 身份系統
