-- 005_add_operator_delegations.sql
-- Agent 委託：使用者簽發給平台 Agent 的 OperatorCap 紀錄。

CREATE TABLE IF NOT EXISTS operator_delegations (
    id                SERIAL PRIMARY KEY,
    user_id           INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    cap_object_id     VARCHAR(66) NOT NULL UNIQUE,
    agent_address     VARCHAR(66) NOT NULL,
    max_spend_per_tx  BIGINT,
    daily_limit       BIGINT,
    valid_until       TIMESTAMPTZ,
    allowed_actions   INTEGER,
    revoked           BOOLEAN NOT NULL DEFAULT FALSE,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_operator_delegations_user_id ON operator_delegations (user_id);
CREATE INDEX IF NOT EXISTS ix_operator_delegations_cap_object_id ON operator_delegations (cap_object_id);
