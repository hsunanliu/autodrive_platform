# AutoDrive 零知識證明 (ZKP) 實施計劃

## 📋 執行摘要

本文檔詳細說明如何在 AutoDrive 去中心化叫車平台中整合零知識證明技術，以解決當前架構的隱私洩露問題。

**核心發現**：
- 🔴 **嚴重風險**: GPS 位置、支付金額、錢包地址完全公開
- 🟡 **中等風險**: 用戶信譽、行程歷史可被追蹤
- ✅ **機會**: ZKP 可在不影響功能的前提下大幅提升隱私

**建議投資**：
- 階段 1（緊急修復）: 2-3 週, $5,000
- 階段 2（基礎 ZKP）: 2-3 個月, $15,000
- 階段 3（完整架構）: 6-12 個月, $50,000

---

## 一、系統隱私問題分析

### 1.1 數據流圖（當前架構）

```
┌──────────────────────────────────────────────────────────────────┐
│                      AutoDrive 當前數據流                          │
└──────────────────────────────────────────────────────────────────┘

[乘客 Mobile App]
    ├─ 註冊
    │   └─> wallet_address (明文) → PostgreSQL
    │   └─> username, email, phone (明文) → PostgreSQL
    │
    ├─ 叫車請求
    │   └─> GPS (25.0330, 121.5654) 明文
    │       └─> WebSocket (未加密) → Backend
    │           └─> Broadcast 給附近司機（明文）
    │
    └─ 支付
        └─> Sign Transaction → Sui Blockchain
            └─> Escrow Contract (完全公開):
                - passenger: 0x1a2b3c...
                - driver: 0x4d5e6f...
                - amount: 250 SUI
                - platform_fee: 25 SUI

[司機 Mobile App]
    ├─ 實時位置更新 (每 5 秒)
    │   └─> GPS (lat, lng) 明文 → WebSocket → 乘客
    │
    └─ 收款
        └─> Smart Contract 自動轉帳 (鏈上公開)

[Backend PostgreSQL]
    ├─ users 表:
    │   - wallet_address (明文, 可關聯所有交易)
    │   - email, phone (明文)
    │   - reputation_score (明文, 0-100)
    │
    ├─ trips 表:
    │   - pickup_lat, pickup_lng (明文)
    │   - dropoff_lat, dropoff_lng (明文)
    │   - pickup_address: "台北市信義區..." (明文)
    │   - fare: 250.00 (明文)
    │   - created_at, completed_at (可推斷通勤時間)
    │
    └─ payments 表:
        - blockchain_tx_hash (可查詢鏈上所有細節)
        - amount_micro_sui (明文)

[Sui Blockchain - 完全公開]
    ├─ UserProfile:
    │   - user_address (公開)
    │   - reputation (公開)
    │   - total_rides (公開)
    │
    ├─ Escrow:
    │   - passenger, driver, platform (公開地址)
    │   - total_amount, driver_amount, platform_fee (公開金額)
    │   - status (公開)
    │
    └─ TripReceipt:
        - pickup_hash, dropoff_hash (僅哈希，較好)
        - distance_km, final_amount (公開)
        - passenger, driver (公開地址)
```

### 1.2 隱私風險矩陣

| 數據類型 | 存儲位置 | 加密狀態 | 可見性 | 風險等級 | 影響 |
|---------|---------|---------|--------|---------|------|
| **GPS 坐標** | DB + WebSocket | 明文 | 管理員 + 配對用戶 | 🔴 極高 | 可追蹤住址、工作地點、生活習慣 |
| **錢包地址** | DB + 鏈上 | 明文 | 完全公開 | 🔴 極高 | 關聯所有歷史交易、推斷財富 |
| **支付金額** | 鏈上 | 明文 | 完全公開 | 🔴 極高 | 消費習慣、經濟狀況 |
| **行程歷史** | DB + 鏈上 | 明文 | 管理員 | 🔴 高 | 行為模式、社交網絡 |
| **信譽分數** | DB + 鏈上 | 明文 | 配對用戶 | 🟡 中 | 可能被歧視、信息不對稱 |
| **用戶名/郵箱** | DB | 明文 | 管理員 | 🟡 中 | 個人信息洩露、垃圾郵件 |
| **密碼** | DB | bcrypt 哈希 | 管理員 | 🟢 低 | 已有基本保護 |

### 1.3 關鍵隱私洩露場景

#### 場景 1: 位置追蹤攻擊
**文件**: `backend/app/websocket/events.py:164-196`

```python
# 當前實現 - 完全暴露位置
@sio.event
async def update_location(sid: str, data: dict):
    trip_id = data.get("trip_id")
    lat = data.get("lat")      # 精確到小數點後 6 位（約 11 cm）
    lng = data.get("lng")

    # 廣播給房間內所有人（明文）
    await sio.emit("driver_location_update", {
        "trip_id": trip_id,
        "lat": lat,      # 🔴 完全公開
        "lng": lng,
        "timestamp": timestamp
    }, room=f"trip_{trip_id}")
```

**攻擊向量**:
1. 惡意乘客記錄司機完整 GPS 軌跡
2. 推斷司機住址（行程起點/終點聚類）
3. 追蹤司機日常路線和時間模式
4. 數據庫洩露 → 所有用戶歷史位置外洩

**影響**:
- 個人安全風險（跟蹤、騷擾）
- 違反 GDPR/CCPA（精確位置屬於敏感數據）
- 商業間諜（競爭對手分析司機分佈）

---

#### 場景 2: 財務隱私洩露
**文件**: `contracts/sources/financial/payment_escrow.move:25-45`

```move
// 當前智能合約 - 完全透明
public struct Escrow has key {
    id: UID,
    trip_id: u64,
    passenger: address,        // 🔴 公開：0x1a2b3c4d...
    driver: address,           // 🔴 公開：0x5e6f7g8h...
    platform: address,
    total_amount: u64,         // 🔴 公開：250 SUI = $500
    driver_amount: u64,        // 🔴 公開：225 SUI（司機分成 90%）
    platform_fee: u64,         // 🔴 公開：25 SUI（平台費 10%）
    payment: Coin<SUI>,
    status: u8,
}
```

**攻擊向量**:
1. 通過錢包地址查詢所有歷史交易
2. 推斷用戶月收入/支出
3. 關聯多個地址推斷總資產
4. 針對性詐騙（已知高淨值用戶）

**真實數據洩露示例**:
```bash
# 任何人都可以查詢
$ curl https://explorer.sui.io/address/0x1a2b3c...

{
  "transactions": [
    {"amount": 250, "to": "0x5e6f...", "timestamp": "2025-01-15 08:30"},
    {"amount": 180, "to": "0x7g8h...", "timestamp": "2025-01-15 18:45"},
    # ... 完整消費記錄
  ],
  "total_sent": 12500,  // 🔴 總支出：12,500 SUI = $25,000
  "frequency": "每天 2 次",
  "pattern": "早晚通勤"
}
```

---

#### 場景 3: 行為模式推斷
**文件**: `backend/app/models/ride.py:50-85`

```python
class Trip(Base):
    __tablename__ = 'trips'

    user_id = Column(Integer, ForeignKey('users.id'))
    pickup_lat = Column(Float)         # 🔴 25.033964
    pickup_lng = Column(Float)         # 🔴 121.565171
    pickup_address = Column(String(500))  # 🔴 "台北市信義區信義路五段7號"

    dropoff_lat = Column(Float)
    dropoff_lng = Column(Float)
    dropoff_address = Column(String(500))

    requested_at = Column(DateTime)    # 🔴 2025-01-15 08:30:15
    completed_at = Column(DateTime)
```

**可推斷的敏感信息**:

| 數據點 | 推斷結果 | 隱私影響 |
|--------|---------|---------|
| 每天 8:30 從 A 點到 B 點 | 住址 A，公司 B | 可定向廣告、入室盜竊 |
| 週五晚間到特定區域 | 社交習慣、娛樂偏好 | 個人隱私洩露 |
| 醫院附近頻繁行程 | 健康狀況 | 保險歧視 |
| 高消費區域 | 經濟狀況 | 詐騙目標 |

---

## 二、零知識證明應用場景

### 2.1 優先級矩陣

```
                    隱私提升
                        ↑
                        │
            P0          │      P1
      ┌─────────────────┼─────────────────┐
      │                 │                 │
      │  位置鄰近證明    │   評分閾值證明   │
      │  支付範圍證明    │                 │
      │                 │                 │
      ├─────────────────┼─────────────────┤ → 實現難度
      │                 │                 │
  P2  │  行程模式證明    │   年齡驗證       │
      │                 │   駕照驗證       │
      │                 │                 │
      └─────────────────┴─────────────────┘
```

### 2.2 場景 P0-1: 位置鄰近證明 ⭐⭐⭐⭐⭐

**問題**: GPS 坐標完全暴露

**ZKP 方案**: 證明「我在目標點 X 米範圍內」，但不公開精確坐標

#### Circom 電路設計

```circom
// zkp/circuits/location_proximity.circom
pragma circom 2.0.0;

include "circomlib/comparators.circom";
include "circomlib/sign.circom";

template LocationProximityProof() {
    // === 私密輸入（用戶保密）===
    signal input actual_lat;        // 實際緯度：25033964 (乘以 10^6)
    signal input actual_lng;        // 實際經度：121565171

    // === 公開輸入（驗證者知道）===
    signal input target_lat;        // 目標緯度
    signal input target_lng;        // 目標經度
    signal input max_distance_m;    // 最大距離（米）

    // === 公開輸出 ===
    signal output is_nearby;        // 布爾值：1 = 在範圍內, 0 = 不在

    // === 電路邏輯 ===

    // 1. 計算緯度差（以米為單位）
    // 1° 緯度 ≈ 111,000 米
    signal lat_diff;
    lat_diff <== actual_lat - target_lat;

    signal lat_diff_abs;
    lat_diff_abs <== lat_diff * lat_diff;  // 平方消除符號

    signal lat_distance_m;
    lat_distance_m <== lat_diff_abs * 111000000 / 1000000;  // 轉換為米

    // 2. 計算經度差
    // 1° 經度 ≈ 111,000 * cos(緯度) 米
    // 簡化：台灣約 25°N，cos(25°) ≈ 0.906
    signal lng_diff;
    lng_diff <== actual_lng - target_lng;

    signal lng_diff_abs;
    lng_diff_abs <== lng_diff * lng_diff;

    signal lng_distance_m;
    lng_distance_m <== lng_diff_abs * 100566000 / 1000000;  // 111000 * 0.906

    // 3. 計算總距離（簡化的歐幾里得距離）
    // 精確版應使用 Haversine 公式，但需要更多約束
    signal distance_squared;
    distance_squared <== lat_distance_m + lng_distance_m;

    signal max_distance_squared;
    max_distance_squared <== max_distance_m * max_distance_m;

    // 4. 比較距離
    component cmp = LessEqThan(32);
    cmp.in[0] <== distance_squared;
    cmp.in[1] <== max_distance_squared;

    is_nearby <== cmp.out;
}

component main {public [target_lat, target_lng, max_distance_m]} = LocationProximityProof();
```

#### 應用場景

**場景 A: 司機匹配**
```javascript
// mobile/lib/services/zkp_service.dart

class ZKPLocationService {
  // 司機證明「我在乘客 5 公里範圍內」
  async generateProximityProof({
    myLat: 25.033964,          // 私密
    myLng: 121.565171,         // 私密
    targetLat: 25.041234,      // 公開（乘客位置區域碼）
    targetLng: 121.561234,
    maxDistanceKm: 5
  }) {
    const witness = {
      actual_lat: myLat * 1e6,
      actual_lng: myLng * 1e6,
      target_lat: targetLat * 1e6,
      target_lng: targetLng * 1e6,
      max_distance_m: maxDistanceKm * 1000
    };

    // 生成證明（客戶端）
    const { proof, publicSignals } = await snarkjs.groth16.fullProve(
      witness,
      "location_proximity.wasm",
      "location_proximity.zkey"
    );

    return {
      proof: proof,
      isNearby: publicSignals[0] === "1"  // 只公開布爾結果
    };
  }
}
```

**場景 B: 行程完成驗證**
```javascript
// 證明「我確實經過了起點和終點」
async function proveRouteCompletion(trip) {
  // 證明 1: 司機曾在起點 100 米內
  const startProof = await generateProximityProof({
    myLat: actualStartLat,        // 私密
    myLng: actualStartLng,
    targetLat: trip.pickup_lat,   // 公開
    targetLng: trip.pickup_lng,
    maxDistanceKm: 0.1  // 100 米
  });

  // 證明 2: 司機曾在終點 100 米內
  const endProof = await generateProximityProof({
    myLat: actualEndLat,
    myLng: actualEndLng,
    targetLat: trip.dropoff_lat,
    targetLng: trip.dropoff_lng,
    maxDistanceKm: 0.1
  });

  // 提交到智能合約驗證
  return { startProof, endProof };
}
```

#### 智能合約驗證器

```move
// contracts/sources/zkp/groth16_verifier.move
module autodrive::location_verifier {
    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;

    // Groth16 驗證密鑰（從 ceremony 生成）
    struct VerificationKey has key, store {
        id: UID,
        alpha: vector<u8>,      // G1 point
        beta: vector<u8>,       // G2 point
        gamma: vector<u8>,      // G2 point
        delta: vector<u8>,      // G2 point
        ic: vector<vector<u8>>  // G1 points
    }

    // 證明結構
    struct Proof has copy, drop {
        a: vector<u8>,          // G1 point
        b: vector<u8>,          // G2 point
        c: vector<u8>           // G1 point
    }

    // 公開信號
    struct PublicSignals has copy, drop {
        target_lat: u64,
        target_lng: u64,
        max_distance_m: u64,
        is_nearby: u8  // 0 or 1
    }

    // 驗證函數
    public fun verify_location_proof(
        vk: &VerificationKey,
        proof: Proof,
        public_signals: PublicSignals
    ): bool {
        // 1. 檢查 is_nearby 必須為 1
        assert!(public_signals.is_nearby == 1, EInvalidProof);

        // 2. 驗證 Groth16 證明
        // 注意：Sui 當前不支持原生 pairing，需要預編譯合約
        let verified = verify_groth16_proof(
            &vk.alpha,
            &vk.beta,
            &vk.gamma,
            &vk.delta,
            &vk.ic,
            &proof.a,
            &proof.b,
            &proof.c,
            encode_public_signals(public_signals)
        );

        verified
    }

    // Pairing 驗證（需要 Sui 核心團隊支持或預編譯）
    native fun verify_groth16_proof(
        alpha: &vector<u8>,
        beta: &vector<u8>,
        gamma: &vector<u8>,
        delta: &vector<u8>,
        ic: &vector<vector<u8>>,
        proof_a: &vector<u8>,
        proof_b: &vector<u8>,
        proof_c: &vector<u8>,
        public_inputs: vector<u8>
    ): bool;
}
```

#### 隱私提升對比

| 項目 | 當前方案 | ZKP 方案 | 隱私提升 |
|-----|---------|---------|---------|
| **傳輸數據** | GPS (25.033964, 121.565171) | Proof (256 bytes) + is_nearby (1 bit) | +99% |
| **存儲數據** | 完整坐標 | 僅區域哈希 | +95% |
| **可追蹤性** | 精確軌跡 | 只知道「在範圍內」 | +90% |
| **Gas 成本** | ~0.001 SUI | ~0.05 SUI (驗證) | -50x |
| **延遲** | <100ms | ~2 秒（證明生成） | -20x |

---

### 2.3 場景 P0-2: 支付範圍證明 ⭐⭐⭐⭐⭐

**問題**: 所有交易金額鏈上完全公開

**ZKP 方案**: 使用 Bulletproofs 實現範圍證明

#### 技術選擇：Bulletproofs vs Groth16

| 特性 | Bulletproofs | Groth16 (Circom) |
|-----|-------------|------------------|
| **證明大小** | ~700 bytes (對數增長) | ~200 bytes (固定) |
| **驗證時間** | O(n)，較慢 | O(1)，極快 |
| **Trusted Setup** | ❌ 不需要 | ✅ 需要 (MPC ceremony) |
| **適用場景** | 範圍證明、交易隱私 | 複雜邏輯、固定電路 |

**選擇**: 支付隱私使用 **Bulletproofs**（無需信任設置更安全）

#### 實現方案

```rust
// zkp/src/bulletproofs/range_proof.rs
use bulletproofs::{BulletproofGens, PedersenGens, RangeProof};
use curve25519_dalek::scalar::Scalar;
use merlin::Transcript;

pub struct PaymentRangeProof {
    gens: BulletproofGens,
    pedersen_gens: PedersenGens,
}

impl PaymentRangeProof {
    pub fn new() -> Self {
        Self {
            gens: BulletproofGens::new(64, 1),  // 64-bit 範圍
            pedersen_gens: PedersenGens::default(),
        }
    }

    /// 生成範圍證明：證明 amount 在 [0, 2^64) 範圍內
    /// 且屬於某個公開的範圍桶（例如 100-200 SUI）
    pub fn prove_payment_range(
        &self,
        actual_amount: u64,      // 私密：實際金額 150 SUI
        range_bucket_min: u64,   // 公開：100 SUI
        range_bucket_max: u64,   // 公開：200 SUI
    ) -> (RangeProof, Vec<u8>) {
        // 1. 檢查金額在桶內
        assert!(
            actual_amount >= range_bucket_min && actual_amount <= range_bucket_max,
            "Amount not in range bucket"
        );

        // 2. 生成隨機盲因子（確保零知識）
        let blinding = Scalar::random(&mut OsRng);

        // 3. 創建 Pedersen 承諾：C = amount * G + blinding * H
        let commitment = self.pedersen_gens.commit(
            Scalar::from(actual_amount),
            blinding
        );

        // 4. 生成範圍證明：證明 0 ≤ amount < 2^64
        let mut transcript = Transcript::new(b"PaymentRangeProof");
        let (proof, _) = RangeProof::prove_single(
            &self.gens,
            &self.pedersen_gens,
            &mut transcript,
            actual_amount,
            &blinding,
            64  // 證明 64-bit 範圍
        ).unwrap();

        // 5. 額外證明：amount 在 [bucket_min, bucket_max]
        // 方法：證明 (amount - bucket_min) 和 (bucket_max - amount) 都 ≥ 0
        // ... 需要額外的範圍證明

        (proof, commitment.compress().to_bytes().to_vec())
    }

    /// 驗證範圍證明
    pub fn verify_payment_range(
        &self,
        proof: &RangeProof,
        commitment: &[u8],
        range_bucket_min: u64,
        range_bucket_max: u64,
    ) -> bool {
        let mut transcript = Transcript::new(b"PaymentRangeProof");

        // 解壓縮承諾
        let commitment_point = match CompressedRistretto::from_slice(commitment).decompress() {
            Some(p) => p,
            None => return false,
        };

        // 驗證基本範圍證明
        proof.verify_single(
            &self.gens,
            &self.pedersen_gens,
            &mut transcript,
            &commitment_point,
            64
        ).is_ok()

        // 注意：還需驗證金額在特定桶內（需要額外證明）
    }
}
```

#### 智能合約整合

```move
// contracts/sources/financial/private_payment_escrow.move
module autodrive::private_payment {
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::object::{Self, UID};
    use std::vector;

    // 範圍桶定義（美元等值）
    const BUCKET_0_50: u8 = 0;      // $0-50
    const BUCKET_50_100: u8 = 1;    // $50-100
    const BUCKET_100_200: u8 = 2;   // $100-200
    const BUCKET_200_500: u8 = 3;   // $200-500
    const BUCKET_500_PLUS: u8 = 4;  // $500+

    // 私密支付託管
    struct PrivateEscrow has key {
        id: UID,
        trip_id: u64,

        // 🔒 隱藏實際金額
        amount_commitment: vector<u8>,  // Pedersen 承諾
        range_bucket: u8,               // 只公開範圍（0-4）

        // 🔒 隱藏參與方（可選）
        passenger_commitment: vector<u8>,  // 地址承諾
        driver_commitment: vector<u8>,

        // ✅ 保留必要數據
        payment: Coin<SUI>,  // 實際代幣（鏈上仍可見總量）
        status: u8,
    }

    // 創建私密託管（需要範圍證明）
    public fun create_private_escrow(
        trip_id: u64,
        payment: Coin<SUI>,
        amount_commitment: vector<u8>,
        range_bucket: u8,
        range_proof: vector<u8>,  // Bulletproof 序列化
        ctx: &mut TxContext
    ): PrivateEscrow {
        // 1. 驗證範圍證明
        assert!(
            verify_bulletproof(&range_proof, &amount_commitment, range_bucket),
            EInvalidRangeProof
        );

        // 2. 驗證代幣金額與承諾一致（需要額外機制）
        // 注意：這裡有個矛盾 - Coin 的金額是公開的
        // 解決方案：使用 confidential assets 或混幣器

        PrivateEscrow {
            id: object::new(ctx),
            trip_id,
            amount_commitment,
            range_bucket,
            passenger_commitment: vector::empty(),
            driver_commitment: vector::empty(),
            payment,
            status: 0,
        }
    }

    // Bulletproof 驗證（需要預編譯支持）
    native fun verify_bulletproof(
        proof: &vector<u8>,
        commitment: &vector<u8>,
        range_bucket: u8
    ): bool;
}
```

#### 前端整合

```dart
// mobile/lib/services/zkp_payment_service.dart
import 'package:bulletproofs/bulletproofs.dart';

class ZKPPaymentService {
  final BulletproofsProver _prover = BulletproofsProver();

  /// 創建私密支付
  Future<PrivatePaymentData> createPrivatePayment({
    required double amountSUI,
    required String recipientAddress,
  }) async {
    // 1. 確定範圍桶
    final bucket = _determineBucket(amountSUI);

    // 2. 生成範圍證明
    final amountMicroSUI = (amountSUI * 1e9).toInt();
    final proofData = await _prover.proveRange(
      value: amountMicroSUI,
      min: bucket.min,
      max: bucket.max,
    );

    // 3. 返回證明數據
    return PrivatePaymentData(
      commitment: proofData.commitment,
      rangeBucket: bucket.id,
      proof: proofData.proof,
      // 實際金額只在客戶端保存，不上鏈
      actualAmount: amountMicroSUI,
    );
  }

  RangeBucket _determineBucket(double amountSUI) {
    if (amountSUI < 50) return RangeBucket(0, 0, 50e9);
    if (amountSUI < 100) return RangeBucket(1, 50e9, 100e9);
    if (amountSUI < 200) return RangeBucket(2, 100e9, 200e9);
    if (amountSUI < 500) return RangeBucket(3, 200e9, 500e9);
    return RangeBucket(4, 500e9, double.infinity);
  }
}
```

#### 隱私提升效果

**當前鏈上數據（完全公開）**:
```json
{
  "trip_id": 12345,
  "passenger": "0x1a2b3c4d5e6f...",
  "driver": "0x7g8h9i0j1k2l...",
  "total_amount": 250000000000,  // 250 SUI = $500
  "driver_amount": 225000000000,
  "platform_fee": 25000000000
}
```

**ZKP 方案鏈上數據（範圍化）**:
```json
{
  "trip_id": 12345,
  "amount_commitment": "0x8a7f6e5d4c3b...",  // Pedersen 承諾
  "range_bucket": 3,  // 只知道在 $200-500 範圍
  "range_proof": "0x9b8c7d6e5f4a...",  // 700 bytes
  "status": 1
}
```

**隱私提升**:
- ✅ 金額模糊化（只知道範圍）
- ✅ 無法精確追蹤消費習慣
- ✅ 防止針對性攻擊
- ⚠️ 限制：Sui Coin 的 value 仍可見（需要 confidential assets）

---

### 2.4 場景 P1-1: 身份驗證（年齡、駕照）⭐⭐⭐⭐

**問題**: 需上傳身份證件，洩露所有個人信息

**ZKP 方案**: 選擇性披露年齡、駕照有效性

#### 電路設計

```circom
// zkp/circuits/age_verification.circom
pragma circom 2.0.0;

include "circomlib/comparators.circom";
include "circomlib/poseidon.circom";

template AgeVerification() {
    // === 私密輸入（用戶身份證數據）===
    signal input birthYear;      // 1990
    signal input birthMonth;     // 5
    signal input birthDay;       // 15
    signal input idNumber;       // 身份證號（哈希）

    // === 公開輸入 ===
    signal input currentYear;    // 2025
    signal input currentMonth;   // 1
    signal input currentDay;     // 27
    signal input minAge;         // 18

    // === 公開輸出 ===
    signal output isAdult;       // 是否 >= minAge
    signal output idCommitment;  // 身份承諾（防止重複註冊）

    // === 計算年齡 ===
    signal ageYears;
    ageYears <== currentYear - birthYear;

    // 調整月日（如果生日未到，年齡 -1）
    signal monthPassed;
    component cmpMonth = GreaterEqThan(4);
    cmpMonth.in[0] <== currentMonth;
    cmpMonth.in[1] <== birthMonth;
    monthPassed <== cmpMonth.out;

    signal dayPassed;
    component cmpDay = GreaterEqThan(5);
    cmpDay.in[0] <== currentDay;
    cmpDay.in[1] <== birthDay;
    dayPassed <== cmpDay.out;

    signal birthdayPassed;
    birthdayPassed <== monthPassed * dayPassed;

    signal actualAge;
    actualAge <== ageYears - (1 - birthdayPassed);

    // 檢查是否成年
    component cmpAge = GreaterEqThan(7);
    cmpAge.in[0] <== actualAge;
    cmpAge.in[1] <== minAge;
    isAdult <== cmpAge.out;

    // 生成身份承諾（防止同一人重複註冊）
    component hasher = Poseidon(4);
    hasher.inputs[0] <== idNumber;
    hasher.inputs[1] <== birthYear;
    hasher.inputs[2] <== birthMonth;
    hasher.inputs[3] <== birthDay;
    idCommitment <== hasher.out;
}

component main {public [currentYear, currentMonth, currentDay, minAge]} = AgeVerification();
```

#### 駕照驗證電路

```circom
// zkp/circuits/driver_license_verification.circom
template DriverLicenseVerification() {
    // === 私密輸入 ===
    signal input licenseNumber;      // 駕照號碼
    signal input issueYear;          // 發照年份：2020
    signal input expiryYear;         // 到期年份：2030
    signal input licenseType;        // 駕照類型：2（普通小客車）

    // === 公開輸入 ===
    signal input currentYear;        // 2025
    signal input minDrivingYears;    // 最少駕齡：2 年
    signal input requiredLicenseType; // 要求類型：2

    // === 公開輸出 ===
    signal output isValid;           // 駕照是否有效
    signal output hasEnoughExperience; // 駕齡是否足夠
    signal output licenseCommitment; // 駕照承諾

    // 1. 檢查未過期
    component cmpExpiry = LessThan(12);
    cmpExpiry.in[0] <== currentYear;
    cmpExpiry.in[1] <== expiryYear;
    isValid <== cmpExpiry.out;

    // 2. 檢查駕齡
    signal drivingYears;
    drivingYears <== currentYear - issueYear;

    component cmpExperience = GreaterEqThan(4);
    cmpExperience.in[0] <== drivingYears;
    cmpExperience.in[1] <== minDrivingYears;
    hasEnoughExperience <== cmpExperience.out;

    // 3. 檢查類型
    signal typeMatch;
    typeMatch <== (licenseType == requiredLicenseType);

    // 4. 生成駕照承諾
    component hasher = Poseidon(3);
    hasher.inputs[0] <== licenseNumber;
    hasher.inputs[1] <== issueYear;
    hasher.inputs[2] <== expiryYear;
    licenseCommitment <== hasher.out;
}
```

#### 使用流程

```javascript
// 司機註冊流程
async function registerDriver(driverData) {
  // 1. 用戶在客戶端生成年齡證明
  const ageProof = await generateAgeProof({
    birthYear: 1990,      // 私密
    birthMonth: 5,
    birthDay: 15,
    idNumber: hashIDNumber("A123456789"),
    currentYear: 2025,    // 公開
    currentMonth: 1,
    currentDay: 27,
    minAge: 18
  });

  // 2. 生成駕照證明
  const licenseProof = await generateLicenseProof({
    licenseNumber: hashLicense("12-345678"),  // 私密
    issueYear: 2020,
    expiryYear: 2030,
    licenseType: 2,
    currentYear: 2025,    // 公開
    minDrivingYears: 2,
    requiredLicenseType: 2
  });

  // 3. 提交到智能合約
  await registerOnChain({
    wallet_address: "0x1a2b...",
    age_proof: ageProof.proof,
    age_commitment: ageProof.publicSignals.idCommitment,
    license_proof: licenseProof.proof,
    license_commitment: licenseProof.publicSignals.licenseCommitment,
  });

  // 4. 合約驗證通過後，發放司機 NFT
}
```

#### 智能合約驗證

```move
// contracts/sources/identity/zkp_driver_registry.move
module autodrive::zkp_driver_registry {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use autodrive::groth16_verifier;

    // 司機 NFT（只有通過 ZKP 驗證的才能獲得）
    struct DriverNFT has key, store {
        id: UID,
        owner: address,
        age_commitment: vector<u8>,      // 年齡證明承諾
        license_commitment: vector<u8>,  // 駕照證明承諾
        verified_at: u64,
        status: u8,  // 0=active, 1=suspended
    }

    // 全局註冊表（防止重複註冊）
    struct DriverRegistry has key {
        id: UID,
        registered_commitments: Table<vector<u8>, bool>,
    }

    // 註冊司機（需要 ZKP 證明）
    public fun register_driver_with_zkp(
        age_proof: vector<u8>,
        age_public_signals: vector<u64>,  // [isAdult, idCommitment]
        license_proof: vector<u8>,
        license_public_signals: vector<u64>,  // [isValid, hasExp, licenseCommitment]
        registry: &mut DriverRegistry,
        age_vk: &groth16_verifier::VerificationKey,
        license_vk: &groth16_verifier::VerificationKey,
        ctx: &mut TxContext
    ): DriverNFT {
        let sender = tx_context::sender(ctx);

        // 1. 驗證年齡證明
        assert!(
            groth16_verifier::verify(age_vk, &age_proof, &age_public_signals),
            EInvalidAgeProof
        );
        assert!(age_public_signals[0] == 1, ENotAdult);  // isAdult == 1

        // 2. 驗證駕照證明
        assert!(
            groth16_verifier::verify(license_vk, &license_proof, &license_public_signals),
            EInvalidLicenseProof
        );
        assert!(license_public_signals[0] == 1, EInvalidLicense);  // isValid
        assert!(license_public_signals[1] == 1, EInsufficientExp);  // hasEnoughExperience

        // 3. 防止重複註冊（檢查身份承諾）
        let id_commitment = encode_u64_to_bytes(age_public_signals[1]);
        assert!(
            !table::contains(&registry.registered_commitments, id_commitment),
            EDuplicateRegistration
        );
        table::add(&mut registry.registered_commitments, id_commitment, true);

        // 4. 發放司機 NFT
        DriverNFT {
            id: object::new(ctx),
            owner: sender,
            age_commitment: id_commitment,
            license_commitment: encode_u64_to_bytes(license_public_signals[2]),
            verified_at: tx_context::epoch(ctx),
            status: 0,
        }
    }
}
```

#### 隱私對比

| 項目 | 傳統 KYC | ZKP 方案 |
|-----|---------|---------|
| **提交數據** | 身份證照片、姓名、地址、生日 | 零知識證明（256 bytes）|
| **平台知道** | 所有個人信息 | 僅知道「年滿 18 歲」 |
| **洩露風險** | 數據庫洩露 → 完整信息外洩 | 洩露證明 → 無法反推身份 |
| **重複註冊** | 需要比對姓名/證件號 | 承諾哈希自動防止 |
| **合規性** | ✅ GDPR 數據最小化 | ✅ 完全符合 |

---

### 2.5 場景 P1-2: 評分系統 ⭐⭐⭐⭐

**問題**: 信譽分數完全公開，可能被歧視

**ZKP 方案**: 閾值證明 + 匿名評價

#### 信譽閾值證明

```circom
// zkp/circuits/reputation_threshold.circom
template ReputationThresholdProof() {
    // === 私密輸入 ===
    signal input actual_reputation;  // 實際分數：87
    signal input user_secret;        // 用戶密鑰（防止證明重放）

    // === 公開輸入 ===
    signal input threshold;          // 門檻：80
    signal input nonce;              // 隨機數（防止重放）

    // === 公開輸出 ===
    signal output meets_threshold;   // 是否達標：1
    signal output proof_hash;        // 證明哈希（綁定用戶）

    // 1. 檢查是否達標
    component cmp = GreaterEqThan(7);
    cmp.in[0] <== actual_reputation;
    cmp.in[1] <== threshold;
    meets_threshold <== cmp.out;

    // 2. 生成證明哈希（綁定到特定用戶和請求）
    component hasher = Poseidon(3);
    hasher.inputs[0] <== user_secret;
    hasher.inputs[1] <== threshold;
    hasher.inputs[2] <== nonce;
    proof_hash <== hasher.out;
}
```

#### 匿名評價系統

```circom
// zkp/circuits/anonymous_rating.circom
template AnonymousRatingProof() {
    // === 私密輸入 ===
    signal input trip_id;            // 行程 ID
    signal input user_id;            // 評價者 ID
    signal input trip_merkle_proof[10];  // Merkle 證明（證明參與過此行程）

    // === 公開輸入 ===
    signal input trip_merkle_root;   // 行程 Merkle 樹根
    signal input rating;             // 評分：1-5（公開）

    // === 公開輸出 ===
    signal output is_valid_reviewer; // 是否有資格評價
    signal output nullifier;         // 廢止符（防止重複評價）

    // 1. 驗證 Merkle 證明（證明用戶參與過此行程）
    component merkle = MerkleTreeChecker(10);
    merkle.leaf <== Poseidon([trip_id, user_id]);
    merkle.root <== trip_merkle_root;
    for (var i = 0; i < 10; i++) {
        merkle.pathElements[i] <== trip_merkle_proof[i];
    }
    is_valid_reviewer <== merkle.out;

    // 2. 生成廢止符（同一用戶對同一行程只能評價一次）
    component nullifierHasher = Poseidon(2);
    nullifierHasher.inputs[0] <== user_id;
    nullifierHasher.inputs[1] <== trip_id;
    nullifier <== nullifierHasher.out;
}
```

#### 應用場景

```javascript
// 司機優先匹配高信譽乘客
async function matchHighReputationPassengers(driver) {
  // 司機設置：只接受信譽 ≥ 80 的乘客
  const requests = await getMatchingRequests(driver.location);

  const qualifiedRequests = [];
  for (const request of requests) {
    // 乘客提供信譽證明（不公開實際分數）
    const proof = await request.passenger.generateReputationProof({
      threshold: 80,
      nonce: generateNonce()
    });

    // 驗證證明
    if (await verifyReputationProof(proof)) {
      qualifiedRequests.push(request);
    }
  }

  return qualifiedRequests;
}

// 乘客匿名評價司機
async function submitAnonymousRating(tripId, rating) {
  // 1. 構建行程參與者 Merkle 樹
  const tripParticipants = [passenger_id, driver_id];
  const merkleTree = new MerkleTree(tripParticipants);

  // 2. 生成匿名評價證明
  const proof = await generateAnonymousRatingProof({
    trip_id: tripId,
    user_id: passenger_id,      // 私密
    merkle_proof: merkleTree.getProof(passenger_id),
    merkle_root: merkleTree.root,  // 公開
    rating: rating  // 公開：4 星
  });

  // 3. 提交到合約
  await submitRating({
    trip_id: tripId,
    rating: rating,
    proof: proof.proof,
    nullifier: proof.publicSignals.nullifier,  // 防止重複評價
  });
}
```

---

## 三、技術架構設計

### 3.1 ZKP 技術棧選擇

```
┌─────────────────────────────────────────────────────────────────┐
│                    ZKP 技術棧架構圖                               │
└─────────────────────────────────────────────────────────────────┘

【前端（Flutter/React）】
    │
    ├─> snarkjs.js / flutter_zkp
    │   └─> 證明生成（WASM）
    │       - 輸入: witness.json
    │       - 輸出: proof.json
    │
    └─> Web Worker / Isolate
        └─> 避免阻塞 UI（2-5 秒生成時間）

【中間層（可選 - 減輕客戶端負擔）】
    │
    └─> Proof Generation Service (Docker)
        └─> rapidsnark（C++ 加速）
            - 性能: 200ms vs 2s (WASM)
            - 適合複雜電路

【電路編譯】
    │
    ├─> circom 2.0（電路語言）
    │   └─> *.circom → *.r1cs + *.wasm + *.sym
    │
    └─> Powers of Tau Ceremony (一次性)
        └─> ptau → zkey (verification key)

【智能合約（Sui Move）】
    │
    ├─> groth16_verifier.move
    │   └─> 原生 pairing 運算（需 Sui 支持）
    │   └─> 或預編譯合約
    │
    └─> Gas 成本優化
        └─> 批量驗證 + Rollup

【數據庫】
    │
    └─> PostgreSQL
        └─> 存儲承諾和證明元數據
            - id_commitment: 0x8a7f...
            - proof_hash: 0x9b8c...
```

### 3.2 系統整合方案

#### 方案 A: 混合模式（推薦）

**隱私分級策略**:
- **P0 數據（高敏感）**: 強制 ZKP
  - GPS 坐標 → 位置鄰近證明
  - 支付金額 → 範圍證明

- **P1 數據（中敏感）**: 可選 ZKP
  - 信譽分數 → 閾值證明（用戶可選擇公開）

- **P2 數據（低敏感）**: 傳統加密
  - 用戶名、頭像 → AES-256

**實施步驟**:
1. 第 1 個月：實現位置鄰近證明（最緊急）
2. 第 2 個月：實現年齡/駕照驗證
3. 第 3-4 個月：實現支付範圍證明
4. 第 5-6 個月：優化和審計

#### 方案 B: 完全 ZKP（理想）

所有數據默認隱私，需要公開時提供證明：
- 需要更長開發時間（6-12 個月）
- 更高 Gas 成本（+100-300%）
- 更好的隱私保護（GDPR 黃金標準）

### 3.3 文件結構

```
autodrive_platform/
├── zkp/
│   ├── circuits/
│   │   ├── location_proximity.circom
│   │   ├── age_verification.circom
│   │   ├── driver_license.circom
│   │   ├── reputation_threshold.circom
│   │   └── anonymous_rating.circom
│   │
│   ├── build/
│   │   ├── location_proximity.r1cs
│   │   ├── location_proximity.wasm
│   │   ├── location_proximity.zkey
│   │   └── verification_key.json
│   │
│   ├── scripts/
│   │   ├── compile_circuits.sh
│   │   ├── generate_keys.sh
│   │   └── run_ceremony.sh
│   │
│   └── src/
│       ├── bulletproofs/
│       │   └── range_proof.rs
│       └── utils/
│           └── witness_calculator.js
│
├── contracts/sources/zkp/
│   ├── groth16_verifier.move
│   ├── location_verifier.move
│   ├── age_verifier.move
│   └── payment_verifier.move
│
├── backend/app/services/
│   ├── zkp_service.py
│   └── proof_verification_service.py
│
└── mobile/lib/services/
    ├── zkp_service.dart
    ├── zkp_location_service.dart
    ├── zkp_payment_service.dart
    └── zkp_identity_service.dart
```

---

## 四、分階段實施計劃

### 階段 0: 緊急修復（1-2 週，$5,000）

**目標**: 立即減少最嚴重的隱私洩露

#### 任務清單

1. **WebSocket TLS 加密** (2 天)
   - 文件: `backend/app/main.py`
   - 實現 SSL/TLS 證書
   - 配置 nginx 反向代理

2. **數據庫敏感字段加密** (3 天)
   - 文件: `backend/app/models/user.py`, `ride.py`
   - 使用 SQLAlchemy 加密擴展
   - 加密字段: email, phone, GPS 坐標

3. **位置數據降精度** (2 天)
   - Geohash 6 位（±600 米）
   - 只存儲區域碼而非精確坐標

4. **日誌脫敏** (1 天)
   - 移除日誌中的敏感信息
   - 實現日誌過濾器

**成本**: $5,000（1 個全職開發者，10 天）

**預期效果**: 隱私提升 30%，風險降低 50%

---

### 階段 1: 基礎 ZKP 實現（2-3 個月，$15,000）

**目標**: 實現核心 ZKP 功能

#### Sprint 1: 環境搭建（2 週）

**任務**:
1. 安裝 circom, snarkjs, rapidsnark
2. 配置 Powers of Tau ceremony
3. 建立 CI/CD 流程
4. 編寫測試框架

**交付物**:
- ZKP 開發環境 Docker image
- Ceremony 腳本
- 自動化測試套件

#### Sprint 2: 年齡驗證（3 週）

**任務**:
1. 實現 `age_verification.circom`
2. 生成驗證密鑰
3. Sui Move 驗證器合約
4. Flutter 客戶端整合

**交付物**:
- 年齡驗證電路（經過審計）
- 智能合約: `age_verifier.move`
- Flutter SDK: `zkp_identity_service.dart`
- 單元測試 + 集成測試

#### Sprint 3: 位置鄰近證明（4 週）

**任務**:
1. 實現 `location_proximity.circom`
2. 優化 Haversine 公式（減少約束）
3. 智能合約驗證器
4. WebSocket 整合

**交付物**:
- 位置證明電路
- 驗證器合約: `location_verifier.move`
- 後端 API: `/api/v1/zkp/verify-location`
- 前端整合

#### Sprint 4: 測試與優化（2 週）

**任務**:
1. 端到端測試
2. 性能優化（證明生成時間 <3 秒）
3. Gas 成本優化
4. 用戶文檔

**成本**: $15,000（1 個 ZKP 專家 + 1 個智能合約開發者，10 週）

**預期效果**: 隱私提升 60%，用戶體驗 -10%（證明生成延遲）

---

### 階段 2: 支付隱私（1-2 個月，$10,000）

**目標**: 實現 Bulletproofs 範圍證明

#### 任務清單

1. **Bulletproofs 實現** (3 週)
   - Rust 庫: `bulletproofs`
   - 範圍證明 API
   - 承諾方案

2. **智能合約整合** (2 週)
   - Sui 預編譯支持（或等待官方）
   - 驗證器合約
   - Confidential Assets 方案

3. **前端整合** (2 週)
   - Flutter Bulletproofs plugin
   - 支付流程改造

4. **測試** (1 週)

**成本**: $10,000

---

### 階段 3: 完整隱私架構（3-6 個月，$25,000）

**目標**: 全面隱私保護

#### 功能清單

1. **匿名評價系統**
   - Merkle 樹驗證
   - 廢止符機制

2. **混幣器 (Mixer)**
   - 切斷地址關聯
   - 提款延遲機制

3. **零知識 Rollup**
   - 批量驗證
   - Gas 成本降低 70%

4. **隱私分析工具**
   - 隱私分數儀表板
   - 洩露檢測

**成本**: $25,000

---

## 五、成本與收益分析

### 5.1 總成本估算

| 階段 | 時間 | 人力 | 成本 | 累計 |
|------|------|------|------|------|
| **階段 0** | 2 週 | 1 Dev | $5,000 | $5,000 |
| **階段 1** | 3 月 | 2 Dev | $15,000 | $20,000 |
| **階段 2** | 2 月 | 1 Dev | $10,000 | $30,000 |
| **階段 3** | 6 月 | 2 Dev | $25,000 | $55,000 |
| **審計** | 1 月 | 外部 | $15,000 | $70,000 |
| **維護（年）** | - | 0.5 Dev | $10,000/年 | - |

### 5.2 隱私提升對比

| 階段 | 位置隱私 | 支付隱私 | 身份隱私 | 總體隱私 | GDPR 合規 |
|------|---------|---------|---------|---------|-----------|
| **當前** | 0% | 0% | 20% | 10% | ⚠️ 風險 |
| **階段 0** | 30% | 0% | 40% | 25% | ⚠️ 部分 |
| **階段 1** | 80% | 0% | 90% | 60% | ✅ 大部分 |
| **階段 2** | 80% | 70% | 90% | 75% | ✅ 完全 |
| **階段 3** | 95% | 90% | 95% | 90% | ✅ 黃金 |

### 5.3 Gas 成本影響

| 操作 | 當前 Gas | ZKP Gas | 增幅 | 備註 |
|------|---------|---------|------|------|
| 用戶註冊 | 0.01 SUI | 0.05 SUI | +400% | 需年齡驗證 |
| 司機註冊 | 0.01 SUI | 0.08 SUI | +700% | 需駕照驗證 |
| 創建行程 | 0.005 SUI | 0.03 SUI | +500% | 位置證明 |
| 支付託管 | 0.01 SUI | 0.06 SUI | +500% | 範圍證明 |
| **Rollup 後** | - | 0.015 SUI | +50% | 批量驗證 |

### 5.4 ROI 分析

**收益**:
1. **用戶增長**: +20-40%（隱私敏感用戶吸引）
2. **法律風險**: -$500K（避免 GDPR 罰款）
3. **品牌價值**: +$100K（隱私標籤）
4. **競爭優勢**: 無法量化（市場第一個隱私叫車平台）

**成本**:
- 開發: $55K
- 審計: $15K
- 維護: $10K/年
- Gas 補貼: $20K/年（階段 1-2，Rollup 前）

**淨收益（3 年）**:
```
收益: ($500K 風險避免) + ($100K 品牌) + (20% 用戶增長 × $200K 收入 × 3 年)
    = $500K + $100K + $120K = $720K

成本: $55K + $15K + ($10K × 3) + ($20K × 2) = $140K

ROI = ($720K - $140K) / $140K = 414%
```

---

## 六、風險與挑戰

### 6.1 技術風險

| 風險 | 影響 | 可能性 | 緩解措施 |
|------|------|-------|---------|
| **Sui pairing 不支持** | 🔴 高 | 中 | 使用預編譯或等待官方支持 |
| **證明生成太慢** | 🟡 中 | 高 | 使用 rapidsnark 加速 |
| **電路有 bug** | 🔴 高 | 中 | 專業審計 + 形式化驗證 |
| **密鑰洩露** | 🔴 極高 | 低 | MPC ceremony + 硬件保護 |

### 6.2 用戶體驗風險

| 問題 | 影響 | 解決方案 |
|------|------|---------|
| 證明生成延遲 2-5 秒 | 用戶流失 | - Web Worker 異步生成<br>- 顯示進度條<br>- 預生成證明 |
| Gas 成本增加 5 倍 | 用戶抱怨 | - 平台補貼前期用戶<br>- Rollup 降低成本<br>- 分級定價（隱私 vs 便宜） |
| 概念難以理解 | 採用率低 | - 簡化 UI（一鍵驗證）<br>- 教育內容<br>- 默認開啟隱私 |

### 6.3 法律與合規風險

| 問題 | 風險 | 對策 |
|------|------|------|
| 監管要求 KYC | 無法匿名 | 選擇性披露（ZKP 仍可證明年齡）|
| 稅務審計 | 需要交易記錄 | 鏈下保留加密備份 |
| 反洗錢 AML | 混幣器被禁 | 透明度選項（用戶可選）|

---

## 七、總結與建議

### 7.1 關鍵發現

1. **嚴重隱私洩露**: 當前系統 GPS、支付、身份完全透明
2. **ZKP 可行性**: 技術成熟，但需要 Sui pairing 支持
3. **成本可控**: $55K 開發 + $15K 審計，ROI 414%
4. **分階段實施**: 優先位置和身份，最後支付

### 7.2 推薦方案

**選擇階段 1（基礎 ZKP）作為起點**:
- 時間: 3 個月
- 成本: $20K（含緊急修復）
- 隱私提升: 60%
- 風險可控

**長期目標**:
- 12 個月內完成階段 2-3
- 成為市場第一個隱私叫車平台
- 符合 GDPR 黃金標準

### 7.3 立即行動項

**本週**:
1. ✅ 實施 WebSocket TLS
2. ✅ 數據庫字段加密
3. ✅ 位置降精度

**下週**:
1. 招募 ZKP 專家（1 人）
2. 設置 circom 開發環境
3. 啟動 Powers of Tau ceremony

**下月**:
1. 完成年齡驗證電路
2. 部署測試網驗證器
3. 用戶測試

---

## 八、參考資料

### 技術文檔
- [Circom 官方文檔](https://docs.circom.io/)
- [snarkjs GitHub](https://github.com/iden3/snarkjs)
- [Bulletproofs 論文](https://eprint.iacr.org/2017/1066.pdf)
- [Sui Move 文檔](https://docs.sui.io/concepts/sui-move-concepts)

### 隱私標準
- [GDPR 數據最小化原則](https://gdpr-info.eu/art-5-gdpr/)
- [零知識證明標準 (ZKProof)](https://zkproof.org/standards/)

### 開源專案
- [Semaphore (匿名投票)](https://github.com/semaphore-protocol/semaphore)
- [Tornado Cash (混幣器)](https://github.com/tornadocash)
- [zkSync (ZK Rollup)](https://github.com/matter-labs/zksync)

---

**文檔版本**: v1.0
**最後更新**: 2025-01-27
**作者**: AutoDrive 技術團隊
**審核**: 待審
