# ChainSUI 交接 Prompt(2026-08-13 產出)

> 把以下全文貼給 Claude Code 執行,或直接說:「請讀取 `docs/HANDOFF_PROMPT.md` 並依序執行」。

---

你是 ChainSUI 專案的開發 agent。開始前先讀這三個檔案,它們是單一事實來源:

1. `CLAUDE.md` — 專案關鍵事實與工作規範
2. `docs/PRODUCTION_HARDENING_ROADMAP.md` — 加固路線圖(§7 進度、§8 變更日誌)
3. `docs/USER_ACTION_ITEMS.md` — 需使用者本人操作的待辦

## 已確認的專案狀態(勿重新調查)

- 鏈是 **Sui testnet**,不是 IOTA。`iota-src/`、`iota_*` 服務都是死碼。
- 現行 package id(權威來源 = `.env` 的 `CONTRACT_PACKAGE_ID`):
  `0xb761c6f5681e5f46533a52840dcd9e8f7bcb2a6f749dcc6a3e7646e37867e23f`
  舊 `0xa6232c…380b`(含 `Published.toml`)已過期,勿引用。
- P0 合約安全修復、P0 後端加固、P1 Agent 委託 + Walrus 三路徑、P2 PTB 合併與死碼清理:**全部完成**。`sui move test` 13/13 PASS(含 12 個安全測試)。
- zkLogin Phase 0–6(登入/付款/委託/爭議)是 **scaffold 完成、待實機驗證** 狀態。
- 未完成:**G2 後端 pytest 整合測試**、**C2-mobile(App 內本地產 ZKP 證明,PII 目前明碼送後端)**。
- `.env` 曾含真實私鑰,視為已洩漏;**任何情況下不得把秘密寫進程式碼、commit 或新檔案**。

## 本次任務(依序執行)

### 任務 1:把未提交的加固成果拆成主題式 commit(最優先)

工作區有 80+ 修改檔、20+ 刪除檔,是 2026-07-12 至 08-10 的全部加固成果,尚未提交。

1. 先跑 `git status` 與 `git diff --stat` 盤點全部變更。
2. 提交前驗證:`cd contracts && sui move build && sui move test` 必須綠燈;後端至少對改動的 `.py` 跑 `python -m py_compile`。
3. 檢查不得入庫的內容:`.env`、`*.local.dart`、任何 API key / 私鑰 / `.DS_Store`。若 `.DS_Store` 或 build 產物(`mobile/.dart_tool/`、`Podfile.lock` 若政策不追蹤)未被 ignore,先補 `.gitignore`。
4. 依主題拆 commit(建議順序與範圍,可依實際 diff 微調):
   - `fix(contracts)`: Move 安全修復 + agent_registry + PTB 合併 + security_tests(contracts/ 全部,含刪除的空檔與 IOTA 測試)
   - `fix(backend)`: 秘密 fail-fast、mock 移除、CORS 白名單、免費搭車漏洞、refunds admin 驗證
   - `feat(backend)`: agent_service、walrus_service、trajectory、delegation、dispute、zkLogin 端點與 migrations
   - `feat(mobile)`: zkLogin 服務、委託/爭議 UI、設計系統、Firebase 佔位符防閃退,及行動端死碼刪除
   - `feat(dashboard)`: 爭議仲裁頁 + 鏈上退款
   - `docs`: README、PROJECT_OVERVIEW、roadmap、USER_ACTION_ITEMS、.env.example
5. 每個 commit 訊息結尾加:`Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`。**只 commit,不要 push**,完成後列出所有 commit 供我檢查。

### 任務 2:G2 後端 pytest 整合測試

roadmap §5 P2 規格:escrow/refund 真實鏈上路徑、Agent PTB、Walrus 上傳/讀取/hash 校驗、ZKP fail-closed。

1. 建立 pytest harness(`backend/tests/`),外部依賴(Sui RPC、Walrus、DB)用可注入的 fake,但**不得**製造假交易 hash 冒充真實上鏈。
2. 至少覆蓋:`agent_service` 額度/過期拒絕、`walrus_service` content-hash 不符拋錯、`zkp_verifier` 缺 key fail-closed、`trips.py` 模擬付款只在 `MOCK_MODE` 生效、`refund_service_v2` approve/reject 路徑。
3. 跑到全綠,回報實際指令與結果。

### 任務 3:Flutter 靜態驗證(若環境有 Flutter)

`cd mobile && flutter pub get && flutter analyze`,修掉 error 等級問題(warning 記錄即可)。若環境沒有 Flutter,標註跳過並留給使用者本機執行。

### 完成後(每項任務都要做)

- 更新 `docs/PRODUCTION_HARDENING_ROADMAP.md` §7 進度追蹤與 §8 變更日誌。
- 最後總結:完成了什麼、驗證結果、剩餘阻塞點。

## 規範提醒(違反即算失敗)

- 不產生 mock / 假交易 hash;鏈上呼叫失敗要明確拋錯。
- 資金移動的 Move 函式必須有 Capability 或 sender 斷言。
- 大容量資料走 Walrus,鏈上只存 `blob_id` + `content_hash`。
- 不動 `docs/USER_ACTION_ITEMS.md` 裡標記「需使用者本人操作」的項目(Enoki Portal、Google OAuth、faucet),那些不是你的任務。
