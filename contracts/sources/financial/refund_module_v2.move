module autodrive::refund_module_v2 {
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::event;
    use sui::balance::{Self, Balance};

    /// 退款狀態
    const STATUS_PENDING: u8 = 1;
    const STATUS_APPROVED: u8 = 2;
    const STATUS_REJECTED: u8 = 3;
    const STATUS_COMPLETED: u8 = 4;

    /// 錯誤碼
    const E_INVALID_STATUS: u64 = 1;
    const E_NOT_AUTHORIZED: u64 = 2;
    const E_INSUFFICIENT_BALANCE: u64 = 3;
    const E_TRIP_NOT_COMPLETED: u64 = 4;
    const E_ESCROW_NOT_RELEASED: u64 = 5;

    /// 退款請求對象（用戶擁有）
    public struct RefundRequest has key, store {
        id: UID,
        trip_id: u64,
        requester: address,
        original_amount: u64,
        refund_amount: u64,
        reason: vector<u8>,
        status: u8,
        created_at: u64,
    }

    /// 退款能力 - 用於自動執行退款
    public struct RefundCapability has key, store {
        id: UID,
        platform_address: address,
    }

    /// 簡化版退款池 - 使用 Balance 而不是 Coin
    public struct RefundPoolV2 has key {
        id: UID,
        balance: Balance<SUI>,
        platform_address: address,
        total_refunded: u64,
    }

    /// 退款事件
    public struct RefundEvent has copy, drop {
        refund_id: address,
        trip_id: u64,
        requester: address,
        amount: u64,
        status: u8,
    }

    /// 初始化函數 - 部署時自動調用
    fun init(ctx: &mut TxContext) {
        let platform = tx_context::sender(ctx);

        // 創建退款池
        let pool = RefundPoolV2 {
            id: object::new(ctx),
            balance: balance::zero<SUI>(),
            platform_address: platform,
            total_refunded: 0,
        };
        transfer::share_object(pool);

        // 創建退款能力並轉移給平台
        let cap = RefundCapability {
            id: object::new(ctx),
            platform_address: platform,
        };
        transfer::transfer(cap, platform);
    }

    /// 用戶直接創建退款請求（無需平台簽署）
    public entry fun create_refund_request(
        trip_id: u64,
        original_amount: u64,
        refund_amount: u64,
        reason: vector<u8>,
        ctx: &mut TxContext
    ) {
        let requester = tx_context::sender(ctx);
        let current_time = tx_context::epoch(ctx);

        let refund_request = RefundRequest {
            id: object::new(ctx),
            trip_id,
            requester,
            original_amount,
            refund_amount,
            reason,
            status: STATUS_PENDING,
            created_at: current_time,
        };

        let refund_id = object::uid_to_address(&refund_request.id);

        // 發出退款請求事件
        event::emit(RefundEvent {
            refund_id,
            trip_id,
            requester,
            amount: refund_amount,
            status: STATUS_PENDING,
        });

        // 將退款請求轉移給用戶自己
        transfer::transfer(refund_request, requester);
    }

    /// 平台向退款池注資（使用 Balance）
    public entry fun fund_pool(
        pool: &mut RefundPoolV2,
        payment: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        // 只有平台可以注資
        assert!(tx_context::sender(ctx) == pool.platform_address, E_NOT_AUTHORIZED);

        let coin_balance = coin::into_balance(payment);
        balance::join(&mut pool.balance, coin_balance);
    }

    /// 用戶提交退款請求到池（用於自動執行）
    public entry fun submit_for_auto_refund(
        request: RefundRequest,
        pool: &mut RefundPoolV2,
        ctx: &mut TxContext
    ) {
        let RefundRequest {
            id,
            trip_id,
            requester,
            original_amount: _,
            refund_amount,
            reason: _,
            status,
            created_at: _,
        } = request;

        // 驗證狀態
        assert!(status == STATUS_PENDING, E_INVALID_STATUS);

        // 檢查退款池餘額
        let pool_balance = balance::value(&pool.balance);
        assert!(pool_balance >= refund_amount, E_INSUFFICIENT_BALANCE);

        // 從退款池提取資金
        let refund_balance = balance::split(&mut pool.balance, refund_amount);
        let refund_coin = coin::from_balance(refund_balance, ctx);

        // 直接轉帳給請求者
        transfer::public_transfer(refund_coin, requester);

        // 更新統計
        pool.total_refunded = pool.total_refunded + refund_amount;

        // 發出退款完成事件
        let refund_id = object::uid_to_address(&id);
        event::emit(RefundEvent {
            refund_id,
            trip_id,
            requester,
            amount: refund_amount,
            status: STATUS_COMPLETED,
        });

        // 刪除請求對象
        object::delete(id);
    }

    /// 平台批准並執行退款（需要 RefundCapability）
    public entry fun approve_and_execute(
        _cap: &RefundCapability,
        request: RefundRequest,
        pool: &mut RefundPoolV2,
        ctx: &mut TxContext
    ) {
        let RefundRequest {
            id,
            trip_id,
            requester,
            original_amount: _,
            refund_amount,
            reason: _,
            status,
            created_at: _,
        } = request;

        // 驗證狀態
        assert!(status == STATUS_PENDING, E_INVALID_STATUS);

        // 檢查退款池餘額
        let pool_balance = balance::value(&pool.balance);
        assert!(pool_balance >= refund_amount, E_INSUFFICIENT_BALANCE);

        // 從退款池提取資金
        let refund_balance = balance::split(&mut pool.balance, refund_amount);
        let refund_coin = coin::from_balance(refund_balance, ctx);

        // 轉帳給請求者
        transfer::public_transfer(refund_coin, requester);

        // 更新統計
        pool.total_refunded = pool.total_refunded + refund_amount;

        // 發出事件
        let refund_id = object::uid_to_address(&id);
        event::emit(RefundEvent {
            refund_id,
            trip_id,
            requester,
            amount: refund_amount,
            status: STATUS_COMPLETED,
        });

        // 刪除請求對象
        object::delete(id);
    }

    /// 查詢退款池餘額
    public fun get_pool_balance(pool: &RefundPoolV2): u64 {
        balance::value(&pool.balance)
    }

    /// 查詢總退款金額
    public fun get_total_refunded(pool: &RefundPoolV2): u64 {
        pool.total_refunded
    }
}
