-- 車輛召回功能相關字段
-- 執行方式：在後端容器內執行 alembic upgrade head

-- 在 vehicles 表添加召回相關字段
ALTER TABLE vehicles
ADD COLUMN IF NOT EXISTS recall_target_lat DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS recall_target_lng DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS recall_started_at TIMESTAMP;

-- 添加索引以提高查詢性能
CREATE INDEX IF NOT EXISTS idx_vehicles_recall_status
ON vehicles(status)
WHERE recall_started_at IS NOT NULL;

-- 註釋
COMMENT ON COLUMN vehicles.recall_target_lat IS '召回目標位置緯度';
COMMENT ON COLUMN vehicles.recall_target_lng IS '召回目標位置經度';
COMMENT ON COLUMN vehicles.recall_started_at IS '召回開始時間';
