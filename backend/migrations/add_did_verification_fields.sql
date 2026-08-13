-- 添加 DID 驗證相關欄位到 users 表
-- 2025-11-27: 添加 DID + ZKP 身份驗證支持

-- 1. 添加 did_document 欄位（存儲 DID 文檔 JSON）
ALTER TABLE users
ADD COLUMN IF NOT EXISTS did_document TEXT;

COMMENT ON COLUMN users.did_document IS 'DID 文檔（JSON 格式，包含驗證方法等）';

-- 2. 添加 age_verified 欄位（年齡驗證狀態）
ALTER TABLE users
ADD COLUMN IF NOT EXISTS age_verified BOOLEAN DEFAULT FALSE NOT NULL;

COMMENT ON COLUMN users.age_verified IS '年齡驗證狀態（通過 ZKP 驗證）';

-- 3. 添加 license_verified 欄位（駕照驗證狀態，僅司機）
ALTER TABLE users
ADD COLUMN IF NOT EXISTS license_verified BOOLEAN DEFAULT FALSE NOT NULL;

COMMENT ON COLUMN users.license_verified IS '駕照驗證狀態（通過 ZKP 驗證，僅司機）';

-- 4. 創建索引以提高查詢性能
CREATE INDEX IF NOT EXISTS idx_users_age_verified ON users(age_verified);
CREATE INDEX IF NOT EXISTS idx_users_license_verified ON users(license_verified);

-- 5. 驗證遷移結果
-- SELECT column_name, data_type, is_nullable, column_default
-- FROM information_schema.columns
-- WHERE table_name = 'users'
-- AND column_name IN ('did_document', 'age_verified', 'license_verified');
