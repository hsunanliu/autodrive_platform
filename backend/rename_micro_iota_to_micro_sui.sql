-- 數據庫遷移腳本：將所有 micro_iota 欄位重命名為 micro_sui
-- 執行時間：2025-11-05
-- 原因：平台從 IOTA 遷移到 Sui 區塊鏈

BEGIN;

-- 1. 重命名 users 表中的欄位
ALTER TABLE users
RENAME COLUMN total_earnings_micro_iota TO total_earnings_micro_sui;

-- 2. 重命名 vehicles 表中的欄位
ALTER TABLE vehicles
RENAME COLUMN total_earnings_micro_iota TO total_earnings_micro_sui;

-- 3. 重命名 trips 表中的欄位
ALTER TABLE trips
RENAME COLUMN payment_amount_micro_iota TO payment_amount_micro_sui;

-- 4. 重命名 payment_transactions 表中的欄位（如果存在）
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'payment_transactions'
        AND column_name = 'amount_micro_iota'
    ) THEN
        ALTER TABLE payment_transactions
        RENAME COLUMN amount_micro_iota TO amount_micro_sui;
    END IF;
END $$;

COMMIT;

-- 驗證遷移結果
SELECT
    'users' as table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'users'
AND column_name LIKE '%micro%'

UNION ALL

SELECT
    'vehicles' as table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'vehicles'
AND column_name LIKE '%micro%'

UNION ALL

SELECT
    'trips' as table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'trips'
AND column_name LIKE '%micro%';
