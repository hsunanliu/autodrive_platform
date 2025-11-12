# 🔐 ZKP 模組方案 - AutoDrive Platform

**文檔類型**: 技術方案設計
**建立日期**: 2025-10-26
**版本**: v1.0
**狀態**: 設計階段

---

## 📋 概述

本文檔設計 AutoDrive Platform 的零知識證明（Zero-Knowledge Proof, ZKP）模組，用於在不洩露隱私的情況下驗證用戶資格、行程真實性、車輛合規性等關鍵信息。

### 為什麼需要 ZKP？

在去中心化叫車平台中，我們面臨以下隱私挑戰：

1. **身份驗證**: 證明用戶年滿 18 歲，但不洩露確切年齡
2. **駕駛資格**: 證明司機持有有效駕照，但不公開駕照號碼
3. **信用評分**: 證明用戶信用分數高於閾值，但不洩露具體分數
4. **行程真實性**: 證明行程確實完成，但不公開 GPS 軌跡細節
5. **支付能力**: 證明用戶錢包餘額足夠，但不洩露確切金額

### ZKP 的優勢

✅ **隱私保護**: 驗證資格而不洩露敏感數據
✅ **最小化披露**: 只證明必要資訊（例如「年齡 ≥ 18」而非「年齡 = 25」）
✅ **去信任化**: 驗證可由任何人執行，無需信任中心化機構
✅ **不可偽造**: 密碼學保證證明的真實性
✅ **可鏈上驗證**: 智能合約可驗證 ZKP，實現完全去中心化

---

## 🎯 使用場景

### 場景 1: 年齡驗證（Age Verification）

**需求**: 乘客和司機必須年滿 18 歲才能使用平台

**傳統方案問題**:
- 上傳身份證 → 洩露姓名、地址、身份證號碼
- 中心化驗證 → 需要信任平台不會濫用數據

**ZKP 方案**:
```
Prover (用戶)     Verifier (智能合約)
     |                    |
     |  Proof: age ≥ 18   |
     |------------------->|
     |                    |
     |    ✅ Verified     |
     |<-------------------|
```

**證明內容**: "我的出生日期早於 2007-10-26"
**不洩露**: 具體出生日期、姓名、身份證號碼

---

### 場景 2: 駕照驗證（Driver License Verification）

**需求**: 司機必須持有有效駕照

**ZKP 方案**:
- **證明**: 「我持有台灣交通部簽發的駕照」+「有效期至少到 2026-01-01」
- **不洩露**: 駕照號碼、姓名、地址
- **額外好處**: 可選擇性公開「駕齡 ≥ 3 年」提高匹配優先級

---

### 場景 3: 信用評分驗證（Credit Score Verification）

**需求**: 高信用用戶享有優先匹配

**ZKP 方案**:
```solidity
// Solidity 驗證邏輯（簡化）
function verifyHighCredit(bytes calldata proof) public view returns (bool) {
    // 驗證 ZKP: credit_score >= 700
    return zkVerifier.verify(proof);
}
```

**證明**: 「我的信用分數 ≥ 700」
**不洩露**: 具體分數（可能是 702 或 850）
**應用**: 高信用用戶享有 10% 折扣

---

### 場景 4: 行程真實性驗證（Trip Completion Proof）

**需求**: 證明行程確實完成且符合預期路線

**ZKP 方案**:
- **證明**: 「車輛確實經過起點附近 50 米範圍」+「經過終點附近 50 米範圍」+「行駛時間在合理範圍內（15-45 分鐘）」
- **不洩露**: 完整 GPS 軌跡
- **防作弊**: 無法偽造證明（GPS 數據由可信硬件簽名）

---

### 場景 5: 錢包餘額驗證（Wallet Balance Proof）

**需求**: 證明用戶有足夠餘額支付行程費用

**ZKP 方案**:
```javascript
// 生成證明（客戶端）
const proof = await generateBalanceProof({
  balance: 100.5,  // 實際餘額（私密）
  threshold: 50    // 行程費用（公開）
});

// 驗證（智能合約）
assert(proof.proves("balance >= threshold"));
// ✅ 通過，但不知道具體餘額
```

---

## 🔧 技術方案

### 方案選擇矩陣

| ZKP 系統 | 證明大小 | 驗證速度 | 生成速度 | 複雜度 | 推薦場景 |
|---------|---------|---------|---------|--------|---------|
| **zk-SNARKs** | ⭐⭐⭐⭐⭐ (200B) | ⭐⭐⭐⭐⭐ (5ms) | ⭐⭐⭐ (10s) | ⭐⭐⭐⭐ | 鏈上驗證 |
| **zk-STARKs** | ⭐⭐⭐ (100KB) | ⭐⭐⭐ (50ms) | ⭐⭐⭐⭐ (2s) | ⭐⭐⭐ | 高安全需求 |
| **Bulletproofs** | ⭐⭐⭐⭐ (1KB) | ⭐⭐ (200ms) | ⭐⭐⭐⭐ (1s) | ⭐⭐ | 範圍證明 |
| **Plonk** | ⭐⭐⭐⭐ (500B) | ⭐⭐⭐⭐ (10ms) | ⭐⭐⭐⭐ (3s) | ⭐⭐⭐ | 通用證明 |

### 推薦方案: **Groth16 (zk-SNARKs)** + **SnarkJS**

**理由**:
1. ✅ **證明極小**: ~200 bytes，適合鏈上存儲
2. ✅ **驗證極快**: ~5ms，gas 成本低
3. ✅ **成熟生態**: Circom + SnarkJS 工具鏈完善
4. ✅ **Solidity 支持**: 直接生成 Solidity 驗證合約
5. ✅ **已有案例**: Tornado Cash、zkSync 等成功案例

**劣勢**:
- ⚠️ 需要可信設置（Trusted Setup）→ 可用多方計算（MPC）緩解
- ⚠️ 證明生成較慢（10秒）→ 在客戶端離線生成

---

## 🏗️ 架構設計

### Off-Chain Proof Generation + On-Chain Verification

```
┌─────────────────────────────────────────────────────────┐
│                    AutoDrive Platform                    │
└─────────────────────────────────────────────────────────┘
            │                            │
            │                            │
  ┌─────────▼─────────┐        ┌────────▼────────┐
  │   Client (前端)    │        │  Smart Contract  │
  │                    │        │   (SUI/Move)     │
  │  1. 輸入私密數據   │        │                  │
  │  2. 生成 ZKP       │        │  4. 驗證 ZKP     │
  │  3. 提交證明       │───────>│  5. 授予權限     │
  └────────────────────┘        └──────────────────┘
            │
            │
  ┌─────────▼─────────┐
  │  ZK Circuit        │
  │  (Circom)          │
  │                    │
  │  • age_check.circom│
  │  • balance.circom  │
  │  • credit.circom   │
  └────────────────────┘
```

### 核心組件

#### 1. **Circom 電路（Circuit）**

定義 ZKP 的邏輯規則：

```circom
// circuits/age_verification.circom
pragma circom 2.0.0;

include "circomlib/comparators.circom";

template AgeCheck() {
    // 私密輸入
    signal input birthYear;    // 出生年份（私密）
    signal input birthMonth;   // 出生月份（私密）
    signal input birthDay;     // 出生日（私密）

    // 公開輸入
    signal input currentYear;  // 當前年份（公開）
    signal input currentMonth; // 當前月份（公開）
    signal input currentDay;   // 當前日（公開）

    // 公開輸出
    signal output isAdult;     // 是否成年（公開）

    // 計算年齡
    signal age;
    age <== currentYear - birthYear;

    // 檢查月份和日期
    component monthCheck = LessThan(8);
    monthCheck.in[0] <== birthMonth;
    monthCheck.in[1] <== currentMonth;

    component dayCheck = LessThan(8);
    dayCheck.in[0] <== birthDay;
    dayCheck.in[1] <== currentDay;

    // 判斷是否成年（18 歲）
    component ageCheck = GreaterEqThan(8);
    ageCheck.in[0] <== age;
    ageCheck.in[1] <== 18;

    isAdult <== ageCheck.out;
}

component main = AgeCheck();
```

#### 2. **前端證明生成（SnarkJS）**

```javascript
// dashboard/src/services/zkp_service.js
import { groth16 } from 'snarkjs';

export async function generateAgeProof(birthDate) {
  const now = new Date();

  // 準備輸入
  const input = {
    birthYear: birthDate.getFullYear(),
    birthMonth: birthDate.getMonth() + 1,
    birthDay: birthDate.getDate(),
    currentYear: now.getFullYear(),
    currentMonth: now.getMonth() + 1,
    currentDay: now.getDate(),
  };

  // 加載電路文件
  const wasmFile = '/zkp/age_verification.wasm';
  const zkeyFile = '/zkp/age_verification.zkey';

  // 生成證明（約 5-10 秒）
  const { proof, publicSignals } = await groth16.fullProve(
    input,
    wasmFile,
    zkeyFile
  );

  // 格式化為合約可接受的格式
  const proofFormatted = {
    pi_a: proof.pi_a.slice(0, 2),
    pi_b: proof.pi_b.slice(0, 2).map(v => v.reverse()),
    pi_c: proof.pi_c.slice(0, 2),
    publicSignals: publicSignals,
  };

  return proofFormatted;
}
```

#### 3. **Move 智能合約驗證器**

```move
// contracts/sources/zkp_verifier.move
module autodrive::zkp_verifier {
    use std::vector;

    /// ZKP 證明結構
    struct Groth16Proof has copy, drop {
        pi_a: vector<u256>,
        pi_b: vector<vector<u256>>,
        pi_c: vector<u256>,
        public_signals: vector<u256>,
    }

    /// 年齡驗證證明
    public fun verify_age_proof(proof: Groth16Proof): bool {
        // 這裡調用預編譯的 Groth16 驗證器
        // SUI 需要通過 Move 原生函數或預編譯合約實現

        // 偽代碼（實際需要 pairing 運算）
        let vk = get_age_verification_key();
        verify_groth16(proof, vk)
    }

    /// 餘額證明驗證
    public fun verify_balance_proof(proof: Groth16Proof, threshold: u64): bool {
        // 驗證公開輸入包含 threshold
        assert!(vector::borrow(&proof.public_signals, 0) == &(threshold as u256), 0);

        let vk = get_balance_verification_key();
        verify_groth16(proof, vk)
    }
}
```

---

## 📦 實作步驟

### Phase 1: 環境搭建（1-2 天）

1. **安裝工具**:
```bash
# 安裝 Circom 編譯器
curl -fsSL https://circom.io/install.sh | bash

# 安裝 SnarkJS
npm install -g snarkjs

# 下載 Groth16 預編譯文件
wget https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_20.ptau
```

2. **創建項目結構**:
```
autodrive_platform/
├── zkp/
│   ├── circuits/
│   │   ├── age_verification.circom
│   │   ├── balance_proof.circom
│   │   └── credit_score.circom
│   ├── build/
│   │   ├── *.wasm
│   │   └── *.zkey
│   ├── verification_keys/
│   └── scripts/
│       ├── compile.sh
│       └── setup.sh
└── ...
```

### Phase 2: 電路開發（3-5 天）

1. **開發基礎電路**:
   - `age_verification.circom`: 年齡驗證
   - `balance_proof.circom`: 餘額證明
   - `range_proof.circom`: 範圍證明（通用）

2. **編譯電路**:
```bash
cd zkp/circuits
circom age_verification.circom --r1cs --wasm --sym
```

3. **執行可信設置（Trusted Setup）**:
```bash
# Phase 1: Powers of Tau
snarkjs powersoftau new bn128 20 pot20_0000.ptau

# Phase 2: Circuit-specific setup
snarkjs groth16 setup age_verification.r1cs pot20_0000.ptau age_verification_0000.zkey

# 生成驗證密鑰
snarkjs zkey export verificationkey age_verification_0000.zkey verification_key.json
```

### Phase 3: 前端整合（2-3 天）

1. **建立 ZKP 服務**:
```javascript
// dashboard/src/services/zkp_service.js
export class ZKPService {
  async generateAgeProof(birthDate) { /* ... */ }
  async generateBalanceProof(balance, threshold) { /* ... */ }
  async verifyProof(proof) { /* ... */ }
}
```

2. **建立 UI 組件**:
```jsx
// dashboard/src/components/AgeVerification.jsx
import { ZKPService } from '../services/zkp_service';

const AgeVerification = () => {
  const [birthDate, setBirthDate] = useState(null);
  const [generating, setGenerating] = useState(false);
  const [proof, setProof] = useState(null);

  const handleGenerate = async () => {
    setGenerating(true);
    const zkpService = new ZKPService();
    const proof = await zkpService.generateAgeProof(birthDate);
    setProof(proof);
    setGenerating(false);
  };

  return (
    <div>
      <input type="date" onChange={(e) => setBirthDate(new Date(e.target.value))} />
      <button onClick={handleGenerate} disabled={generating}>
        {generating ? '生成證明中...' : '生成年齡證明'}
      </button>
      {proof && <div>證明已生成: {JSON.stringify(proof).slice(0, 100)}...</div>}
    </div>
  );
};
```

### Phase 4: 智能合約整合（3-4 天）

1. **實作 Move 驗證器**（可能需要等待 SUI 原生支持或使用預編譯合約）

2. **替代方案：使用鏈下驗證 + 鏈上記錄**
```move
module autodrive::zkp_registry {
    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;

    /// 用戶驗證記錄
    struct VerificationRecord has key {
        id: UID,
        user_address: address,
        verification_type: vector<u8>, // "age", "license", "credit"
        verified_at: u64,
        expiry: u64,
    }

    /// 註冊驗證（鏈下驗證後，鏈上記錄）
    public entry fun register_verification(
        user_address: address,
        verification_type: vector<u8>,
        proof_hash: vector<u8>, // 證明的 hash
        expiry: u64,
        ctx: &mut TxContext
    ) {
        // 創建驗證記錄
        let record = VerificationRecord {
            id: object::new(ctx),
            user_address,
            verification_type,
            verified_at: tx_context::epoch(ctx),
            expiry,
        };

        // 轉移給用戶
        transfer::transfer(record, user_address);
    }
}
```

### Phase 5: 測試與優化（2-3 天）

1. **單元測試**:
```javascript
// zkp/tests/age_verification.test.js
describe('Age Verification Circuit', () => {
  it('should verify adult age', async () => {
    const input = {
      birthYear: 1990,
      birthMonth: 5,
      birthDay: 15,
      currentYear: 2025,
      currentMonth: 10,
      currentDay: 26,
    };

    const witness = await circuit.calculateWitness(input);
    await circuit.checkConstraints(witness);
    assert.equal(witness[1], 1); // isAdult = 1
  });

  it('should reject minor age', async () => {
    const input = {
      birthYear: 2010,
      birthMonth: 5,
      birthDay: 15,
      currentYear: 2025,
      currentMonth: 10,
      currentDay: 26,
    };

    const witness = await circuit.calculateWitness(input);
    assert.equal(witness[1], 0); // isAdult = 0
  });
});
```

2. **性能測試**:
   - 證明生成時間 < 10 秒
   - 證明大小 < 500 bytes
   - 驗證時間 < 100ms

---

## 🔒 安全考量

### 1. 可信設置（Trusted Setup）

**問題**: Groth16 需要可信設置，如果設置過程被破壞，攻擊者可生成假證明

**解決方案**:
- **多方計算（MPC）**: 邀請多個獨立參與者（10-50 人）共同執行設置儀式
- **公開儀式**: 全程直播並記錄，確保透明度
- **備選方案**: 使用 Plonk（無需可信設置）

### 2. 私密數據保護

**原則**: 私密數據永遠不上鏈、不傳輸給伺服器

**實作**:
```javascript
// ❌ 錯誤：將生日發送到伺服器
await api.post('/verify-age', { birthDate });

// ✅ 正確：本地生成證明，只發送證明
const proof = await zkp.generateAgeProof(birthDate);
await api.post('/submit-proof', { proof });
```

### 3. 證明重播攻擊

**問題**: 攻擊者可能複製他人的證明重複使用

**解決方案**:
- **加入 Nonce**: 證明中包含一次性隨機數
- **加入時間戳**: 證明包含當前時間，設置有效期（例如 1 小時）
- **綁定地址**: 證明中包含用戶錢包地址

```circom
template AgeCheckWithNonce() {
    signal input birthYear;
    signal input nonce;          // 隨機數
    signal input userAddress;    // 用戶地址
    signal input currentYear;

    // ... 驗證邏輯
}
```

---

## 💰 成本分析

### 鏈上成本

| 操作 | Gas 成本（估算） | 說明 |
|-----|---------------|------|
| **部署驗證合約** | ~500,000 gas | 一次性成本 |
| **鏈上驗證（Groth16）** | ~260,000 gas | 每次驗證 |
| **鏈下驗證 + 記錄** | ~50,000 gas | 更便宜的替代方案 |

### 開發成本

| 階段 | 時間 | 人力成本（估算） |
|-----|------|---------------|
| 環境搭建 | 1-2 天 | $500 |
| 電路開發 | 3-5 天 | $2,000 |
| 前端整合 | 2-3 天 | $1,500 |
| 合約整合 | 3-4 天 | $2,000 |
| 測試優化 | 2-3 天 | $1,000 |
| **總計** | **11-17 天** | **$7,000** |

---

## 📊 實作優先級

### P0 - 立即實作（MVP）

1. ✅ **年齡驗證**: 確保用戶符合法定年齡
2. ✅ **駕照驗證**: 司機資格驗證

### P1 - 短期實作（3 個月內）

3. ⭐ **信用評分證明**: 優先匹配機制
4. ⭐ **餘額證明**: 防止無效訂單

### P2 - 長期實作（6 個月內）

5. 🔮 **行程真實性證明**: 防作弊機制
6. 🔮 **多條件組合證明**: 例如「年齡 ≥ 18 且信用 ≥ 700」

---

## 🎨 用戶體驗設計

### 驗證流程

```
用戶註冊
    │
    ├─> 輸入生日（本地）
    │
    ├─> 點擊「驗證年齡」
    │     │
    │     └─> 瀏覽器生成 ZKP（5-10 秒）
    │            │
    │            └─> 顯示進度條：「生成隱私證明中...」
    │
    ├─> 證明生成完成
    │     │
    │     └─> 自動提交證明到合約
    │            │
    │            └─> 驗證通過 ✅
    │
    └─> 用戶獲得「已驗證」徽章
```

### UI 設計

```jsx
<div className="zkp-verification">
  <h3>🔐 隱私驗證</h3>
  <p>我們使用零知識證明技術，在不洩露您的個人資訊的情況下驗證您的資格。</p>

  <div className="verification-card">
    <div className="icon">🎂</div>
    <h4>年齡驗證</h4>
    <p>證明您年滿 18 歲，無需洩露確切生日</p>
    <button onClick={handleAgeVerification}>
      開始驗證
    </button>
  </div>

  {generating && (
    <div className="progress">
      <div className="progress-bar" style={{ width: `${progress}%` }} />
      <p>生成隱私證明中... {progress}%</p>
    </div>
  )}

  {verified && (
    <div className="success">
      <CheckCircle />
      <p>驗證成功！您的隱私數據已安全保護。</p>
    </div>
  )}
</div>
```

---

## 🚀 未來擴展

### 1. 可組合證明（Composable Proofs）

允許組合多個證明：

```circom
template CompositeCheck() {
    signal input age;
    signal input creditScore;
    signal input balance;

    // 檢查: age >= 18 AND creditScore >= 700 AND balance >= 50
    // ...
}
```

### 2. 遞歸證明（Recursive Proofs）

證明「我有一個有效的年齡證明」而無需重新生成：

```
Proof_Level_1: age >= 18
Proof_Level_2: "我有一個有效的 Proof_Level_1"
```

### 3. 與 DID 整合

結合去中心化身份（Decentralized Identity）：

```javascript
// 用戶持有一個 DID（例如 Ceramic、ENS）
const did = 'did:ethr:0x123...';

// 生成綁定 DID 的證明
const proof = await generateAgeProof(birthDate, did);

// 證明可在多個 DApp 間重用
```

---

## 📚 參考資源

### 學習資源

- [Circom 官方文檔](https://docs.circom.io/)
- [SnarkJS GitHub](https://github.com/iden3/snarkjs)
- [ZK-SNARKS 簡介](https://z.cash/technology/zksnarks/)
- [ZK 應用案例](https://github.com/matter-labs/awesome-zero-knowledge-proofs)

### 開源項目

- **Tornado Cash**: 隱私交易（已下線，僅供技術參考）
- **Semaphore**: 匿名投票與身份驗證
- **zkEVM**: 以太坊零知識虛擬機

### 工具與庫

- **circomlib**: Circom 標準庫（比較器、hash 等）
- **snarkjs**: JavaScript ZKP 工具鏈
- **rapidsnark**: 快速證明生成（WASM + Native）

---

## ✅ 實作檢查清單

### 開發階段

- [ ] 安裝 Circom 和 SnarkJS
- [ ] 開發年齡驗證電路
- [ ] 開發餘額證明電路
- [ ] 執行可信設置（MPC）
- [ ] 生成 WASM 和 zkey 文件
- [ ] 建立前端 ZKP 服務
- [ ] 建立 UI 組件
- [ ] 整合智能合約
- [ ] 單元測試（電路）
- [ ] 集成測試（端到端）

### 部署階段

- [ ] 部署驗證合約到 SUI 測試網
- [ ] 上傳 WASM/zkey 到 CDN
- [ ] 建立用戶驗證流程
- [ ] 性能優化（Web Worker）
- [ ] 安全審計
- [ ] 文檔編寫
- [ ] 用戶測試
- [ ] 主網部署

---

**文檔維護者**: SUI Autonomous DApp Builder
**最後更新**: 2025-10-26
**版本**: v1.0
