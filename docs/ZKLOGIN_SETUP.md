# zkLogin 非託管登入 — 啟用設定清單

> 程式碼已全部接好（Flutter 服務、登入按鈕、後端端點、iOS 回跳）。
> 只剩「外部憑證註冊 + 填 4 個地方的值」。填完即端到端可登入。
> 技術可行性已驗證：真實臨時金鑰 → Enoki nonce 鏈上實測 HTTP 200。

## 一次性資料
| 項目 | 值 |
|---|---|
| iOS Bundle ID | `com.example.projectDapp` |
| Enoki API Key（public，已填 `.env`） | `enoki_public_643a99a9…c75` |
| 目標網路 | Sui testnet |

> ⚠️ `com.example.*` 是 Flutter 預設佔位。開發/testnet 可用；上架 App Store 需改自有反向網域。

---

## 步驟 1 — Google Cloud Console 建 OAuth Client
1. https://console.cloud.google.com → APIs & Services → Credentials
2. Create Credentials → OAuth client ID → Application type = **iOS**
3. Bundle ID 填 `com.example.projectDapp`
4. 取得 **client id**：`<XXXX>.apps.googleusercontent.com`
   - 反向 client id（redirect 用）= `com.googleusercontent.apps.<XXXX>`

## 步驟 2 — Enoki Portal 註冊 Auth Provider
1. https://portal.enoki.mystenlabs.com → 你的 app（對應此 public key）
2. Auth Providers → Add → **Google**
3. 貼上步驟 1 的 client id
   - （目前 app 的 `authenticationProviders` 為空，這步是缺口所在）

## 步驟 3 — 填入 4 個地方
以 client id `123-abc.apps.googleusercontent.com` 為例：

| # | 檔案 | 欄位 | 值 |
|---|---|---|---|
| 1 | `backend/.env` | `GOOGLE_OAUTH_CLIENT_ID=` | `123-abc.apps.googleusercontent.com` |
| 2 | `mobile/lib/config/app_config.local.dart` | `localGoogleOAuthClientId` | `123-abc.apps.googleusercontent.com` |
| 3 | `mobile/lib/config/app_config.local.dart` | `localGoogleOAuthRedirectUrl` | `com.googleusercontent.apps.123-abc:/oauth2redirect` |
| 4 | `mobile/ios/Runner/Info.plist` | `CFBundleURLSchemes`（google-oauth 那組） | `com.googleusercontent.apps.123-abc` |

> 重點：#3 的 scheme 前綴與 #4 必須**完全一致**，否則 OAuth 回跳失敗。

## 步驟 4 — 驗證
```bash
# 後端載入 client id
docker compose up -d --force-recreate backend

# Flutter
cd mobile && flutter pub get && flutter run
# → 登入頁點「用 Google 登入（免助記詞）」→ Google 授權 →
#   成功建立 zkLogin 位址並進入首頁 = 端到端打通
```

---

## 打通後解鎖
- **Phase 4** 非託管付款（`lock_payment` 走 zkLogin 簽名，取代 mock hash）— 程式碼已備置
- **Phase 5** 委託授權（`issue_operator_cap`）
- **Phase 6** 爭議（`raise_dispute` 凍結 escrow）

## Phase 4 額外需在 Enoki Portal 設定（贊助交易）
付款走 Enoki「贊助交易」（Enoki 代付 gas 並組 zkLogin 簽名），故除了 Auth Provider 外還要：
1. **Sponsor 資金**：在 Enoki Portal 為此 app 啟用交易贊助並儲值（testnet gas）。
2. **Allowed move targets**：允許以下三個（目前 package：`0xb761c6f5…e23f`）。後端各 `prepare` 已帶
   `allowedMoveCallTargets`，但 portal 端也需放行：
   - `…::payment_escrow::lock_payment`（Phase 4 付款）
   - `…::agent_registry::issue_operator_cap`（Phase 5 委託）
   - `…::payment_escrow::raise_dispute`（Phase 6 爭議）
3. 乘客的 zkLogin 位址需先領 **testnet SUI**（付款金額本身由乘客出；gas 由 Enoki 贊助）。

### 實機驗證重點（Phase 4）
- 用真實 Google 登入取得 JWT 後，跑一次付款，確認：
  - `prepare` 回傳 `{bytes, digest}`（Enoki 贊助成功）
  - App 簽名後 `execute` 回傳 `escrow_object_id`（鏈上建立 Escrow）
- 若 `execute` 報「簽名格式」相關錯誤，代表 Enoki 需「已組裝的 zkLogin 簽名」而非臨時簽名，
  需在 `zklogin_service.signSuiTransactionBytes` 改為組裝完整 zkLogin 簽名（proof+maxEpoch+addressSeed）。

## 相關程式碼（已完成）
- `mobile/lib/services/zklogin_service.dart` — 產臨時金鑰 / nonce / OAuth / login / signDigest
- `mobile/lib/login_page.dart` — 「用 Google 登入」按鈕 + handler
- `backend/app/api/v1/auth.py` — `/auth/zklogin/{nonce,login,zkp}`
- `backend/app/services/zklogin_service.py` — Enoki HTTP 封裝
