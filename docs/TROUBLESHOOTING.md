# 故障排除（專案專屬速查）

> 只收「本專案特有」的排錯知識。通用的 FastAPI/Flutter 除錯不收。
> 歷史根因分析（白屏、閃退、zkLogin nonce 等）在 roadmap §8 與 `docs/changelog-*.md`，先搜那裡。

## 資料庫

```bash
# 進入 psql（容器名與帳號固定如下）
docker exec autodrive_platform-db-1 psql -U autodrive -d autodrive_dev

# 常用檢查
docker exec autodrive_platform-db-1 psql -U autodrive -d autodrive_dev -c "\dt"          # 列表
docker exec autodrive_platform-db-1 psql -U autodrive -d autodrive_dev -c "\d+ trips"    # 表結構

# 套用 migration（backend/migrations/ 依序號執行）
docker cp backend/migrations/006_xxx.sql autodrive_platform-db-1:/tmp/
docker exec autodrive_platform-db-1 psql -U autodrive -d autodrive_dev -f /tmp/006_xxx.sql
```

- `UndefinedColumnError` / `relation does not exist` ＝ migration 沒跑，用上面流程補。
- 完全重置：`docker compose down -v && docker compose up -d`（**-v 會清掉所有資料**）。

## 後端 / Docker

- **改了 `.env` 沒生效**：`docker compose up -d --force-recreate backend`，重啟不會重讀 env。
- 啟動失敗先看 `docker compose logs backend --tail 50`；config fail-fast 會因缺
  `SECRET_KEY`/`DATABASE_URL`/`OPERATOR_PRIVATE_KEY` 直接拒絕啟動（設計如此，補值勿加預設）。
- Port 8000 被占：`lsof -i :8000` → kill。

## Sui 鏈上

- RPC：`fullnode.testnet.sui.io` 曾對本機回 404，備援 `https://sui-testnet-rpc.publicnode.com`。
- Gas 不足：`sui client gas` 查餘額；testnet faucet：
  `curl -X POST 'https://faucet.testnet.sui.io/gas' -H 'Content-Type: application/json' -d '{"FixedAmountRequest":{"recipient":"<addr>"}}'`
- 退款池注資：`scripts/ops/fund_refund_pool.sh`。

## Flutter 實機

- 後端位址在 gitignored 的 `mobile/lib/config/app_config.local.dart`；Mac 換網路後 IP 會變，
  先用手機 Safari 開 `http://<Mac IP>:8000/health` 確認可達（`ipconfig getifaddr en0` 查 IP，或跑 `update_ip.sh`）。
- 模擬器連本機用 `http://localhost:8000`。
- 無線偵錯找不到 Dart VM Service：`Info.plist` 需有 `NSBonjourServices`（`_dartVmService._tcp`）
  與 `NSLocalNetworkUsageDescription`（已修，roadmap §8 2026-08-14）。
- 啟動就 SIGABRT 且 Dart 無 log：查 `~/Library/Logs/DiagnosticReports/Runner-*.ips`，
  歷史案例是 Firebase 佔位符 API key 丟原生 NSException（roadmap §8 2026-07-29）。
