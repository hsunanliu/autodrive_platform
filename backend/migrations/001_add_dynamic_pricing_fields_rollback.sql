-- ============================================================================
-- 資料庫回滾：移除動態定價相關欄位
-- 檔案：001_add_dynamic_pricing_fields_rollback.sql
-- 日期：2025-10-22
-- 說明：回滾 001_add_dynamic_pricing_fields.sql 的變更
-- 警告：這將刪除所有動態定價資料，請謹慎使用！
-- ============================================================================

-- 移除索引
DROP INDEX IF EXISTS idx_trips_priority;
DROP INDEX IF EXISTS idx_trips_price_type;
DROP INDEX IF EXISTS idx_trips_status_priority;

-- 移除約束
ALTER TABLE trips
DROP CONSTRAINT IF EXISTS valid_price_type;

ALTER TABLE trips
DROP CONSTRAINT IF EXISTS valid_priority;

ALTER TABLE trips
DROP CONSTRAINT IF EXISTS valid_surge_multiplier;

-- 移除欄位
ALTER TABLE trips
DROP COLUMN IF EXISTS surge_multiplier;

ALTER TABLE trips
DROP COLUMN IF EXISTS surge_reason;

ALTER TABLE trips
DROP COLUMN IF EXISTS price_type;

ALTER TABLE trips
DROP COLUMN IF EXISTS priority;

ALTER TABLE trips
DROP COLUMN IF EXISTS estimated_wait_minutes;

ALTER TABLE trips
DROP COLUMN IF EXISTS actual_wait_minutes;

-- ============================================================================
-- 回滾完成
-- 驗證步驟：
-- SELECT column_name FROM information_schema.columns WHERE table_name='trips';
-- ============================================================================
