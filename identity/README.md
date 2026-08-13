# DID + ZKP Identity System

去中心化身份標識符（DID）+ 零知識證明（ZKP）身份驗證系統

## 📚 目錄結構

```
identity/
├── did/                      # DID 模組
│   ├── creator.ts            # DID 創建器
│   └── resolver.ts           # DID 解析器
├── vc/                       # Verifiable Credentials 模組
│   ├── issuer.ts            # VC 簽發器（待實現）
│   ├── holder.ts            # VC 持有者（待實現）
│   └── verifier.ts          # VC 驗證器（待實現）
└── zkp/                      # Zero-Knowledge Proofs 模組
    ├── circuits/             # Circom 電路
    │   └── age_credential_proof.circom  # 年齡驗證電路（待實現）
    └── provers/              # 證明生成器
        └── age_prover.ts     # 年齡證明生成器（待實現）
```

## 🔐 DID (Decentralized Identifier)

### DID 格式
```
did:sui:<address>
```

例如：`did:sui:0x1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p7q8r9s0t1u2v3w4x5y6z7a8b9c0d`

### 特點
- 符合 W3C DID Core 1.0 標準
- 使用 Ed25519 簽名算法
- 鏈上存儲 DID 文檔
- 支持 DID 更新和停用

### 使用示例

#### 創建 DID
```typescript
import { DIDCreator } from './did/creator';

// 創建新 DID
const result = await DIDCreator.create();
console.log('DID:', result.did);
console.log('地址:', result.address);
console.log('DID 文檔:', result.didDocument);

// 重要：私鑰需要安全存儲
console.warn('私鑰:', result.privateKey);
```

#### 解析 DID
```typescript
import { DIDResolver } from './did/resolver';

const resolver = new DIDResolver({
  rpcUrl: 'https://fullnode.testnet.sui.io:443',
  packageId: '0x...',  // DID Registry 包 ID
  registryObjectId: '0x...'  // DID Registry 對象 ID
});

// 解析 DID
const result = await resolver.resolve('did:sui:0x...');

if (result.didDocument) {
  console.log('DID 文檔:', result.didDocument);
} else {
  console.error('錯誤:', result.didResolutionMetadata.message);
}
```

## 📜 智能合約（Sui Move）

### 1. DID Registry (`contracts/sources/identity/did_registry.move`)

**功能**:
- 註冊新的 DID
- 更新 DID 文檔
- 停用 DID
- 解析 DID（查詢）

**關鍵函數**:
```move
// 註冊 DID
public entry fun register_did(
    registry: &mut DIDRegistry,
    did: String,
    verification_methods: String,
    authentication: String,
    assertion_method: String,
    clock: &Clock,
    ctx: &mut TxContext
)

// 更新 DID
public entry fun update_did(
    registry: &mut DIDRegistry,
    did: String,
    verification_methods: String,
    authentication: String,
    assertion_method: String,
    clock: &Clock,
    ctx: &mut TxContext
)

// 解析 DID
public fun resolve_did(
    registry: &DIDRegistry,
    did: String
): (String, address, String, String, String, u64, u64, bool)
```

### 2. Trusted Issuers Registry (`contracts/sources/identity/trusted_issuers.move`)

**功能**:
- 管理受信任的憑證簽發者
- 只有管理員可以添加/撤銷簽發者
- 驗證簽發者是否受信任

**關鍵函數**:
```move
// 添加簽發者
public entry fun add_issuer(
    registry: &mut TrustedIssuersRegistry,
    issuer_did: String,
    name: String,
    credential_types: String,
    issuer_address: address,
    clock: &Clock,
    ctx: &mut TxContext
)

// 撤銷簽發者
public entry fun revoke_issuer(
    registry: &mut TrustedIssuersRegistry,
    issuer_did: String,
    clock: &Clock,
    ctx: &mut TxContext
)

// 檢查簽發者是否受信任
public fun is_trusted_issuer(
    registry: &TrustedIssuersRegistry,
    issuer_did: String
): bool
```

### 3. Credential Verifier (`contracts/sources/identity/credential_verifier.move`)

**功能**:
- 驗證 ZKP 證明
- 防止憑證重複使用（commitment 機制）
- 記錄用戶已驗證的憑證

**關鍵函數**:
```move
// 驗證年齡憑證
public entry fun verify_age_credential(
    registry: &mut CredentialRegistry,
    did_registry: &DIDRegistry,
    trusted_issuers: &TrustedIssuersRegistry,
    vk: &VerificationKey,
    user_did: String,
    issuer_did: String,
    proof: vector<u8>,
    public_signals: vector<u64>,
    commitment: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext
)

// 驗證駕照憑證
public entry fun verify_license_credential(...)

// 檢查用戶是否已驗證特定憑證
public fun has_credential(
    registry: &CredentialRegistry,
    user_did: String,
    credential_type: u64
): bool
```

## 🔒 Zero-Knowledge Proofs

### 年齡驗證 ZKP

**目標**: 證明用戶年齡 ≥ 18 歲，而不揭露實際出生日期

**公開輸入**:
- `currentDate`: 當前日期（YYYYMMDD）
- `minAge`: 最小年齡（例如：18）
- `issuerPublicKey`: 簽發者公鑰

**私密輸入**:
- `birthDate`: 用戶生日（YYYYMMDD）
- `issuerSignature`: 簽發者簽名

**公開輸出**:
- `isValid`: 是否滿足年齡要求（0 或 1）
- `didCommitment`: DID 承諾值（防止重複使用）

### 駕照驗證 ZKP

**目標**: 證明用戶持有有效駕照，而不揭露駕照號碼

**公開輸入**:
- `currentDate`: 當前日期
- `issuerPublicKey`: 簽發者公鑰（交通部）

**私密輸入**:
- `licenseNumber`: 駕照號碼
- `expiryDate`: 到期日
- `issuerSignature`: 簽發者簽名

**公開輸出**:
- `isValid`: 駕照是否有效（0 或 1）
- `licenseCommitment`: 駕照承諾值

## 🚀 實現流程

### 階段 1：DID 基礎設施（已完成）

1. ✅ 創建 DID 文件結構
2. ✅ 實現 DID 創建器（`identity/did/creator.ts`）
3. ✅ 實現 DID 解析器（`identity/did/resolver.ts`）
4. 🔄 **進行中**：部署 DID Registry 智能合約
   - ✅ `did_registry.move` - DID 註冊表
   - ✅ `trusted_issuers.move` - 受信任簽發者
   - ✅ `credential_verifier.move` - 憑證驗證器
   - ⏳ 編譯和部署合約

### 階段 2：VC 簽發和驗證（待實現）

1. ⏳ 實現 VC 簽發器（`identity/vc/issuer.ts`）
2. ⏳ 實現 VC 持有者（`identity/vc/holder.ts`）
3. ⏳ 實現 VC 驗證器（`identity/vc/verifier.ts`）

### 階段 3：ZKP 電路和證明生成（待實現）

1. ⏳ 創建年齡驗證電路（`identity/zkp/circuits/age_credential_proof.circom`）
2. ⏳ 創建年齡證明生成器（`identity/zkp/provers/age_prover.ts`）
3. ⏳ 設置 Circom 開發環境
4. ⏳ 執行 Powers of Tau ceremony
5. ⏳ 生成驗證密鑰

### 階段 4：完整流程測試（待實現）

1. ⏳ 端到端測試
2. ⏳ 移動應用集成
3. ⏳ 智能合約驗證測試

## 📖 使用場景

### 場景 1：用戶註冊（年齡驗證）

```typescript
// 1. 用戶創建 DID
const { did, privateKey } = await DIDCreator.create();

// 2. 用戶線下到政府機關獲取年齡憑證（VC）
//    政府機關簽發 VC：{ birthDate: "19900101", issuer: "did:sui:gov" }

// 3. 用戶在本地生成 ZKP 證明
const ageProof = await generateAgeProof({
  vc: idVC,
  currentDate: new Date(),
  minAge: 18
});

// 4. 用戶提交 DID + ZKP 到平台
await platform.register({
  did: did,
  ageProof: ageProof.proof,
  publicSignals: ageProof.publicSignals,
  commitment: ageProof.commitment
});

// 5. 平台在智能合約上驗證 ZKP
// ✅ 平台只知道：「這個 DID 的用戶年齡 >= 18」
// ❌ 平台不知道：實際出生日期
```

### 場景 2：司機註冊（駕照驗證）

```typescript
// 1. 司機已有 DID
const did = "did:sui:0x...";

// 2. 司機線下到交通部獲取駕照憑證
//    交通部簽發 VC：{ licenseNumber: "ABC123", expiryDate: "20251231", issuer: "did:sui:transport" }

// 3. 司機生成駕照 ZKP
const licenseProof = await generateLicenseProof({
  vc: licenseVC,
  currentDate: new Date()
});

// 4. 司機提交證明
await platform.verifyDriverLicense({
  did: did,
  licenseProof: licenseProof.proof,
  publicSignals: licenseProof.publicSignals,
  commitment: licenseProof.commitment
});

// ✅ 平台只知道：「這個司機有有效駕照」
// ❌ 平台不知道：駕照號碼、到期日
```

## 🔍 隱私保護原理

### 傳統 KYC vs DID + ZKP

| 項目 | 傳統 KYC | DID + ZKP |
|------|---------|-----------|
| 數據存儲 | 平台存儲完整個人信息 | 平台只存儲 DID 和證明 |
| 隱私風險 | 數據洩露暴露所有信息 | 洩露只有 DID，無個人信息 |
| 驗證方式 | 平台檢查原始數據 | 智能合約驗證 ZKP |
| 可撤銷性 | 難以刪除已洩露數據 | 停用 DID 即可 |
| 符合 GDPR | ❌ 數據最小化困難 | ✅ 天然符合數據最小化 |

### 關鍵技術

1. **承諾值（Commitment）**:
   - 防止同一憑證被多次使用
   - 無法從承諾值反推原始數據
   - 格式：`SHA256(birthDate || salt || DID)`

2. **ZKP 證明**:
   - 使用 Groth16 證明系統
   - 證明大小：~200 bytes
   - 驗證時間：<10ms

3. **受信任簽發者**:
   - 政府機關、交通部等官方機構
   - 由平台管理員添加
   - 可撤銷簽發者權限

## 🔧 部署指南

### 1. 編譯智能合約

```bash
cd /Users/hsuanliu/autodrive_platform/contracts
sui move build
```

### 2. 部署合約

```bash
sui client publish --gas-budget 100000000
```

### 3. 初始化註冊表

```bash
# 記錄 Package ID 和 Registry Object IDs
export PACKAGE_ID="0x..."
export DID_REGISTRY_ID="0x..."
export TRUSTED_ISSUERS_ID="0x..."
export CREDENTIAL_REGISTRY_ID="0x..."
```

### 4. 添加受信任簽發者

```bash
sui client call \
  --package $PACKAGE_ID \
  --module trusted_issuers \
  --function add_issuer \
  --args $TRUSTED_ISSUERS_ID "did:sui:0xgov" "Government" '["AgeCredential"]' 0xgov 0x6
```

## 📊 系統優勢

### 隱私保護
- ✅ 用戶控制自己的數據
- ✅ 平台無法獲取原始個人信息
- ✅ 鏈上數據無法追溯到個人
- ✅ 符合 GDPR 和 CCPA

### 安全性
- ✅ 密碼學驗證，無法偽造
- ✅ 承諾值防止重複使用
- ✅ 受信任簽發者機制
- ✅ 智能合約不可篡改

### 用戶體驗
- ✅ 一次驗證，多處使用
- ✅ 無需重複提交個人信息
- ✅ 快速驗證（<10ms）
- ✅ 隨時可撤銷

### 合規性
- ✅ 數據最小化原則
- ✅ 用戶同意機制
- ✅ 數據可攜帶性
- ✅ 被遺忘權

## 📚 參考資料

- [W3C DID Core 1.0](https://www.w3.org/TR/did-core/)
- [W3C Verifiable Credentials Data Model](https://www.w3.org/TR/vc-data-model/)
- [Circom Documentation](https://docs.circom.io/)
- [Sui Move Documentation](https://docs.sui.io/move)
- [Groth16 Paper](https://eprint.iacr.org/2016/260.pdf)

## 🐛 已知限制

1. **Groth16 驗證**:
   - Sui Move 不原生支持配對運算
   - 當前實現為簡化版本
   - 實際部署需要鏈下驗證或預編譯合約

2. **DID 格式驗證**:
   - 鏈上驗證較為簡單
   - 需要完善地址匹配檢查

3. **憑證撤銷**:
   - 當前未實現憑證撤銷列表
   - 建議在階段 2 實現

## 📝 TODOs

- [ ] 完成 ZKP 電路實現
- [ ] 實現 VC 簽發和驗證邏輯
- [ ] 完善 Groth16 驗證（鏈下或預編譯）
- [ ] 添加憑證撤銷機制
- [ ] 移動端集成
- [ ] 性能優化和安全審計
