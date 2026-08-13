/// Agent 能力委託 (Capability Delegation for the Agentic Web)
///
/// 讓乘客/司機把「代發交易」的權限，在**明確的邊界內**委託給平台的自動化 Agent：
///   - 單筆金額上限 (max_spend_per_tx)
///   - 每日累計上限 (daily_limit，跨自然日自動重置)
///   - 授權到期時間 (valid_until_ms)
///   - 允許的動作白名單 (allowed_actions，bitmask)
///   - 隨時可由用戶撤銷 (revoke)
///
/// 設計選擇：`OperatorCap` 是 **shared object**，並以**雙重 sender 把關**：
///   - 只有 `user`（授權人）能 `revoke`。
///   - 只有 `agent`（被授權者）能透過 `authorize_action` 動用；每次動用都記帳。
/// 這讓 Agent 得以代表用戶原子化地執行 escrow 釋放/退款/評價，而私鑰永遠留在用戶端，
/// 平台單一金鑰不再是「全權代理」——降低金鑰外洩的爆炸半徑，也符合 Agentic Web 的自主代理精神。
module autodrive::agent_registry {
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::clock::{Self, Clock};
    use sui::event;

    // ============================================================
    // 錯誤碼
    // ============================================================
    const E_NOT_USER: u64 = 1;          // 非授權人，不能撤銷
    const E_NOT_AGENT: u64 = 2;         // 非被授權 Agent，不能動用
    const E_REVOKED: u64 = 3;           // 已撤銷
    const E_EXPIRED: u64 = 4;           // 已過期
    const E_ACTION_NOT_ALLOWED: u64 = 5;// 動作不在白名單
    const E_OVER_TX_LIMIT: u64 = 6;     // 超過單筆上限
    const E_OVER_DAILY_LIMIT: u64 = 7;  // 超過每日累計上限
    const E_ZERO_LIMIT: u64 = 8;        // 上限不可為 0（等於未授權）

    // ============================================================
    // 動作 bitmask（供其他模組引用）
    // ============================================================
    const ACTION_RELEASE_ESCROW: u64 = 1; // 0b0001 釋放託管給司機/平台
    const ACTION_REFUND: u64 = 2;         // 0b0010 退款給乘客
    const ACTION_RATE: u64 = 4;           // 0b0100 代發評價
    const ACTION_MATCH: u64 = 8;          // 0b1000 搓合/接單

    /// 一天的毫秒數（用於每日額度重置）
    const MS_PER_DAY: u64 = 86_400_000;

    // ============================================================
    // 能力物件
    // ============================================================

    /// 用戶授權給 Agent 的操作能力（shared object）
    public struct OperatorCap has key {
        id: UID,
        /// 授權人（資金/資產的真正所有者）
        user: address,
        /// 被授權的 Agent 位址
        agent: address,
        /// 單筆交易金額上限
        max_spend_per_tx: u64,
        /// 每日累計金額上限
        daily_limit: u64,
        /// 今日已動用金額
        spent_today: u64,
        /// 今日的日序（timestamp_ms / MS_PER_DAY），跨日自動重置
        day_index: u64,
        /// 授權到期（clock 毫秒時間戳）
        valid_until_ms: u64,
        /// 允許動作 bitmask
        allowed_actions: u64,
        /// 是否已撤銷
        revoked: bool,
    }

    // ============================================================
    // 事件
    // ============================================================

    public struct OperatorCapIssued has copy, drop {
        cap_id: ID,
        user: address,
        agent: address,
        max_spend_per_tx: u64,
        daily_limit: u64,
        valid_until_ms: u64,
        allowed_actions: u64,
    }

    public struct OperatorCapRevoked has copy, drop {
        cap_id: ID,
        user: address,
    }

    public struct AgentActionAuthorized has copy, drop {
        cap_id: ID,
        user: address,
        agent: address,
        action: u64,
        amount: u64,
        spent_today: u64,
    }

    // ============================================================
    // 發行 / 撤銷
    // ============================================================

    /// 用戶簽發一份委託授權給指定 Agent。
    /// 由用戶自己的錢包簽署（sender = user），因此私鑰不必交給平台。
    public entry fun issue_operator_cap(
        agent: address,
        max_spend_per_tx: u64,
        daily_limit: u64,
        valid_for_ms: u64,
        allowed_actions: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(max_spend_per_tx > 0 && daily_limit > 0, E_ZERO_LIMIT);
        let now = clock::timestamp_ms(clock);
        let user = tx_context::sender(ctx);

        let cap = OperatorCap {
            id: object::new(ctx),
            user,
            agent,
            max_spend_per_tx,
            daily_limit,
            spent_today: 0,
            day_index: now / MS_PER_DAY,
            valid_until_ms: now + valid_for_ms,
            allowed_actions,
            revoked: false,
        };

        event::emit(OperatorCapIssued {
            cap_id: object::id(&cap),
            user,
            agent,
            max_spend_per_tx,
            daily_limit,
            valid_until_ms: cap.valid_until_ms,
            allowed_actions,
        });

        transfer::share_object(cap);
    }

    /// 用戶撤銷授權。只有授權人本人可呼叫。
    public entry fun revoke(cap: &mut OperatorCap, ctx: &TxContext) {
        assert!(tx_context::sender(ctx) == cap.user, E_NOT_USER);
        cap.revoked = true;
        event::emit(OperatorCapRevoked { cap_id: object::uid_to_inner(&cap.id), user: cap.user });
    }

    // ============================================================
    // 授權檢查（供其他模組呼叫）
    // ============================================================

    /// Agent 動用授權前必呼叫：驗證 sender、時效、動作白名單、單筆與每日額度，並記帳。
    /// 通過則回傳 `user` 位址，讓呼叫模組據以核對資產所有權（例如 escrow.passenger == user）。
    /// 任一條件不符即 abort，交易整筆失敗。
    public fun authorize_action(
        cap: &mut OperatorCap,
        action: u64,
        amount: u64,
        clock: &Clock,
        ctx: &TxContext
    ): address {
        // 1. 未撤銷、由正確的 Agent 發起
        assert!(!cap.revoked, E_REVOKED);
        assert!(tx_context::sender(ctx) == cap.agent, E_NOT_AGENT);

        // 2. 未過期
        let now = clock::timestamp_ms(clock);
        assert!(now <= cap.valid_until_ms, E_EXPIRED);

        // 3. 動作在白名單
        assert!(cap.allowed_actions & action == action, E_ACTION_NOT_ALLOWED);

        // 4. 單筆上限
        assert!(amount <= cap.max_spend_per_tx, E_OVER_TX_LIMIT);

        // 5. 每日額度（跨日自動重置）
        let today = now / MS_PER_DAY;
        if (today != cap.day_index) {
            cap.day_index = today;
            cap.spent_today = 0;
        };
        assert!(cap.spent_today + amount <= cap.daily_limit, E_OVER_DAILY_LIMIT);
        cap.spent_today = cap.spent_today + amount;

        event::emit(AgentActionAuthorized {
            cap_id: object::uid_to_inner(&cap.id),
            user: cap.user,
            agent: cap.agent,
            action,
            amount,
            spent_today: cap.spent_today,
        });

        cap.user
    }

    // ============================================================
    // 動作常數 getter（供其他模組使用，避免硬編碼 bitmask）
    // ============================================================
    public fun action_release_escrow(): u64 { ACTION_RELEASE_ESCROW }
    public fun action_refund(): u64 { ACTION_REFUND }
    public fun action_rate(): u64 { ACTION_RATE }
    public fun action_match(): u64 { ACTION_MATCH }

    // ============================================================
    // 視圖函數
    // ============================================================
    public fun user(cap: &OperatorCap): address { cap.user }
    public fun agent(cap: &OperatorCap): address { cap.agent }
    public fun is_revoked(cap: &OperatorCap): bool { cap.revoked }
    public fun spent_today(cap: &OperatorCap): u64 { cap.spent_today }
    public fun daily_limit(cap: &OperatorCap): u64 { cap.daily_limit }
    public fun max_spend_per_tx(cap: &OperatorCap): u64 { cap.max_spend_per_tx }

    /// 是否仍在有效期且未撤銷
    public fun is_active(cap: &OperatorCap, clock: &Clock): bool {
        !cap.revoked && clock::timestamp_ms(clock) <= cap.valid_until_ms
    }

    #[test_only]
    public fun issue_for_testing(
        user: address,
        agent: address,
        max_spend_per_tx: u64,
        daily_limit: u64,
        valid_until_ms: u64,
        allowed_actions: u64,
        ctx: &mut TxContext
    ): OperatorCap {
        OperatorCap {
            id: object::new(ctx),
            user,
            agent,
            max_spend_per_tx,
            daily_limit,
            spent_today: 0,
            day_index: 0,
            valid_until_ms,
            allowed_actions,
            revoked: false,
        }
    }

    #[test_only]
    public fun share_for_testing(cap: OperatorCap) {
        transfer::share_object(cap);
    }

    #[test_only]
    public fun destroy_for_testing(cap: OperatorCap) {
        let OperatorCap {
            id, user: _, agent: _, max_spend_per_tx: _, daily_limit: _,
            spent_today: _, day_index: _, valid_until_ms: _, allowed_actions: _, revoked: _,
        } = cap;
        object::delete(id);
    }
}
