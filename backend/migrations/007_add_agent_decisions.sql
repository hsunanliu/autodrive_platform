-- 007_add_agent_decisions.sql
-- Agent 決策層：記錄 LLM 結算決策（供前端活動 feed + 大額待確認），
-- 並在委託表加「自動執行門檻」欄位（分級權限：小額自動、大額需乘客確認）。

-- 1. 委託自動門檻（MIST）。決策金額 ≤ 此值自動代發；> 此值存 pending 待確認。預設 1 SUI。
ALTER TABLE operator_delegations
    ADD COLUMN IF NOT EXISTS auto_threshold_mist BIGINT NOT NULL DEFAULT 1000000000;

COMMENT ON COLUMN operator_delegations.auto_threshold_mist IS
    'Agent 自動執行門檻（MIST）：決策金額 ≤ 此值自動代發，> 此值存 pending 待乘客確認。';

-- 2. Agent 決策紀錄表（前端 /agent/activities feed 的資料來源）
CREATE TABLE IF NOT EXISTS agent_decisions (
    id                SERIAL PRIMARY KEY,
    trip_id           INTEGER NOT NULL REFERENCES trips(trip_id) ON DELETE CASCADE,
    user_id           INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    action            VARCHAR(32) NOT NULL,   -- release | refund | hold_for_confirm | flag_review
    amount_mist       BIGINT NOT NULL,
    status            VARCHAR(32) NOT NULL,   -- auto_executed | pending | confirmed | declined | needs_review | failed
    reason            VARCHAR(500),
    confidence        DOUBLE PRECISION,
    source            VARCHAR(16),            -- llm | rules | fallback
    escrow_object_id  VARCHAR(66) NOT NULL,
    operator_cap_id   VARCHAR(66) NOT NULL,
    tx_digest         VARCHAR(66),
    error             VARCHAR(500),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_agent_decisions_user_id ON agent_decisions (user_id);
CREATE INDEX IF NOT EXISTS ix_agent_decisions_trip_id ON agent_decisions (trip_id);
CREATE INDEX IF NOT EXISTS ix_agent_decisions_status ON agent_decisions (status);
