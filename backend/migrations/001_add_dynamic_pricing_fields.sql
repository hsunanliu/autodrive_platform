-- ============================================================================
-- 資料庫遷移：新增動態定價相關欄位
-- 檔案：001_add_dynamic_pricing_fields.sql
-- 日期：2025-10-22
-- 說明：為 trips 表新增動態定價、優先級和等待時間追蹤欄位
-- ============================================================================

-- 新增動態定價相關欄位到 trips 表
ALTER TABLE trips
ADD COLUMN IF NOT EXISTS surge_multiplier FLOAT DEFAULT 1.0 NOT NULL
    COMMENT '動態加價係數（1.0 = 無加價）';

ALTER TABLE trips
ADD COLUMN IF NOT EXISTS surge_reason VARCHAR(200)
    COMMENT '加價原因說明';

ALTER TABLE trips
ADD COLUMN IF NOT EXISTS price_type VARCHAR(20) DEFAULT 'standard' NOT NULL
    COMMENT '定價類型：dynamic（動態）或 standard（標準）';

ALTER TABLE trips
ADD COLUMN IF NOT EXISTS priority INTEGER DEFAULT 2 NOT NULL
    COMMENT '優先級：1=快速叫車（動態定價），2=標準叫車（固定價格）';

ALTER TABLE trips
ADD COLUMN IF NOT EXISTS estimated_wait_minutes INTEGER
    COMMENT '預估等待時間（分鐘）';

ALTER TABLE trips
ADD COLUMN IF NOT EXISTS actual_wait_minutes INTEGER
    COMMENT '實際等待時間（分鐘），從創建到接單';

-- 為新欄位建立索引以加速查詢
CREATE INDEX IF NOT EXISTS idx_trips_priority
    ON trips(priority);

CREATE INDEX IF NOT EXISTS idx_trips_price_type
    ON trips(price_type);

CREATE INDEX IF NOT EXISTS idx_trips_status_priority
    ON trips(status, priority, requested_at);

-- 更新約束條件
ALTER TABLE trips
DROP CONSTRAINT IF EXISTS valid_trip_status;

ALTER TABLE trips
ADD CONSTRAINT valid_trip_status
CHECK (status IN ('requested', 'matched', 'accepted', 'picked_up', 'in_progress', 'completed', 'cancelled'));

ALTER TABLE trips
ADD CONSTRAINT valid_price_type
CHECK (price_type IN ('standard', 'dynamic'));

ALTER TABLE trips
ADD CONSTRAINT valid_priority
CHECK (priority IN (1, 2));

ALTER TABLE trips
ADD CONSTRAINT valid_surge_multiplier
CHECK (surge_multiplier >= 1.0 AND surge_multiplier <= 3.0);

-- ============================================================================
-- 遷移完成
-- 驗證步驟：
-- 1. SELECT column_name, data_type FROM information_schema.columns WHERE table_name='trips' AND column_name LIKE '%surge%';
-- 2. SELECT column_name, data_type FROM information_schema.columns WHERE table_name='trips' AND column_name IN ('priority', 'price_type');
-- ============================================================================
