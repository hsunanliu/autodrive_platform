# 使用者待辦清單（USER ACTION ITEMS）

> 這是「**需要你本人操作、我（Claude）無法代做**」的事情的**單一清單**。
> 程式碼側我已完成的進度見 `docs/PRODUCTION_HARDENING_ROADMAP.md` §8 變更日誌。
> 完成一項就打勾。最後更新：2026-07-29。

---

## 🔴 P0 — 卡住 zkLogin 全部功能（登入/付款/委託/爭議）

### 1. Enoki Portal 設定贊助交易
- 位置：https://portal.enoki.mystenlabs.com → 你的 app（對應 `enoki_public_643a…c75`）
- [ ] 開啟 **交易贊助（sponsored transactions）** 並**儲值 testnet gas**
- [ ] **允許 move 目標**（allowed move call targets），把下面**三行完整字串**逐一貼上
  （格式 = `package::module::function`，已用 RPC 驗證這三個函式都在鏈上）：
  ```
  0xb761c6f5681e5f46533a52840dcd9e8f7bcb2a6f749dcc6a3e7646e37867e23f::payment_escrow::lock_payment
  0xb761c6f5681e5f46533a52840dcd9e8f7bcb2a6f749dcc6a3e7646e37867e23f::agent_registry::issue_operator_cap
  0xb761c6f5681e5f46533a52840dcd9e8f7bcb2a6f749dcc6a3e7646e37867e23f::payment_escrow::raise_dispute
  ```
  > package id 的權威來源：`.env` 的 `CONTRACT_PACKAGE_ID`（＝上面這串）。
  > ⚠️ 不要用 `Published.toml`/`CLAUDE.md` 裡的 `0xa6232c…380b`，那是過期版（無爭議函式）。
- ✅ Google Auth Provider 已註冊（我驗證過，這項已完成）

### 2. Google OAuth 同意畫面
- 位置：Google Cloud Console → OAuth consent screen
- [ ] 若專案在「Testing」模式，把你的測試 Google 帳號加進 **Test users**（否則登入會被擋）

### 3. zkLogin 位址領測試幣
- [ ] 第一次 Google 登入拿到 zkLogin 位址後，去 testnet faucet 給它一點 **SUI**
  （付款金額本身由乘客出；gas 由 Enoki 贊助，所以只需覆蓋車資額）

---

## 🟡 P1 — Google Maps（不影響 zkLogin，但影響地圖功能）

新 key `AIzaSyAezZ…lFWk` 已存進 gitignored 檔（`google_maps_config.local.dart` + `.env`），但它有應用限制。
- 位置：Google Cloud Console → Credentials → 該 key
- [ ] **API 限制**：只勾 Directions API、Places API、Geocoding API、Street View Static API
- [ ] **應用程式限制**：iOS app 含 bundle id `com.example.projectDapp`（REST header 我已接）
- [ ] 設**每日配額/預算上限**（防外流被刷）
- [ ] （選填）若要後端也能算真實路線：GCP 另建一把**伺服器 IP 限制**的 key，填進 `.env` 的
  `BACKEND_GOOGLE_MAPS_API_KEY`（未填則後端用直線 fallback，不影響 app）

---

## 🟡 P1.5 — Firebase 推播（選填，app 已能不靠它啟動）

啟動閃退已修好（Firebase key 是佔位符 → 現在會自動跳過，app 照常跑，只是沒推播）。
若要啟用 FCM 推播通知：
- [ ] Firebase Console → 專案設定 → iOS app → 下載真實的 `GoogleService-Info.plist` 放進 `mobile/ios/Runner/`
- [ ] 跑 `flutterfire configure` 更新 `mobile/lib/firebase_options.dart`（把佔位符換成真實值）
- 不做也沒關係——zkLogin / 付款 / 委託 / 爭議 全部功能都不需要 Firebase

---

## 🟢 P2 — 本機驗證（我這環境跑不了 Flutter）

- [ ] `cd mobile && flutter pub get && flutter analyze`（驗證我這幾輪寫的 Dart；新增套件：
  `flutter_appauth`、`ed25519_edwards`、`pointycastle`）
- [ ] 實機/模擬器跑 Google 登入（免助記詞）
- [ ] 實機測付款 → 確認 `execute` 回傳 `escrow_object_id`（鏈上建立 Escrow）
- [ ] 把第一個實機錯誤貼給我（很可能是 Enoki 簽名格式，排查點見 `docs/ZKLOGIN_SETUP.md`）

---

## ⚪ P3 — 資料一致性（低優先，建議清）

- [x] ~~`CLAUDE.md` 過期 package~~ → 已更新為 `0xb761c6f5…e23f`（2026-08-10）
- [ ] `contracts/Published.toml` 仍寫過期 package `0xa6232c…380b`。它是 `sui move` 產生檔，
  建議下次 `sui move` 部署時自動更新即可；或要我手動改跟我說（改前想跟你確認，因它是工具產生的）

---

## 我（Claude）端的已知後續（不需你動，記錄備查）
- Phase 4/5/6 為 scaffold，待你 P0+P2 完成後依實機結果我來收尾修正。
- Phase 9 死碼清理持續進行（已刪 IOTA/WalletConnect/舊 driver 頁/舊 payment_dialog/sui_contract_service）。
- 詳見 `docs/PRODUCTION_HARDENING_ROADMAP.md` §8。
