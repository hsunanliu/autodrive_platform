-- 004_add_credential_nullifier.sql
-- 防 ZKP 重放（威脅 T3）：為 user_credentials 加一次性 nullifier（唯一）。
-- 同一 commitment 只能被消費一次；重複使用會撞唯一約束而被拒。

ALTER TABLE user_credentials
    ADD COLUMN IF NOT EXISTS nullifier VARCHAR(130);

-- 唯一約束（重放時 INSERT 撞此約束 → 後端拒絕）
CREATE UNIQUE INDEX IF NOT EXISTS ux_user_credentials_nullifier
    ON user_credentials (nullifier)
    WHERE nullifier IS NOT NULL;

COMMENT ON COLUMN user_credentials.nullifier IS
    '一次性 commitment/nullifier；防 ZKP 重放，見 backend/app/core/commitment.py。最終強制點為鏈上 credential_verifier::used_commitments。';
