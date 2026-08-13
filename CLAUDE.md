# CLAUDE.md — ChainSUI

去中心化叫車 DePIN 平台，參加 **Sui Overflow 2026「Agentic Web」賽道**。

## 目前的主線工作：生產級加固

我們正在把程式碼從 hackathon 原型提升到「上主網生產級」。
**接手任何工作前，先讀 [`docs/PRODUCTION_HARDENING_ROADMAP.md`](docs/PRODUCTION_HARDENING_ROADMAP.md)** — 那是本次重構的單一事實來源，含問題清單、優先序、各 Agent 分工、進度追蹤與驗證方式。
完成工作後**務必更新該檔的 §7 進度追蹤與 §8 變更日誌**。

## 關鍵事實（勿再重新調查）

- **鏈是 Sui（testnet framework）**，不是 IOTA。`iota-src/`、`backend/app/services/iota_*`、`contracts/tests/run_tests.sh` 都是舊 IOTA 遺留死碼，不要沿用或引用。
- **現行已發布 package（單一事實來源＝`.env` 的 `CONTRACT_PACKAGE_ID`）：`0xb761c6f5681e5f46533a52840dcd9e8f7bcb2a6f749dcc6a3e7646e37867e23f`**（testnet，2026-07-14 重新部署，含退款池直接退款 + 爭議仲裁 `raise_dispute`/`resolve_dispute`；已用 RPC 驗證函式存在）。
  - ⚠️ 舊 package `0xa6232c…790380b`（與 `contracts/Published.toml` 內容）**已過期、無爭議函式**，勿再引用。`Published.toml` 是 `sui move` 產生檔，尚未更新，以本行與 `.env` 為準。
- Move 命名空間 `autodrive::*` 與 `decentralized_ride::*` 都指向同一 `0x0` package。
- 後端 FastAPI + Postgres + `pysui`；行動端 Flutter。
- ⚠️ **`.env` 內曾有真實 operator 私鑰與 API 金鑰 → 視為已洩漏，須輪替，且不得再落地任何檔案。** 禁止把秘密寫進程式碼或提交。

## 常用指令

```bash
# 合約
cd contracts && sui move build          # 編譯
cd contracts && sui move test           # 測試（勿用 run_tests.sh，那是 IOTA CLI）

# 後端
cd backend && uvicorn app.main:app --reload
```

## 工作規範

- **不要**產生 mock / 假交易 hash 冒充真實鏈上寫入。若鏈上呼叫失敗，明確拋錯，不要降級回假 hash。
- 資金移動、狀態變更的 Move 函式**必須**有明確存取控管（Capability 物件或 sender/witness 斷言）。
- 大容量資料（軌跡、評價內容、佐證檔）走 Walrus，鏈上只存 `blob_id` + `content_hash`。
- 提交訊息結尾加：`Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
