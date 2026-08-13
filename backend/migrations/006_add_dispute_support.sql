-- 006_add_dispute_support.sql
-- 爭議支援：trip 狀態允許 disputed、新增鏈上 Dispute 物件 ID 欄位。

-- 1. 放寬 status 約束以允許 'disputed'
ALTER TABLE trips DROP CONSTRAINT IF EXISTS valid_trip_status;
ALTER TABLE trips ADD CONSTRAINT valid_trip_status
    CHECK (status IN ('requested','matched','accepted','picked_up','in_progress','completed','cancelled','disputed'));

-- 2. 鏈上 Dispute 物件 ID（raise 後由行動端回報，供仲裁 resolve 使用）
ALTER TABLE trips ADD COLUMN IF NOT EXISTS dispute_object_id VARCHAR(66);

COMMENT ON COLUMN trips.dispute_object_id IS
    '鏈上 payment_escrow::Dispute 物件 ID；raise_dispute 後由行動端回報，resolve_dispute 需用。';
