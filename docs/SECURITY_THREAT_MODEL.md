# ChainSUI — 安全威脅模型與 ZK 身份藍圖（進度）

> 這是「生產加固」之後的**第二層**安全工作：ZK 身份、Agent 邊界、去中心化隱私。
> 第一層見 [`PRODUCTION_HARDENING_ROADMAP.md`](PRODUCTION_HARDENING_ROADMAP.md)（合約/後端加固，`sui move test` 13/13）。
> 完整四模組架構藍圖（zkLogin + Reclaim zkTLS + Move 狀態防護 + Agent 護欄 + Walrus 加密）已與擁有者確認。

**已鎖定決策**：登入走 **zkLogin 為主 + Slush 錢包為進階**；資格憑證走 **zkTLS 預言機（Reclaim/Primus）驗真實來源**。

## 威脅清單（STRIDE）與修補狀態

| # | 威脅 | 嚴重度 | 狀態 |
|---|---|---|---|
| T1 | 憑證自我聲明，未成年可謊報成年 | 🔴 Critical | ⬜ P1-1（Reclaim zkTLS） |
| T2 | ZKP 私有輸入（生日/駕照號）明文送後端 | 🔴 Critical | ⬜ P1-1（客戶端產證） |
| T3 | ZKP 重放：後端未做 commitment 去重、commitment 可預測 | 🔴 Critical | 🟡 **P0-3 核心完成**（commitment 綁定 + DB 一次性去重；鏈上強制與 mobile 端改法待接） |
| T4 | Walrus 明文 PII（軌跡/評價）上公網 | 🔴 Critical | 🟡 **P0-2 核心完成**（envelope 加密，軌跡已強制加密；評價/退款 + 金鑰派送待接） |
| T5 | `/process-payment` 無認證觸發平台付 gas 鏈上交易 | 🔴 Critical | ✅ **P0-1 完成** |
| T6 | 全站無 rate limiting → 經濟型 DoS | 🟠 High | ✅ **P0-1 完成**（已導入限流） |
| T7 | zkLogin User Salt 外洩 → 位址被接管 | 🟠 High | ⬜ P1-2（salt 服務職責分離） |
| T8 | 未來 AutoGen 被 Prompt Injection（如 0 元車資） | 🟠 High | 🟡 **P2-2 完成**（結構化 action 護欄；AutoGen 接線待其導入） |
| T9 | credential_verifier 無界 Table griefing | 🟡 Medium | 🟡 **P1-3 完成**（身分狀態改 owned soulbound Profile；used_commitments 修剪待接） |
| T10 | 平台費率不一致（0% vs 10%） | 🟡 Medium | ✅ **P2-1 完成**（費率單一事實來源 + 車資地板）|

## 修補優先序
P0-1（認證+限流）✅ → P0-2（Walrus 加密）→ P0-3（ZKP 重放鏈上強制）→ P1-1（Reclaim zkTLS）→ P1-2（zkLogin+salt）→ P1-3（Profile 物件）→ P2-1（費率/車資地板）→ P2-2（AutoGen 護欄）→ P2-3（secret manager/CI 掃描）。

## 變更日誌
- 2026-07-13 · **[P2-2] 完成**：Agent 結構化護欄（威脅 T8，為 AutoGen 預備）。
  - 新增 `backend/app/core/agent_guardrails.py`：`validate_action` 強型別驗證 LLM 產出的動作——action 白名單、須在 OperatorCap bitmask 內、金額 >0 且 ≤ 單筆/每日 cap、物件 id 良構、對象須屬該用戶。**單元測試通過**（未知動作/越權/0或負/超額/跨用戶/自由文字注入/畸形 id/非整數 全部被拒）。
  - `agent_service` 送鏈前加 object-id 良構檢查（defense-in-depth）。
  - 設計要旨：即使 LLM 完全被注入，護欄 + 鏈上 OperatorCap 數值邊界雙重封頂，動不了越權/超額。
  - 檔案：`backend/app/core/agent_guardrails.py`(新), `backend/app/services/agent_service.py`
- 2026-07-13 · **[P2-1] 完成**：費率單一事實來源 + 車資地板（威脅 T10）。
  - `payment_escrow::lock_payment` 加 `MIN_PAYMENT_MIST`（0.001 SUI）車資地板，拒絕 0 元/塵埃金額。
  - 移除後端 `payment_proxy` 的 10% 自算與 `sui_service` move_call 的 `platform_fee` 引數 → 平台費只由合約 `PLATFORM_FEE_RATE`（2.5%）計算，杜絕鏈上/鏈下不一致。
  - 測試金額同步調整；`sui move test` = **14/14 PASS**；後端 py_compile 通過。
  - 檔案：`contracts/sources/financial/payment_escrow.move`, `contracts/tests/security_tests.move`, `backend/app/services/sui_service.py`, `backend/app/api/v1/payment_proxy.py`
- 2026-07-13 · **[P1-3] 完成**：不可轉讓（soulbound）身分 Profile 物件（威脅 T1/T9）。
  - 新增 `contracts/sources/identity/profile.move`：`PassengerProfile`/`DriverProfile`（`key` only → soulbound、無轉移函式）；`is_adult`/`has_valid_license` 的 setter 為 `public(package)`（非 public/entry，外部套件與原生交易無法呼叫）→ 只有同套件的 `credential_verifier` 於 groth16 驗證後設定。Agent 的 OperatorCap 亦無觸及 Profile 的動作 → 身分狀態不可被越權竄改。
  - `credential_verifier::verify_age_credential`/`verify_license_credential` 接受使用者自己的 Profile（斷言 owner==sender），驗證通過即設 flag（只存 boolean + commitment，無明文）。
  - 身分狀態改為 owned 物件（非 shared registry 巨型 Table）→ 降低 Shared Object griefing 面（T9）。
  - **`sui move test` = 14/14 PASS**（新增 `test_passenger_profile_defaults_and_gated_setter`）。
  - 檔案：`contracts/sources/identity/profile.move`(新), `contracts/sources/identity/credential_verifier.move`, `contracts/tests/security_tests.move`
- 2026-07-12 · **[P0-3] 核心完成**：ZKP 重放防禦（威脅 T3）。
  - 新增 `backend/app/core/commitment.py`：commitment 由 `SHA256(DOMAIN ∥ 位址 ∥ 類型 ∥ proof_id ∥ 一次性 nonce)` 派生，取代可預測的 `sha256(did:type:timestamp)`。**單元測試通過**：決定性、位址/類型/proof/nonce 皆綁定、格式健檢。
  - `UserCredential` 加**唯一 `nullifier`** 欄位（+ `migrations/004_add_credential_nullifier.sql`）。
  - `identity_service` 新增 `_consume_commitment`：格式健檢 + 原子性唯一約束去重（重複 INSERT 撞唯一索引 → IntegrityError → 判定重放並拒），接進 age/license 兩條驗證成功路徑。
  - 剩餘：mobile `did_service.dart` 改送 nonce+要素讓後端派生 commitment；後端真正送鏈讓 `credential_verifier::used_commitments` 成為最終強制點（需部署，可鏡射 `agent_service` 的 pysui 寫法）。
  - 檔案：`backend/app/core/commitment.py`(新), `backend/app/models/credential.py`, `backend/migrations/004_add_credential_nullifier.sql`, `backend/app/services/identity_service.py`
- 2026-07-12 · **[P0-2] 核心完成**：Walrus 存前 envelope 加密（威脅 T4），消除明文 PII 上公網。
  - 新增 `backend/app/core/envelope.py`：每 blob 隨機 DEK + AES-256-GCM 加密內容；DEK 以 sealed-box（X25519 ephemeral ECDH → HKDF → AES-GCM）包給每個收件者公鑰。
  - `walrus_service` 新增 `store_encrypted`/`read_encrypted`（Walrus 只存密文，鏈上錨定**密文** SHA256）。
  - `trajectory_service.flush_to_walrus` 改**強制加密**：缺收件者金鑰即不上傳（fail-safe，拒絕明文 GPS 上公網）。
  - **功能驗證通過**（隔離 venv 實測）：授權者可解、第三方不可解、AAD 竄改被 GCM 拒、密文不含明文。
  - 剩餘：評價/退款佐證走加密路徑、為每用戶派送 X25519 加密金鑰、把 `nonce`/`wrapped_deks` 存 DB；生產可升級為 **Sui Seal**（介面已設計為可替換）。
  - 檔案：`backend/app/core/envelope.py`(新), `backend/app/services/{walrus_service,trajectory_service}.py`
- 2026-07-12 · **[P0-1] 完成**：匿名昂貴端點補認證 + 導入限流（威脅 T5/T6）。
  - 新增 `backend/app/core/rate_limit.py`：無新相依的記憶體滑動視窗限流器（FastAPI 依賴 `rate_limit(times, seconds, scope)`；多實例部署再換 Redis）。
  - `payment_proxy /process-payment`：加 `get_current_user` + **行程須屬呼叫者**（`trip.user_id==current_user.id`）+ 限流（60s/5 次）。
  - `payment_proxy /temp-escrow-address`：加認證 + 限流（原本匿名洩漏平台錢包位址）。
  - `wallet /create`：加限流（5min/5 次，防金鑰生成濫用；註冊前流程故不強制認證）。
  - `trips /estimate`：加限流（60s/20 次，匿名觸發 CoinGecko+DB）。
  - `trips /{id}/route`（Google Maps 計費）、`refunds /create`（Walrus 上傳）：加限流。
  - 驗證：5 個後端檔 py_compile 通過。
  - 檔案：`backend/app/core/rate_limit.py`(新), `backend/app/api/v1/{payment_proxy,wallet,trips,refunds}.py`
