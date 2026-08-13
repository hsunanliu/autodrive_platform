-- 評價與信譽系統資料庫遷移
-- 執行日期: 2024-12
-- 說明: 新增車輛評價表、信譽分數表、封禁記錄表

-- ============================================================
-- 1. 車輛評價表 (vehicle_ratings)
-- ============================================================
CREATE TABLE IF NOT EXISTS vehicle_ratings (
    id SERIAL PRIMARY KEY,
    trip_id INTEGER NOT NULL REFERENCES trips(trip_id) ON DELETE CASCADE,
    vehicle_id VARCHAR(100) NOT NULL REFERENCES vehicles(vehicle_id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- 評分內容
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    tags JSONB DEFAULT '[]'::jsonb,  -- ["乾淨", "準時", "平穩"]

    -- 鏈上存證
    rating_hash VARCHAR(66),  -- SHA256 hash (0x + 64 hex)
    blockchain_tx_id VARCHAR(100),  -- 上鏈交易 hash
    proof_object_id VARCHAR(100),  -- Sui 上的 RatingProof 對象 ID

    -- 時間戳
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- 確保每個行程只能評價一次
    CONSTRAINT unique_trip_rating UNIQUE (trip_id, user_id)
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_vehicle_ratings_vehicle_id ON vehicle_ratings(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_ratings_user_id ON vehicle_ratings(user_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_ratings_created_at ON vehicle_ratings(created_at DESC);

-- ============================================================
-- 2. 信譽分數表 (reputation_scores)
-- ============================================================
CREATE TABLE IF NOT EXISTS reputation_scores (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,

    -- 分數與等級
    current_score INTEGER NOT NULL DEFAULT 100,
    level VARCHAR(20) NOT NULL DEFAULT 'normal',  -- gold, good, normal, warning, restricted, probation, banned

    -- 統計
    total_positive INTEGER DEFAULT 0,  -- 正面事件次數
    total_negative INTEGER DEFAULT 0,  -- 負面事件次數
    total_trips INTEGER DEFAULT 0,
    total_ratings_given INTEGER DEFAULT 0,
    avg_rating_given DECIMAL(2,1) DEFAULT 0.0,

    -- 時間戳
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_reputation_scores_level ON reputation_scores(level);
CREATE INDEX IF NOT EXISTS idx_reputation_scores_score ON reputation_scores(current_score DESC);

-- ============================================================
-- 3. 信譽歷史表 (reputation_history)
-- ============================================================
CREATE TABLE IF NOT EXISTS reputation_history (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- 事件資訊
    event_type VARCHAR(50) NOT NULL,  -- rating_5_star, cancel_trip, timeout, etc.
    score_change INTEGER NOT NULL,     -- +3, -5, etc.
    score_before INTEGER NOT NULL,
    score_after INTEGER NOT NULL,
    reason TEXT,

    -- 關聯
    trip_id INTEGER REFERENCES trips(trip_id) ON DELETE SET NULL,
    rating_id INTEGER REFERENCES vehicle_ratings(id) ON DELETE SET NULL,

    -- 時間戳
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_reputation_history_user_id ON reputation_history(user_id);
CREATE INDEX IF NOT EXISTS idx_reputation_history_created_at ON reputation_history(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reputation_history_event_type ON reputation_history(event_type);

-- ============================================================
-- 4. 封禁記錄表 (user_bans)
-- ============================================================
CREATE TABLE IF NOT EXISTS user_bans (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- 封禁資訊
    ban_type VARCHAR(20) NOT NULL,  -- warning, temporary, permanent
    reason TEXT NOT NULL,
    triggered_by VARCHAR(50),  -- low_score, complaint, admin

    -- 時間範圍
    start_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    end_at TIMESTAMP WITH TIME ZONE,  -- NULL = 永久

    -- 申訴狀態
    appeal_status VARCHAR(20) DEFAULT 'none',  -- none, pending, approved, rejected
    appeal_reason TEXT,
    appeal_at TIMESTAMP WITH TIME ZONE,
    reviewed_by INTEGER REFERENCES users(id),
    reviewed_at TIMESTAMP WITH TIME ZONE,

    -- 時間戳
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_user_bans_user_id ON user_bans(user_id);
CREATE INDEX IF NOT EXISTS idx_user_bans_ban_type ON user_bans(ban_type);
CREATE INDEX IF NOT EXISTS idx_user_bans_end_at ON user_bans(end_at);

-- ============================================================
-- 5. 擴展 users 表
-- ============================================================
ALTER TABLE users ADD COLUMN IF NOT EXISTS reputation_score INTEGER DEFAULT 100;
ALTER TABLE users ADD COLUMN IF NOT EXISTS reputation_level VARCHAR(20) DEFAULT 'normal';
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_banned BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS ban_until TIMESTAMP WITH TIME ZONE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS total_ratings_given INTEGER DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS avg_rating_given DECIMAL(2,1) DEFAULT 0.0;

-- ============================================================
-- 6. 擴展 vehicles 表
-- ============================================================
ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS avg_rating DECIMAL(2,1) DEFAULT 0.0;
ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS total_ratings INTEGER DEFAULT 0;
ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS rating_distribution JSONB DEFAULT '{"1": 0, "2": 0, "3": 0, "4": 0, "5": 0}'::jsonb;

-- ============================================================
-- 7. 預定義標籤表 (可選)
-- ============================================================
CREATE TABLE IF NOT EXISTS rating_tags (
    id SERIAL PRIMARY KEY,
    tag_key VARCHAR(50) NOT NULL UNIQUE,
    tag_label VARCHAR(100) NOT NULL,
    tag_type VARCHAR(20) NOT NULL,  -- positive, negative
    icon VARCHAR(50),
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE
);

-- 插入預設標籤
INSERT INTO rating_tags (tag_key, tag_label, tag_type, icon, sort_order) VALUES
    ('clean', '車內整潔', 'positive', 'cleaning_services', 1),
    ('smooth', '行駛平穩', 'positive', 'airline_seat_recline_normal', 2),
    ('on_time', '準時到達', 'positive', 'schedule', 3),
    ('comfortable', '空調舒適', 'positive', 'ac_unit', 4),
    ('safe', '安全可靠', 'positive', 'verified_user', 5),
    ('dirty', '車內髒亂', 'negative', 'warning', 6),
    ('bumpy', '行駛顛簸', 'negative', 'report_problem', 7),
    ('detour', '路線繞遠', 'negative', 'wrong_location', 8),
    ('ac_issue', '空調問題', 'negative', 'thermostat', 9),
    ('unsafe', '感覺不安全', 'negative', 'dangerous', 10)
ON CONFLICT (tag_key) DO NOTHING;

-- ============================================================
-- 8. 創建更新觸發器
-- ============================================================

-- 更新 vehicle_ratings 的 updated_at
CREATE OR REPLACE FUNCTION update_vehicle_ratings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_vehicle_ratings_updated_at ON vehicle_ratings;
CREATE TRIGGER trigger_vehicle_ratings_updated_at
    BEFORE UPDATE ON vehicle_ratings
    FOR EACH ROW
    EXECUTE FUNCTION update_vehicle_ratings_updated_at();

-- 更新 reputation_scores 的 last_updated
CREATE OR REPLACE FUNCTION update_reputation_scores_last_updated()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_updated = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_reputation_scores_last_updated ON reputation_scores;
CREATE TRIGGER trigger_reputation_scores_last_updated
    BEFORE UPDATE ON reputation_scores
    FOR EACH ROW
    EXECUTE FUNCTION update_reputation_scores_last_updated();

-- ============================================================
-- 完成
-- ============================================================
COMMENT ON TABLE vehicle_ratings IS '車輛評價表 - 乘客對自駕車的評價';
COMMENT ON TABLE reputation_scores IS '用戶信譽分數表';
COMMENT ON TABLE reputation_history IS '信譽分數變動歷史';
COMMENT ON TABLE user_bans IS '用戶封禁記錄';
COMMENT ON TABLE rating_tags IS '評價標籤預設值';
