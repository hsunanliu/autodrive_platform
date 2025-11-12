-- 創建行程中繼點表
CREATE TABLE IF NOT EXISTS trip_waypoints (
    id SERIAL PRIMARY KEY,
    trip_id INTEGER NOT NULL REFERENCES trips(trip_id) ON DELETE CASCADE,
    sequence INTEGER NOT NULL,
    lat DOUBLE PRECISION NOT NULL,
    lng DOUBLE PRECISION NOT NULL,
    address VARCHAR(500),
    arrival_time TIMESTAMP WITH TIME ZONE,
    CONSTRAINT trip_waypoints_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES trips(trip_id) ON DELETE CASCADE
);

-- 創建索引以提高查詢性能
CREATE INDEX IF NOT EXISTS idx_trip_waypoints_trip_id ON trip_waypoints(trip_id);
CREATE INDEX IF NOT EXISTS idx_trip_waypoints_sequence ON trip_waypoints(trip_id, sequence);

-- 添加註釋
COMMENT ON TABLE trip_waypoints IS '行程中繼點/停靠點表';
COMMENT ON COLUMN trip_waypoints.trip_id IS '行程 ID';
COMMENT ON COLUMN trip_waypoints.sequence IS '停靠順序：1, 2, 3... (起點為0，終點為最後)';
COMMENT ON COLUMN trip_waypoints.lat IS '緯度';
COMMENT ON COLUMN trip_waypoints.lng IS '經度';
COMMENT ON COLUMN trip_waypoints.address IS '地址';
COMMENT ON COLUMN trip_waypoints.arrival_time IS '實際到達時間（用於追蹤行程進度）';
