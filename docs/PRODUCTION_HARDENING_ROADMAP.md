# ChainSUI 生產級加固路線圖 (Production Hardening Roadmap)

> **這份文件是本次「上主網生產級」重構的單一事實來源 (Single Source of Truth)。**
> 任何 agent（Move 合約、後端、行動端、測試）接手前**必讀本檔**，並在完成工作後更新 [§7 進度追蹤](#7-進度追蹤-progress-tracker) 與 [§8 變更日誌](#8-變更日誌-changelog)。

- **專案**：ChainSUI — 去中心化叫車 DePIN 平台
- **目標賽事**：Sui Overflow 2026「Agentic Web」賽道
- **鏈**：Sui（testnet framework）。**注意：`iota-src/`、`iota_*` 服務、`tests/run_tests.sh` 是舊 IOTA 遺留死碼，不要沿用。**
- **審查基準日**：2026-07-12
- **狀態圖例**：⬜ 未開始 / 🟡 進行中 / ✅ 完成 / ⛔ 卡住（需人工）

---

## 1. 為什麼要做這件事 (Context)

對 12 個已實作 Move 模組、後端 Sui 整合層、ZKP/DID 子系統做生產級審查後，發現**距離上主網有致命差距**：

1. **資金可被任意掏空** — 退款池與託管釋放缺存取控管。
2. **身分驗證形同虛設** — 鏈上 Groth16 驗證是 stub（只檢查 `length(proof) > 0`）。
3. **Agentic 主題未落地** — 「AI Agent」是規則式運算，且用**單一平台私鑰代表所有人簽章**，鏈上零授權委託。
4. **私鑰明碼** — 真實 Sui operator 私鑰、Google/FCM 金鑰寫在 `.env`。
5. **鏈上寫入多為 mock** — 大量流程回傳 `sha256` 假交易 hash 且 `success:True`。
6. **無去中心化存儲** — 批量資料全在 Postgres，GPS 軌跡根本沒落地，完全沒有 Walrus。

**產出要求**：先條列問題與「為什麼」，再提供**修改後、完整可運行**的 Move / Python 程式碼；並將 Agent 能力委託與 Walrus 端到端整合納入。

---

## 2. 架構事實（已確認，勿再重新調查）

| 項目 | 事實 |
|---|---|
| 框架 | Sui framework `testnet`（`Move.toml`/`Move.lock` 實際解析）。所有 source `use sui::`，無 `iota::`。 |
| 已發布 package | `contracts/Published.toml` → testnet `0xa6232c7f85812fe5e57c2e72071915e538ebd2fd7aba98371bd58490e790380b` |
| 已實作 Move 模組 | 12 個（見 §3）。另有 7 個 0-byte 空檔（`platform_controller.move` 等），對應測試無法編譯。 |
| 命名空間 | `autodrive::*`（financial + identity-DID）與 `decentralized_ride::*`（registries/rating/receipt），皆解析到同一 `0x0` package。 |
| 後端簽章 | 單一平台 `OPERATOR_PRIVATE_KEY`，用 `pysui==0.65.0`。**無 Capability 委託**。 |
| 鏈上寫入現況 | 大多 mock（假 hash）。真正會嘗試上鏈的只有 `sui_service.call_contract_lock_payment/release_payment`，但失敗即降級回假 hash。 |
| AI Agent | 100% 規則式，無 LLM。報價 = 線性公式；搓合 = 最近距離排序。 |
| 大容量資料 | 全在 Postgres。GPS 軌跡經 Socket.IO 廣播後**不落地**。IPFS 僅用於退款佐證（本地單節點）。**無 Walrus**。 |
| ZKP | snarkjs/Groth16，兩個電路（age、license）。**證明在後端產生（收原始 PII）**、後端 snarkjs 驗證。鏈上驗證是 stub。 |

---

## 3. 受影響模組地圖

**Move（`contracts/sources/`）**
- `financial/payment_escrow.move` — 託管（release 無授權 ⚠️）
- `financial/refund_module_v2.move` — 退款池（submit_for_auto_refund 可掏空 ⚠️⚠️）
- `financial/refund_module.move` — v1 舊版（建議刪除）
- `identity/credential_verifier.move` — ZKP 驗證 stub ⚠️
- `identity/user_registry.move` — 自我提權 ⚠️
- `identity/did_registry.move` — 弱格式驗證、borrow-before-exists
- `identity/{vehicle_registry,trusted_issuers}.move`
- `business/rating_proof.move` — 評分可被任意竄改 ⚠️
- `business/trip_receipt.move` — 僅記錄，加 Walrus 錨定欄位
- `utils/{constants,events}.move`（其餘 utils 為空檔）
- **新增** `agent/agent_registry.move` — OperatorCap 委託

**後端（`backend/app/`）**
- `config.py`、`.env`（+ repo 根 `docker-compose.yml`）
- `services/{sui_service,contract_service,escrow_service,refund_service_v2,wallet_service}.py`
- `services/{zkp_prover,zkp_verifier,identity_service}.py`
- `api/v1/{refunds,wallet,payment_proxy,zkp}.py`、`main.py`
- **新增** `services/{agent_service,walrus_service}.py`
- **刪除死碼**：`iota_*`、`real_blockchain_service.py`、`matching_service.py`、`refund_service.py`(v1)、`api/v1/{blockchain,iota,contract_integration}.py`

**行動端（`mobile/lib/`）**
- `services/zkp_service.dart`（改客戶端產證）、`mobile/assets/zkp/`

---

## 4. 執行優先序與 Agent 分工

> **P0 必須先於 P1，P1 先於 P2。** 每個 Agent 對應一組獨立工作包，可在同優先層內並行。

| # | 優先 | 工作包 | 負責 Agent | 依賴 |
|---|---|---|---|---|
| 1 | **P0** | Move 致命漏洞修復（escrow / refund / 自我提權 / did） | `move-security-fixer` | 需先有 #3 的 OperatorCap |
| 2 | **P0** | 後端秘密外洩 + 移除 mock 假交易 | `backend-secrets-fixer` | — |
| 3 | **P0** | ZKP 真驗證（`sui::groth16`）+ 客戶端產證 | `zkp-onchain-verifier` | — |
| 4 | **P1** | Agent 能力委託 `agent_registry` + PTB | `agent-capability-designer` | 阻擋 #1 的 release 授權 |
| 5 | **P1** | 後端 Agent runtime（附 cap 送單） | `agent-backend-integrator` | #4 |
| 6 | **P1** | Walrus 端到端（軌跡/評價/佐證） | `walrus-storage-integrator` + `move-anchor-author` | — |
| 7 | **P2** | PTB 合併、on-chain 瘦身、死碼清理 | `sui-gas-optimizer` + `deadcode-cleaner` | #1–#6 |
| 8 | **P2** | Move + 後端測試 | `move-test-author` + `backend-test-author` | #1–#6 |

> **排程備註**：#4（OperatorCap）是 #1 escrow release 授權的前置，因此實作順序為 **#4 → #1**，其餘 P0 可並行。

---

## 5. 詳細工作規格 (Task Specs)

每項格式：**問題 → 為什麼 → 修法 → 檔案**。逐行行號見 `~/.claude/plans/parsed-rolling-cerf.md` 與審查報告。

### P0-A · Move 致命漏洞

**A1. `refund_module_v2::submit_for_auto_refund` 可掏空退款池 (CRITICAL)**
- 問題：此 entry 無 `RefundCapability`、無 sender 檢查即從共享 `RefundPoolV2.balance` 出金給 `requester`；`create_refund_request` 讓任何人自填 `refund_amount`。
- 為什麼：共享物件的資金移動函式無能力物件把關＝無鎖金庫。
- 修法：**刪除** `submit_for_auto_refund`；所有出金走 `approve_and_execute`（已需 `&RefundCapability`）。退款金額改由鏈上託管餘額決定，不接受呼叫者自填。
- 檔案：`financial/refund_module_v2.move`

**A2. `payment_escrow::release_payment` 任何人可強制放款 (CRITICAL)**
- 問題：`Escrow` 為 shared object，release 只檢查 status/trip_id，無授權；用完的空 `Escrow` 永不刪除。
- 為什麼：託管信任模型要求「只有被授權者能觸發放款」。
- 修法：release 需授權來源之一 — (a) 乘客本人簽章確認完成，或 (b) 持 `OperatorCap`（見 P1-A）。放款後 `object::delete` 拆空 `Escrow`。退款同理加授權與時效。
- 檔案：`financial/payment_escrow.move`（依賴 `agent/agent_registry.move`）

**A3. 自我提權：`user_registry` / `rating_proof` (HIGH)**
- 問題：`user_registry::{update_reputation,add_ride,add_drive}` 為無 cap 的 `public fun`，owner 可在 PTB 自抬信譽越過 `can_drive`；`rating_proof::{create_rating_proof,create_vehicle_stats,update_vehicle_stats}` 無把關，任何人可竄改任一車評分（Sybil）。
- 為什麼：狀態變更對呼叫者身分零約束。
- 修法：跨模組狀態變更改需 witness / 平台 cap；評分寫入須綁定有效 `TripReceipt`（rater 必為該行程乘客）；`VehicleRatingStats` 以 registry Table 收斂為每車唯一。
- 檔案：`identity/user_registry.move`、`identity/vehicle_registry.move`、`business/rating_proof.move`

**A4. 合約強化**
- `did_registry`：補 DID 內嵌 address 與 `controller` 一致性（現 TODO）；`update/deactivate` 先查存在再 `borrow_mut`；`active_dids - 1` 防下溢。
- 時間戳統一為 `sui::clock::Clock`。
- 啟用 `constants::PLATFORM_FEE_RATE`（2.5%）鏈上計費，移除自填 `platform_fee`。
- 檔案：`identity/did_registry.move`、`utils/constants.move`、`financial/payment_escrow.move`

### P0-B · 後端秘密與真實鏈上寫入
- **秘密外洩 (CRITICAL)**：`.env` 有真實 `OPERATOR_PRIVATE_KEY` / `GOOGLE_MAPS_API_KEY` / `FCM_SERVER_KEY` / 弱 JWT。→ **視為已洩漏，立即輪替**；改由 secret manager 注入；移除 `config.py` 弱預設（缺值 fail-fast）；修 `wallet_service.py` salt（現用 `sha256(password)` 當 salt）。
- **mock 冒充真交易 (HIGH)**：移除所有「失敗即回假 hash」fallback，改明確拋錯 + 重試 + 告警；補齊 escrow/refund 真實 pysui 交易（走 PTB）。CORS/Socket.IO `*` → 白名單；補回 `refunds.py` 被註解的 admin 驗證；`wallet.py` 建錢包端點加驗證。
- 檔案：見 §3。

### P0-C · ZKP 端到端
- 鏈上改用 `sui::groth16::verify_groth16_proof(&pvk, &public_inputs, &proof_points)`；`VerificationKey` 存完整 vk bytes 並綁 `credential_type`；`register_verification_key` 加 `AdminCap`；補 `verify_license_credential` 的 deactivated 檢查。
- 客戶端產證：`mobile/lib/services/zkp_service.dart` 改用 `mobile/assets/zkp/*.wasm/*.zkey` 本地產證，後端/鏈上只收 proof + public signals。
- 移除 `zkp_prover.py` / `zkp_verifier.py` 的 simulated fallback（`public_signals[0]==1` 即過）。

### P1-A · Agent 能力委託（Agentic 核心）
- 新增 `contracts/sources/agent/agent_registry.move`：`OperatorCap { user, agent, max_spend_per_tx, daily_limit, spent_today, valid_until, allowed_actions }`。用戶簽發一次授權給 Agent；Agent 代發交易時各 entry 斷言 agent==sender、未過期、金額/累計在限、動作在白名單；用戶可 `revoke`。以 **PTB 原子化**：一筆完成「驗證完成→release→記 receipt→更新評分」。
- 後端 `agent_service.py` 包裝現有規則式報價/搓合為 Agent 決策層，觸發鏈上動作附 `OperatorCap` 走 PTB。

### P1-B · Walrus 端到端
- 新增 `backend/app/services/walrus_service.py`：封裝 publisher/aggregator（`PUT/GET /v1/blobs`）、epoch/存活期、重試、content-hash 驗證。
- 三條路徑（後端上傳 Walrus → 取 `blob_id` → Move 錨定 `blob_id`+`content_hash` → 讀取時比對 hash）：
  1. 行車軌跡：`app/websocket/events.py` 累積 GPS → 行程結束上傳 → `TripReceipt.trajectory_blob_id`
  2. 評價媒體/文字：`rating_service` → `RatingProof.content_blob_id`（+ 現有 32-byte `content_hash`）
  3. 退款佐證：`refund_requests.evidence_cid`(IPFS) → Walrus `evidence_blob_id`
- Move 端於 `trip_receipt.move`/`rating_proof.move`/`refund_module_v2.move` 加 `blob_id`/`content_hash` 欄位。淘汰單節點 `ipfs_service.py`。

### P2 · 優化與測試
- PTB 合併（accept→lock、complete→release、receipt、rating 併單）；on-chain 瘦身（大資料改指 Walrus blob）；死碼清理（IOTA 遺留、空 module、`run_tests.sh`→`sui move test`）。
- Move 測試：退款池授權、escrow release 授權、OperatorCap 額度/時效邊界、Groth16 正反例、評分需綁行程。
- 後端測試：escrow/refund 真實鏈上路徑、Agent PTB、Walrus 上傳/讀取/hash、ZKP 端到端。

---

## 6. 驗證方式 (Verification)

0. 部署：`scripts/ops/deploy_and_init.sh`（發布套件並印出所有 registry/pool/cap 的 object ID，貼進 `backend/.env`；範例見 `backend/.env.example`）。
1. `cd contracts && sui move build`（全編譯、無 IOTA 殘留）→ `sui move test`（P2 測試全綠，目前 9/9 PASS）。
2. Testnet 部署後驗證攻擊已封堵：
   - 非 cap 帳號呼叫舊 `submit_for_auto_refund` / `release_payment` → 應 abort。
   - 偽造空 proof 呼叫 `verify_age_credential` → 應 abort。
   - 用戶自呼 `update_reputation` 自抬信譽 → 應 abort。
3. 後端：移除 `.env` 私鑰後仍能從 secret manager 啟動；escrow lock→release 走真 PTB，Sui explorer 查得真實 tx（非 sha256 假 hash）。
4. Agent：模擬一趟行程，Agent 持 `OperatorCap` 在額度內完成 release；超額/過期 → 交易被拒。
5. Walrus：行程結束後軌跡上 Walrus，`blob_id` 出現在 `TripReceipt`，後端讀回並通過 content-hash 驗證。
6. 掃描確認無明碼私鑰、CORS 白名單生效、mock fallback 已移除。

---

## 7. 進度追蹤 (Progress Tracker)

> 每個 Agent 完成工作後更新此表對應列的狀態，並在 §8 追加一筆日誌。

### P0 — 安全止血
- [x] ✅ **A1** 刪除 `submit_for_auto_refund`，退款一律走 cap `refund_module_v2.move`
- [x] ✅ **A2** `payment_escrow.release_payment` 加授權（乘客簽章 / OperatorCap）+ 放款後刪 Escrow + 費率上鏈
- [x] ✅ **A3a** `user_registry` reputation/rides 提權防護（UserProfile 改共享 + admin 把關；`vehicle_registry.add_trip` 同）
- [x] ✅ **A3b** `rating_proof` 綁定 TripReceipt（評價者須為該行程乘客）+ 統計更新併入評價 + `RatingAdminCap` 建立統計
- [x] ✅ **A4** `did_registry` 存在檢查 + DID 內嵌位址綁定 controller + 下溢註記；`string::as_bytes`
- [x] ✅ **B1** `config.py` 移除弱預設 + fail-fast（缺 SECRET_KEY/DATABASE_URL/OPERATOR_PRIVATE_KEY 即拒絕啟動）；`wallet_service` salt 改隨機。⚠️ **金鑰輪替由用戶手動處理（進行中）**
- [x] 🟡 **B2**（安全加固部分）移除 `sui_service` 靜默假成功 fallback + `escrow_service.refund` 假 hash；CORS/Socket.IO 收斂白名單；`refunds` approve/reject 還原 `get_current_admin`。**真實 pysui 交易串接（release_payment_by_agent + OperatorCap）移至 P1 D2**（依賴 cap 部署）
- [x] ✅ **C1** `credential_verifier` 改 `sui::groth16` 真驗證 + `CredentialAdminCap` + license deactivated 檢查
- [x] 🟡 **C2**（後端安全部分）移除**所有**可偽造的 simulated ZKP 路徑（`zkp_prover`/`zkp_verifier` 缺 key 改 fail-closed；`identity_service` 移除 `_simulate_zkp_verification` 兩條捷徑）；額外修掉 `trips.py` 的**免費搭車漏洞**（模擬付款改為只在 `MOCK_MODE` 生效）。**行動端本地產證待辦**（需 Flutter JS/WASM prover runtime，見下）
  - ⬜ **C2-mobile**：`zkp_service.dart` 目前把原始 PII（生日、駕照號）明碼送後端。需在 App 內用 `mobile/assets/zkp/*.wasm/*.zkey` + `witness_calculator.js`（透過 flutter_js 或原生 prover）本地產證，只送 proof + public signals。此為獨立 Flutter 工作包，需可執行/測試環境。

> **里程碑（2026-07-12）**：P0 全部**合約層**修復完成，`sui move build` 綠燈（0 error）。
> 附帶生產級改進：`Move.toml` 相依由移動分支 `framework/testnet` 釘到穩定 tag `testnet-v1.53.2`（可重現建置）。
> 剩餘 P0 為後端（B1/B2）與行動端（C2）。

### P1 — Agent 委託 + Walrus
- [x] ✅ **D1** 新增 `agent/agent_registry.move`（OperatorCap 模式，提前完成作為 A2 前置）
- [x] 🟡 **D2**（核心完成）新增 `agent_service.py`：Agent 以自身金鑰簽章、持乘客的 `OperatorCap` 呼叫 `release_payment_by_agent`/`refund_payment_by_agent`（PTB，含 `0x6` clock），鏈上失敗明確報錯不 mock。**剩餘**：per-user cap 發現（DB/鏈上映射「passenger→cap_object_id」）、把 `trip_service.complete_trip` 的釋放改走 `agent_service`（需用戶已簽發 cap 的產品流程）
- [x] ✅ **E1** 新增 `walrus_service.py`（PUT/GET blobs、重試、content-hash 校驗、單例）+ `config.py` Walrus 端點設定
- [x] ✅ **E2** Move 錨定欄位：`TripReceipt.{trajectory_blob_id,trajectory_hash}`、`RatingProof.content_blob_id`（`sui move build` 綠燈）
- [x] ✅ **E3** 三條 Walrus 路徑全部接上：
  - **軌跡**：`trajectory_service.py` 緩衝 → `complete_trip` flush→Walrus → 錨定 `TripReceipt`。
  - **評價**：`rating_service.create_rating` 上傳標準化評論到 Walrus（內容 hash == `rating_hash`）→ `content_blob_id`（+ migration 003 + 模型欄位）。
  - **退款佐證**：`refunds.py` 上傳改走 Walrus（`blob_id`→`evidence_cid`、內容 hash→`evidence_hash`），**淘汰單節點 IPFS** 依賴。

### P2 — 優化與測試
- [x] ✅ **F1** PTB 合併 + on-chain 瘦身：新增 `payment_escrow::release_and_receipt_by_agent`（單一交易原子完成釋放+開收據，省一筆 gas，杜絕「已放款但沒收據」中間態）；`trip_receipt::create_receipt_for` 供跨模組複合呼叫。費率已上鏈、大資料已改指 Walrus blob。（測試 13/13 PASS）
- [x] ✅ **F2** 死碼清理：刪 7 個 0-byte source module、17 個空/IOTA 測試檔、`run_tests.sh`
- [x] ✅ **G1** Move 安全測試（`tests/security_tests.move`，**12 tests 全 PASS**）：託管授權、Agent cap 額度/撤銷/動作白名單/時效、評價綁行程、reputation 提權防護、DID 位址綁定
- [x] ✅ **G2** 後端整合測試（`backend/tests/integration/`，**43 tests 全 PASS**）：agent 護欄額度/白名單/跨用戶、agent_service 缺金鑰與鏈上失敗明確報錯（不回假 hash）、delegation 過期/撤銷 cap 拒用、Walrus content-hash 校驗、zkp_verifier fail-closed、trips 模擬付款僅 MOCK_MODE、refund approve/reject。外部依賴全 fake，`docker compose exec backend python -m pytest` 執行；舊 hackathon 測試隔離至 `tests/legacy/`

> **里程碑（2026-07-12）**：`sui move test` 綠燈，9 個安全測試證明核心修復有效。

---

## 8. 變更日誌 (Changelog)

- 2026-08-14 · [實機偵錯環境修復] · 兩個互不相關的問題：(1) 無線偵錯「Dart VM Service was not discovered」＝ `Info.plist` 缺 `NSBonjourServices`（`_dartVmService._tcp`）與 `NSLocalNetworkUsageDescription`，缺了系統不會跳「區域網路」授權、Flutter 找不到 VM Service，已補上；(2) Google 登入 http timeout ＝ `app_config.local.dart` 的後端位址仍是舊熱點 IP `172.20.10.14`，Mac 現為 `192.168.150.143`，手機連不到後端（`/health` 於新 IP 驗證可達），已更新（該檔 gitignored）。另查 USB 完全看不到 iPhone（`system_profiler SPUSBDataType` 無 Apple 裝置）→ 連線全走無線的原因是線材/埠不傳資料。 · `mobile/ios/Runner/Info.plist`, `mobile/lib/config/app_config.local.dart`(不入庫)

- 2026-08-13 · [任務3 Flutter 靜態驗證] · `flutter pub get && flutter analyze`：唯一 error 是範本遺留 `test/widget_test.dart` 引用不存在的 `MyApp`，改為對應 `ProjectDappApp` 的最小 smoke test → **0 error**。剩 17 warning（全為 unused import/field/variable）與 402 info（`withOpacity`/`WillPopScope` deprecation、`avoid_print` 等），無功能影響，留待日後清理。 · `mobile/test/widget_test.dart`
- 2026-08-13 · [G2 後端整合測試 ✅] · 新增 `backend/tests/integration/` pytest harness（**43 tests 全 PASS**，`docker compose exec backend python -m pytest`）。外部依賴（Sui RPC、Walrus、DB、snarkjs）全用可注入 fake、不製造假交易 hash。覆蓋：agent 護欄額度/每日剩餘/動作白名單/跨用戶/髒 object id、agent_service 缺金鑰與鏈上失敗明確報錯不回假 hash、delegation 過期/撤銷 cap 拒用與額度時效解析、walrus content-hash 不符拋錯不重試、zkp_verifier 缺 key fail-closed、trips 模擬付款僅 MOCK_MODE、refund_service_v2 approve 鏈上失敗不落 DB / reject 僅改 DB / 已處理防重複。舊 hackathon 測試（需 docker DB、無法收集）隔離至 `tests/legacy/`。 · `backend/pytest.ini`, `backend/tests/integration/*`(新), `backend/tests/legacy/*`(移動)
- 2026-08-13 · [任務1 主題式 commit ✅] · 2026-07-12〜08-10 全部加固成果（80+ 修改、20+ 刪除、90+ 新檔）拆成 7 個主題 commit（chore 產物清理 / fix(contracts) / fix(backend) / feat(backend) / feat(mobile) / feat(dashboard) / docs），僅 commit 未 push。提交前驗證：`sui move build` 綠燈、`sui move test` **19/19 PASS**、後端 128 個 `.py` 全 py_compile 通過、秘密掃描無命中（`.env`/`*.local.dart` 均未入庫；`.DS_Store`、`mobile/.dart_tool/` 等已 `git rm --cached` 停止追蹤）。備註：`refund_service_v2._try_blockchain_refund`（create 路徑）仍會產生標記為 `pending_signature` 的 sha256 佔位 hash 回傳給呼叫端，雖未冒充成功但建議後續改為回傳待簽參數。 · 全 repo
- 2026-08-10 · [CLAUDE.md 過期 package id 更新（P3）] · 把 CLAUDE.md「關鍵事實」的 package 由過期 `0xa6232c…790380b` 改為現行加固版 `0xb761c6f5…e23f`（與 `.env` CONTRACT_PACKAGE_ID 一致），並註明舊值與 `Published.toml` 已過期勿引用。`Published.toml`（sui move 產生檔）待下次部署自動更新。檔案：`CLAUDE.md`, `docs/USER_ACTION_ITEMS.md`
  - 註：本輪 Bash 工具因 `/login` 後 CLI 進入需重裝狀態而失效，無法做 RPC 上鏈物件驗證；改做純文件工作。使用者需 `node node_modules/@anthropic-ai/claude-code/install.cjs` 或重開 session 修復。
- 2026-07-29 · [啟動閃退根因修復：Firebase 佔位符 API key] ·
  - 症狀：模擬器 build 成功但一啟動就 SIGABRT，Dart 無任何 log。
  - 根因（用 `~/Library/Logs/DiagnosticReports/Runner-*.ips` 崩潰報告定位）：`+[FIRInstallations validateAPIKey:]` 對格式不符的 key 丟**原生 NSException** → SIGABRT。`firebase_options.dart` 與 `GoogleService-Info.plist` 的 key 皆為佔位符 `YOUR_FIREBASE_API_KEY`（先前「移除已提交金鑰」commit 洗掉的）。原生例外 Dart try/catch 攔不到，故在 main() 印任何東西前就死。**非本次改動造成**。
  - 修法：`main.dart` 在呼叫 `Firebase.initializeApp` 前先檢查 `apiKey.startsWith('AIza')`，佔位符則跳過初始化（app 照常啟動，暫無 FCM 推播）。另在 main() 加 `FlutterError.onError` + 全域 try/catch 讓未來啟動例外會印出而非靜默閃退。
  - 驗證：`flutter run` 於 iPhone 16 Plus 模擬器**成功啟動**（Dart 執行、WebSocket 初始化、抓到 SUI 價格、自動以舊 session 登入）。殘留無害警告 `發送 FCM Token 失敗 [core/no-app]`（因跳過 Firebase，預期行為）。
  - 待使用者：要啟用推播 → 從 Firebase Console 下載真實 `GoogleService-Info.plist` + `flutterfire configure`（已補進 USER_ACTION_ITEMS）。
  - 檔案：`mobile/lib/main.dart`
- 2026-07-29 · [iOS build 修復 + zkLogin nonce 修正] ·
  - **build 阻擋錯誤**：`refund_service.dart` multipart 上傳把 `client.send()`（回 `StreamedResponse`）塞進只吃 `Future<Response>` 的 `_httpClient.executeRequest` → 型別不符。改用 `request.send()`（BaseRequest 自管 client）再 `Response.fromStream`。此為既有潛在 bug，Phase 7 把 RefundService 接進活樹後才被編譯到。（其餘 `SFAuthenticationSession`/`openURL` 全是 flutter_appauth iOS 端的 deprecation 警告，無害。）
  - **zkLogin nonce 正確性**：驗證 flutter_appauth 7.0.1 API 時發現有專用 `nonce:` 參數；原本用 `additionalParameters:{'nonce':…}` 可能被 AppAuth 自動產生的 nonce 覆蓋 → id_token 的 nonce 與 Enoki 不符 → 位址推導失敗。改用專用 `nonce:` 參數。
  - 另核對 `ed25519_edwards`/`pointycastle`/`flutter_appauth` 全部 API 與我的用法一致（generateKey/public/newKeyFromSeed/sign/.bytes、Blake2bDigest(digestSize:)/update/doFinal、authorizeAndExchangeCode/AuthorizationTokenRequest/idToken）。
  - 檔案：`mobile/lib/services/refund_service.dart`, `mobile/lib/services/zklogin_service.dart`
- 2026-07-29 · [Phase 9 假 ZKP proof 清除] ·
  - `did_service.dart`：移除 `generateAgeProof`/`generateLicenseProof`/`generateCommitment`——以 `sha256(did:isValid:timestamp)` 產出**可任意偽造的假 proof**（無零知識、無密碼學保證），且經查**零呼叫端**（dialog 實走 `generateAndVerifyAge/License` → 後端 `/identity/generate-*-proof`）。連帶移除變成死碼的 `dart:convert`、`package:crypto` import。
  - `zkp_service.dart` 查核為**真實後端呼叫**（`/zkp/generate-*-proof`），非假 proof，保留不動。
  - 真實方法（`generateAndVerifyAge/License`）與其 dialog 呼叫端未受影響。
  - 檔案：`mobile/lib/services/did_service.dart`
- 2026-07-29 · [Phase 9 舊付款死碼清除 + 使用者待辦單一清單] ·
  - 確認實際付款路徑：`passenger_home → PaymentPage → showOneClickPaymentDialog`（＝我 Phase 4 zkLogin 接的那個，在活路徑上✓）。舊 `payment_dialog.dart` 僅被 import、`showPaymentDialog` 從未被呼叫＝死碼（含零地址司機路徑）。
  - 刪 `mobile/lib/widgets/payment_dialog.dart`（零地址）+ `mobile/lib/services/sui_contract_service.dart`（僅被前者使用、且含過期 package `0xda64…`）；移除 `payment_page.dart` 的死 import。`sui_wallet_service` 仍被 `wallet_setup_page`（活）使用 → 保留。刪後無殘留引用。
  - **新增 `docs/USER_ACTION_ITEMS.md`**：把「需使用者本人操作」的事集中成單一清單（Enoki 贊助設定、Google consent、領測試幣、Maps key 限制、本機驗證、Published.toml/CLAUDE.md 過期 package）。之後使用者待辦都寫在此檔。
  - 檔案：刪 `mobile/lib/widgets/payment_dialog.dart`、`mobile/lib/services/sui_contract_service.dart`；改 `mobile/lib/payment_page.dart`；新 `docs/USER_ACTION_ITEMS.md`
- 2026-07-25 · [Phase 5 委託 + Phase 6 爭議 非託管簽名 scaffold（備置）] ·
  - 沿用 Phase 4 的 Enoki 贊助機制（這兩個動作不涉及 Coin，較單純）。
  - 後端：`zklogin_tx_service.py`（`issue_operator_cap`：agent=平台、額度/時效/動作白名單 RELEASE|REFUND、帶 Clock 0x6；`raise_dispute`：escrow shared obj + reason vector<u8>）；`api/v1/zklogin_actions.py`（`/agent/zklogin/delegate/{prepare,execute}`、`/disputes/zklogin/{prepare,execute}`，user 取自 JWT）。py_compile 通過、4 路由已註冊。
  - 前端：`ApiService` 加 delegate/dispute prepare+execute；`zklogin_action_service.dart`（共用 prepare→簽→execute 編排）；`delegation_page._authorize` 接真實 delegate（預設 1 SUI/筆、5 SUI/日、30 天、放款+退款）→ recordDelegation；`trip_in_progress_page` 加「回報爭議」按鈕 + `_raiseDispute`（簽 raise_dispute → 凍結 → reportDisputeObject → UI 轉 disputed）。
  - 待驗證同 Phase 4（Enoki sponsor 設定 + 實機簽名格式）。
  - 檔案：`backend/app/services/zklogin_tx_service.py`(新), `backend/app/api/v1/zklogin_actions.py`(新), `backend/app/main.py`, `mobile/lib/services/{api_service,zklogin_action_service}.dart`, `mobile/lib/pages/{delegation_page,trip_in_progress_page}.dart`
- 2026-07-24 · [Phase 4 非託管付款 scaffold（備置，待實機+Enoki portal 驗證）] ·
  - 架構決策：pysui 0.65 無 zkLogin 簽名組裝 → 採 Enoki 贊助交易（Enoki 組 zkLogin 簽名+送鏈）。
  - 後端：`payment_zklogin_service.py`（挑乘客 coin → pysui split_coin+move_call lock_payment → serialize kind bytes → Enoki sponsor → execute → 解析 escrow id）；`api/v1/payments_zklogin.py`（`POST /payments/zklogin/prepare`、`/execute`，passenger 取自 app JWT 不由前端傳）。py_compile 通過、路由已註冊、backend healthy。
  - 前端：`zklogin_service.signSuiTransactionBytes`（blake2b256(intent ++ bytes) + flag||sig||pubkey，加 pointycastle）；`zklogin_payment_service.dart`（prepare→sign→execute 編排）；`ApiService.preparePayment/executePayment`；`one_click_payment_dialog` 改走 zkLogin 為主、operator 代簽為後備，**移除偽造 hash 的 mock fallback**（遵守 CLAUDE.md，失敗即拋錯）。
  - ⚠️ 未驗證（需你）：Enoki portal 需設 **sponsor 資金 + allowedMoveCallTargets**；pysui `serialize()` 產出的 kind bytes、Enoki execute 接受「臨時簽名 vs 已組裝 zkLogin 簽名」需以真實 JWT + 已領測試幣的 zkLogin 位址實機測。
  - 檔案：`backend/app/services/payment_zklogin_service.py`(新), `backend/app/api/v1/payments_zklogin.py`(新), `backend/app/main.py`, `mobile/lib/services/{zklogin_service,zklogin_payment_service}.dart`, `mobile/lib/services/api_service.dart`, `mobile/lib/widgets/one_click_payment_dialog.dart`, `mobile/pubspec.yaml`
- 2026-07-24 · [後端 directions 韌性 + Phase 9 死碼刪除] ·
  - 後端 `directions_service.py`：支援選填 `BACKEND_GOOGLE_MAPS_API_KEY`（伺服器 IP 限制專用，未設則沿用 `GOOGLE_MAPS_API_KEY`）；`REQUEST_DENIED` 改為「只警告一次」並說明成因（前端 key 若為 iOS 限制，後端會被拒），避免每次請求洗版 error。直線 fallback 原本就有，功能不受影響。py_compile 通過、backend healthy。
  - 刪除 3 個經精確查證無引用的死碼檔：`services/old_iota_wallet_service.dart`（IOTA 遺留，CLAUDE.md 已載明 IOTA 為死碼）、`services/wallet_connect_service.dart`（import 已從 pubspec 移除的 `walletconnect_flutter_v2`，屬 build 地雷）、`driver_home_page.dart`（587 行舊版，`/driver` 已改用 `DriverHomePageNew`）。皆確認無敏感金鑰、刪後無殘留引用。
  - 保留仍在路由使用的 `payment_page`/`wallet_setup_page`/`sui_*_service`（待 Phase 4 zkLogin 付款上線再處理）。
  - 檔案：`backend/app/services/directions_service.py`, `.env`(選填註解), 刪 `mobile/lib/services/old_iota_wallet_service.dart`, `mobile/lib/services/wallet_connect_service.dart`, `mobile/lib/driver_home_page.dart`
- 2026-07-24 · [Google Maps 金鑰輪替（存本地）+ iOS App 限制相容 header] ·
  - 新 key 只寫入 gitignored 檔（`google_maps_config.local.dart` + `.env`），四道防外洩檢查全過（tracked/staged/untracked 皆 0 命中）。舊失效 key 已換掉。
  - 新 key 為「有效但有 iOS App 限制」。因本專案以 http 直打 REST（非原生 SDK），預設不帶 bundle id → 會被 GCP 拒。於 `GoogleMapsConfig` 加 `iosBundleId` + `restrictionHeaders`（`X-Ios-Bundle-Identifier: com.example.projectDapp`），並補進全部 6 個 Google 呼叫點：Directions、Places(autocomplete/details/geocode)、Street View(metadata + Image.network)。
  - 注意：此 header 可被偽造，僅屬弱防護；真正防線是 API 限制 + 配額。後端 `directions_service.py` 由伺服器 IP 呼叫、不帶此 header，若 key 為 iOS 限制則後端該呼叫會被拒（現有直線 fallback 可承接），如需後端正常應另配 IP 限制的 key。
  - 檔案：`mobile/lib/config/google_maps_config.dart`, `mobile/lib/services/google_directions_service.dart`, `mobile/lib/services/google_places_service.dart`, `mobile/lib/widgets/street_view_image.dart`
- 2026-07-24 · [Phase 9 部分：Google Maps 金鑰單一來源 + 洩漏金鑰移除] ·
  - 診斷：`.env` 與程式內的 Google Maps key `AIzaSyB0mx…` 已失效（Directions/Geocoding 實測 `REQUEST_DENIED: API key is invalid`）——與先前「remove committed Google API keys」commit 吻合，key 應已在 GCP 撤銷。
  - `google_directions_service.dart` 原本**硬編碼**該金鑰（tracked 檔＝已洩漏），改為 `GoogleMapsConfig.apiKey` 單一來源。`google_places_service.dart` 本就用 config。自此所有 Google API 消費者（Directions＋Places）只讀 `google_maps_config.local.dart`（gitignored）一處。
  - 失效影響：路線繪製（Directions）＋地址自動完成（Places）失效；地圖圖磚走 OSM(flutter_map) 不受影響。使用者需在 GCP 建新 key（啟用 Directions/Places API）填入 `google_maps_config.local.dart`。
  - ⚠️ **重要修正**：Phase 9 原列為死碼的 `payment_page`/`wallet_setup_page`/`sui_contract_service`/`sui_wallet_service` 經查**仍被路由使用**（`/payment`、`/wallet/setup`、passenger_home/order_center），是**現行**付款流程。應待 Phase 4 zkLogin 付款上線後才移除，現在刪會使 app 無付款路徑。故本輪不刪。
  - 檔案：`mobile/lib/services/google_directions_service.dart`
- 2026-07-24 · [Phase 7 退款 UI 整併完成 + Enoki provider 驗證] ·
  - **Enoki Google provider 已生效**（實測 `/v1/app` 回傳 `providerType: google` + 相符 client id）；zkLogin 伺服端關卡全部就緒，待本機 flutter run 實測登入。
  - **退款單一路徑**：盤點發現 `lib/pages/trip_history_page.dart`（698 行）為 orphan（無人 import），實際使用的是 root `lib/trip_history_page.dart`（514 行，被 main/兩個 home/driver 頁引用）。將 active 頁退款由 `ApiService.createRefundRequest`（form-urlencoded）改走 `RefundService.createRefundRequest`（multipart，支援佐證檔）並加 token 守衛；刪除 orphan 頁；移除 `ApiService.createRefundRequest` 重複方法。退款自此單一路徑。
  - 檔案：`mobile/lib/trip_history_page.dart`, `mobile/lib/services/api_service.dart`, 刪 `mobile/lib/pages/trip_history_page.dart`
- 2026-07-24 · [Phase 3 狀態機 UI 完成] · `trip_in_progress_page`。
  - 兩個 inline 狀態 Container 改用設計系統 `StatusPill.trip(_status)` / `StatusPill.payment(...)`；支付狀態優先讀後端 `payment_status` enum，缺則以 escrow 回推。
  - 按鈕 switch 補 `disputed`（爭議凍結、停用動作、AppColors.warning）/`completed`/`cancelled` 分支（原本 completed 誤落 default「未知狀態」）；爭議中隱藏「取消行程」（escrow 已凍結）。
  - 移除已無用的 `_getStatusText`/`_getStatusColor`（disputed 顯示由 StatusPill 提供）。
  - 檔案：`mobile/lib/pages/trip_in_progress_page.dart`
- 2026-07-24 · [zkLogin iOS 原生設定 + Phase 9 packageId 統一] ·
  - **packageId 統一**：RPC 查證三個散落 package，只有 `0xb761c6f5…e23f` 具 dispute 函式（加固版）。於 `mobile/lib/config/app_config.dart` 設 `contractPackageId`/`platformAddress` 為單一事實來源；舊 `0xa6232c…380b`/`0xda64…542f` 標為死值。⚠️ `contracts/Published.toml`＋`CLAUDE.md` 仍指向過期 package，待更新。
  - **iOS OAuth 回跳**：`ios/Runner/Info.plist` 加 google-oauth 的 `CFBundleURLScheme`（佔位待填反向 client id）。專案只含 ios+web（無 android）。
  - **設定清單**：新增 `docs/ZKLOGIN_SETUP.md`（Google Cloud + Enoki + 4 處填值 + 驗證步驟）。Bundle ID = `com.example.projectDapp`。
  - 檔案：`mobile/lib/config/app_config.dart`, `mobile/ios/Runner/Info.plist`, `docs/ZKLOGIN_SETUP.md`
- 2026-07-18 · [Phase 0 zkLogin 地基打通 ✅（spike 去風險完成）] · Enoki public key 已接。
  - **Phase 0a spike 成功**：真實臨時 ed25519 金鑰 → Enoki nonce 端到端回傳有效 nonce/randomness/maxEpoch（直打 Enoki 200 + 後端 proxy `/auth/zklogin/nonce` 200）。技術可行性確認，zkLogin 路線成立。
  - **0b 後端**：`ENOKI_API_KEY`（public key）寫入 `.env`，backend 容器 recreate 載入成功；nonce 端點由 503→200。
  - **0c Flutter**：新增 `services/zklogin_service.dart`（產臨時金鑰→nonce→AppAuth Google OAuth 注入 nonce→backend login→UserSession；含 `signDigest` 供 Phase 4/5/6）；`login_page.dart` 加「用 Google 登入（免助記詞）」按鈕+handler；`pubspec.yaml` 加 `flutter_appauth`/`ed25519_edwards`；`app_config.dart`(+local) 加 `googleOAuthClientId`/`redirectUrl`。
  - **唯一剩餘卡點**：需在 Google Cloud 建 OAuth Client、並在 Enoki Portal 把該 client id 註冊為 Google Auth Provider（目前 `authenticationProviders: []`），再填 `GOOGLE_OAUTH_CLIENT_ID`（.env）+ Flutter `localGoogleOAuthClientId`/`RedirectUrl`。填好即端到端可登入。
  - 檔案：`.env`, `mobile/lib/services/zklogin_service.dart`(新), `mobile/lib/login_page.dart`, `mobile/lib/config/app_config{,.local}.dart`, `mobile/pubspec.yaml`
- 2026-07-16 · [前端 Phase 3 + 5 UI（Flutter，待本機 build 驗證）] · 狀態機 + 委託 UI。
  - Phase 3：`trip_in_progress_page` 加 `in_progress` 分支（`_updateTripStatus` 呼叫 `startTrip`）；司機 `picked_up` 按鈕改為「開始行程」→ in_progress，`in_progress` 才是「完成行程並收款」（讓 in_progress 真正被使用）。
  - Phase 5：新增 `pages/delegation_page.dart`（委託狀態查詢 + 撤銷已可運作；「授權」為 zkLogin 簽名整合點）+ `/delegation` 路由。
  - 檔案：`mobile/lib/pages/{trip_in_progress_page,delegation_page}.dart`, `mobile/lib/main.dart`
- 2026-07-16 · [前端 Phase 1 + 2（Flutter，待本機 build 驗證）] · **設計系統 + API 擴充**。
  - Phase 1：新增 `mobile/lib/theme/app_theme.dart`（`AppColors` + `AppTheme.dark()` 集中主題 + `StatusPill` 狀態徽章，含 payment/trip 工廠建構子）；`main.dart` 改用 `AppTheme.dark()` 取代 inline ThemeData。
  - Phase 2：`api_service.dart` 加 zkLogin（nonce/login/zkp）、`startTrip`、`raiseDispute`/`reportDisputeObject`、`recordDelegation`/`getDelegation`/`revokeDelegation`；`refund_service.dart` 硬編碼 IP 改用 `AppConfig.backendUrl`。
  - ⚠️ 此環境無 Flutter，未 build；需使用者本機 `flutter build` 驗證。
  - 檔案：`mobile/lib/theme/app_theme.dart`(新), `mobile/lib/main.dart`, `mobile/lib/services/{api_service,refund_service}.dart`
- 2026-07-16 · [前端 Phase 0b + 8] · **zkLogin 後端基礎 + Dashboard admin**。
  - Phase 0b（後端 zkLogin，Enoki）：新增 `zklogin_service.py`（封裝 Enoki nonce/位址/ZKP/贊助/送鏈）+ `/api/v1/auth/zklogin/{nonce,login,zkp}`（`login` 以 zkLogin 位址 upsert 使用者、發 app JWT，無私鑰）；config 加 `ENOKI_*`。live backend 註冊、fail-safe（無 key 回 503）驗證通過。**需使用者提供 Enoki API key + Google OAuth client 才能上線。**
  - Phase 8（React dashboard）：新增**爭議仲裁**頁（列 disputed 行程 → `/trips/{id}/resolve-dispute` ruling 判司機/退乘客）；`RefundManagement` 加**鏈上退款核准/拒絕**（`/refunds/{id}/approve|reject`，真 admin_refund_from_pool）；`api.js` 加 `/api/v1` 實例 + `disputeAPI`/`refundChainAPI`；路由 `/disputes` + Header 導覽。**`npm run build` 成功（2274 modules）。**
  - 檔案：`backend/app/services/zklogin_service.py`(新), `backend/app/api/v1/auth.py`, `backend/app/{config,main}.py`, `dashboard/src/pages/DisputeManagement.jsx`(新), `dashboard/src/services/api.js`, `dashboard/src/App.jsx`, `dashboard/src/components/Header.jsx`, `dashboard/src/pages/RefundManagement.jsx`

- 2026-07-14 · [Phase 5 收尾] · **狀態機四項收尾（問題 5/7/8/9）**。問題 7：新增 `start_trip` + `PUT /trips/{id}/start`（picked_up→in_progress，讓死狀態被真正使用）。問題 5：`/escrow-payment` 模擬分支收斂到僅 `MOCK_MODE`；正式路徑改回傳乘客要簽的真實 `lock_payment` 參數。問題 9：主流程統一為非託管（乘客自簽 lock），`payment_proxy /process-payment` 標為後備。問題 8：新增 `PaymentStatus` enum（pending/locked/released/refunded/failed），把 `confirmed`/`completed` 收斂為 `locked`。全 py_compile 通過、live backend 熱重載註冊 /start 無錯。**狀態機修復計畫 9 個問題全數完成。** · `backend/app/services/trip_service.py`, `backend/app/api/v1/{trips,payment_proxy}.py`, `backend/app/schemas/trip.py`, `backend/app/models/ride.py`
- 2026-07-14 · [Phase 2c+3 + bug] · **取消退款/完成放款接上 Agent 委託**。`trip_service.complete_trip` 放款、`cancel_trip` 退款/放款一律優先走 `agent_service.*_via_agent`（用 `delegation_service.get_active_cap` 取乘客 OperatorCap），無委託才退回舊路徑；**停止吞例外**，失敗以 error 記錄並反映到 `payment_status`。修復 `auto_upgrade_waiting_trips` 的時區 bug（naive `utcnow()` 減 tz-aware `requested_at`）→ 改 tz-aware 並補正 naive，live log 確認 0 錯誤、任務正常升級。 · `backend/app/services/trip_service.py`
- 2026-07-14 · [Phase 4b + Phase 1 + 環境] · **爭議後端 + Agent 委託基礎 + 整體 stack 接上**。
  - Phase 4b：`TripStatus.DISPUTED`、`migrations/006`、`dispute_service.py`、`POST /trips/{id}/dispute`·`/dispute/report`·`/resolve-dispute`（admin）。鏈上確認 `raise_dispute`/`resolve_dispute` 已部署。
  - Phase 1：`OperatorDelegation` 模型 + `migrations/005` + `delegation_service.py`（上鏈驗證 cap 屬平台 agent、解析額度/時效）+ `POST/GET/DELETE /agent/delegation`。**實測**：鏈上簽發 OperatorCap，欄位與服務解析一致。
  - Bug 修復：`sui_client` 改用 `SuiConfig.user_config`（原本 `SuiConfig.testnet()` 在 pysui 0.65 不存在，導致啟動報錯）→ log 顯示初始化成功。
  - 環境：Docker 全開；DB 套用 migration 003/004/005/006；backend `up -d --force-recreate` 讀到新 `.env`（新 package `0xb761c6f5…`/pool/ArbiterCap），熱重載載入所有新端點，`Application startup complete` 無錯。
  - 待辦：行動端用戶用 Slush 簽 `issue_operator_cap` 並回報 cap id（需 Flutter）；`trip_service` 自動升級的時區 bug（既有，非本次）。
  - 檔案：`backend/app/{models/delegation.py, services/{dispute_service,delegation_service}.py, api/v1/{agent.py, trips.py}, schemas/trip.py, models/ride.py, models/__init__.py, main.py, services/sui_client.py, config.py}`, `backend/migrations/00{5,6}_*.sql`
- 2026-07-14 · [狀態機修復 P2a/2b/4] · **退款串接 + 鏈上爭議仲裁**。合約：`refund_module_v2` 加 `admin_refund_from_pool`（平台以 RefundCapability 直接退款，免 per-request 物件）；`payment_escrow` 加 `disputed` 凍結欄位 + `ArbiterCap` + `raise_dispute`/`resolve_dispute`（判司機 release／退乘客 refund）。後端：`RefundServiceV2` 補 `approve_and_execute_refund`/`reject_refund`（修 AttributeError + 真上鏈）；`sui_service` 加 `call_contract_admin_refund`/`call_contract_resolve_dispute`。`sui move test` **19/19 PASS**。**重新部署 testnet**（新 package `0xb761c6f5…7e23f`，已回填 `.env`），並**端到端驗證**：注資退款池 0.2 SUI → admin 退款 0.05 SUI 成功（池餘額/total_refunded 鏈上確認）。新增 `scripts/ops/fund_refund_pool.sh`。 · `contracts/sources/financial/{refund_module_v2,payment_escrow}.move`, `backend/app/services/{refund_service_v2,sui_service}.py`, `.env`, `scripts/ops/`
- 2026-07-14 · [deploy] · **強化後合約部署上 testnet**。新 package `0x9d46bb749625bfe72d84055296ec3958974f049b91878d1e790361205144065e`（取代舊 `0xa6232c…`）。已回填 `.env`：package/UserRegistry/VehicleRegistry/DIDRegistry/CredentialRegistry/TrustedIssuers/RefundPool + 平台 cap（CredentialAdminCap/RefundCapability/RatingAdminCap）。鏈上驗證：package 存在、CredentialRegistry 為 Shared 物件（init 已執行）。RPC 改用 `sui-testnet-rpc.publicnode.com`（`fullnode.testnet.sui.io` 從本環境回 404）。 · `.env`

> 格式：`YYYY-MM-DD · [工作包代號] · 摘要 · 影響檔案`。最新在上。

- 2026-07-12 · [docs] · 更新專案面向文件至現況：`README.md`（改 ChainSUI/Agentic Web，補 Agent 委託/Walrus/ZKP/安全測試/部署腳本）、`PROJECT_OVERVIEW.md`（修正合約模組清單、環境變數、狀態）、根 `.env.example`（補 Sui/Agent/Walrus 必填變數）。 · `README.md`, `PROJECT_OVERVIEW.md`, `.env.example`
- 2026-07-12 · [F1] · **PTB 複合原子結算**。新增 `payment_escrow::release_and_receipt_by_agent`：Agent 一次交易同時釋放託管給司機/平台並開立行程收據給乘客（原子性 + 省 gas）；`trip_receipt::create_receipt_for` 抽出供跨模組複合呼叫。新增測試 `test_agent_settle_and_receipt_atomic`。`sui move test` = 13/13 PASS。 · `contracts/sources/financial/payment_escrow.move`, `contracts/sources/business/trip_receipt.move`, `contracts/tests/security_tests.move`
- 2026-07-12 · [G1-擴充] · Move 安全測試由 9 增至 **12（全 PASS）**：新增 Agent 動作白名單（release 用 refund-only cap 被拒）、cap 時效（過期後拒）、DID 內嵌位址與 controller 不符被拒。 · `contracts/tests/security_tests.move`
- 2026-07-12 · [ops] · 部署與環境輔助：重寫 `backend/.env.example`（對齊新 `config.py`：Sui/Walrus/CORS/fail-fast 機密，移除 IOTA 殘留）；新增 `scripts/ops/deploy_and_init.sh`（一鍵發布合約並擷取 registry/pool/cap 的 object ID）。 · `backend/.env.example`, `scripts/ops/deploy_and_init.sh`
- 2026-07-12 · [E3-評價/退款] · **Walrus 三路徑完成**。評價：`rating_service.create_rating` 上傳標準化評論到 Walrus（內容 SHA256 == rating_hash），存 `content_blob_id`（+ `migrations/003_add_rating_content_blob.sql` + `VehicleRating.content_blob_id`）。退款佐證：`refunds.py` 由單節點 IPFS 改走 Walrus（`blob_id`→evidence_cid、內容 hash→evidence_hash），移除 ipfs_service import。全部 py_compile 通過。 · `backend/app/services/rating_service.py`, `backend/app/models/rating.py`, `backend/migrations/003_add_rating_content_blob.sql`, `backend/app/api/v1/refunds.py`
- 2026-07-12 · [D2-核心] · **Agent 鏈上代理層**。新增 `agent_service.py`：Agent 以 `OPERATOR_PRIVATE_KEY` 簽章、持乘客 `OperatorCap` 呼叫 `payment_escrow::release_payment_by_agent`/`refund_payment_by_agent`（pysui SyncTransaction + `0x6` clock），鏡射既有 `sui_service` 寫法，鏈上失敗明確報錯。py_compile 通過。剩餘：per-user cap 發現 + 接進 `complete_trip`。 · `backend/app/services/agent_service.py`(新)
- 2026-07-12 · [E3-軌跡] · **GPS 軌跡 → Walrus → 鏈上錨定迴圈接通**。新增 `trajectory_service.py`；`websocket/events.py` 累積每趟 GPS；`trip_service.complete_trip` 結束時上傳 Walrus 並把 blob_id+hash 傳入收據；修正 `escrow_service.create_trip_receipt` 簽名對齊新的 `create_receipt`（8 參數）。全部 py_compile 通過。 · `backend/app/services/{trajectory_service,escrow_service,trip_service}.py`, `backend/app/websocket/events.py`
- 2026-07-12 · [F2/G1] · **死碼清理 + Move 安全測試**。刪除 7 個 0-byte 空 module source、17 個空/IOTA 舊測試檔與 `run_tests.sh`；新增 `tests/security_tests.move`（9 tests：託管乘客釋放/非授權拒絕/退款、Agent cap 有效釋放/超額拒絕/撤銷拒絕、評價綁行程成功/trip 不符拒絕、reputation 非 admin 拒絕）。`sui move test` = 9 passed / 0 failed。為測試加 `rating_proof` test-only cap 建構子。 · `contracts/tests/security_tests.move`(新), `contracts/sources/business/rating_proof.move`, 刪除多個空檔
- 2026-07-12 · [E1/E2] · **Walrus 基礎（儲存層 + 鏈上錨定）**。新增 `walrus_service.py`（Walrus publisher/aggregator HTTP client，含重試與 content-hash 校驗）；`config.py` 加 `WALRUS_*` 設定；Move `TripReceipt` 加 `trajectory_blob_id/trajectory_hash`、`RatingProof` 加 `content_blob_id`，`create_receipt`/`create_rating_proof` 簽名同步更新，`sui move build` 綠燈。⚠️ 後端 `escrow_service.create_trip_receipt` 呼叫 `create_receipt` 的引數需在 E3 補上兩個新參數。 · `backend/app/services/walrus_service.py`(新), `backend/app/config.py`, `contracts/sources/business/{trip_receipt,rating_proof}.move`
- 2026-07-12 · [C2-backend] · **移除所有後端可偽造的 ZKP 模擬路徑**（`zkp_prover._simulate_proof`、`zkp_verifier._simulate_verification`、`identity_service._simulate_zkp_verification` 全部刪除，缺 key/無效 proof 一律 fail-closed）。**額外發現並修復免費搭車漏洞**：`trips.py` verify-payment 的模擬付款原本任何用戶送 `0xtx...` 即標記已付款，改為只在 `MOCK_MODE` 生效。 · `backend/app/services/{zkp_prover,zkp_verifier,identity_service}.py`, `backend/app/api/v1/trips.py`
- 2026-07-12 · [B1/B2] · **後端 P0 安全加固**。`config.py` 改 fail-fast 並移除弱預設（SECRET_KEY/DATABASE_URL/帳密不再有可用預設）；`wallet_service` salt 改 `os.urandom`；`main.py` CORS 與 Socket.IO 由 `*` 收斂為 `CORS_ALLOW_ORIGINS` 白名單；`sui_service.call_contract_release_payment` 與 `escrow_service.refund_payment` 移除「失敗即回假 hash」的偽成功；`refunds.py` approve/reject 還原 `get_current_admin` 驗證。真實鏈上交易串接留待 P1 D2。 · `backend/app/{config,main}.py`, `backend/app/services/{wallet_service,sui_service,escrow_service}.py`, `backend/app/api/v1/refunds.py`
- 2026-07-12 · [A1–A4/C1/D1] · **P0 合約層安全修復完成，`sui move build` 綠燈**。新增 `agent/agent_registry.move`（OperatorCap 委託）；`payment_escrow` 釋放改需乘客簽章或 OperatorCap、消費刪除 Escrow、費率鏈上計算；`refund_module_v2` 刪除無授權掏空路徑；`user_registry`/`vehicle_registry` 統計改共享物件+admin 把關；`rating_proof` 評價綁定 TripReceipt+RatingAdminCap；`credential_verifier` 改 `sui::groth16` 真驗證+CredentialAdminCap；`did_registry` 位址綁定+存在檢查。相依釘 `testnet-v1.53.2`。 · `contracts/sources/{agent/agent_registry,financial/payment_escrow,financial/refund_module_v2,identity/user_registry,identity/vehicle_registry,identity/credential_verifier,identity/did_registry,business/rating_proof,business/trip_receipt}.move`, `contracts/Move.toml`
- 2026-07-12 · [init] · 建立本路線圖與 `CLAUDE.md`；完成 P0/P1/P2 審查與規格 · `docs/PRODUCTION_HARDENING_ROADMAP.md`, `CLAUDE.md`
