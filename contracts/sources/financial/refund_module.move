module autodrive::refund_module {
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::event;

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

    /// 退款請求對象
    public struct RefundRequest has key, store {
        id: UID,
        trip_id: u64,
        requester: address,          // 退款請求者（乘客或司機）
        escrow_object_id: address,   // 原始 Escrow Object ID
        original_amount: u64,        // 原始支付金額
        refund_amount: u64,          // 退款金額
        reason: vector<u8>,          // 退款原因
        status: u8,                  // 退款狀態
        created_at: u64,             // 創建時間戳
        approved_at: u64,            // 批准時間戳
    }

    /// 退款池 - 平台資金池用於處理退款
    public struct RefundPool has key {
        id: UID,
        balance: Coin<SUI>,
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

    /// 初始化退款池（部署時調用一次）
    public entry fun init_refund_pool(ctx: &mut TxContext) {
        let pool = RefundPool {
            id: object::new(ctx),
            balance: coin::zero<SUI>(ctx),
            platform_address: tx_context::sender(ctx),
            total_refunded: 0,
        };
        transfer::share_object(pool);
    }

    /// 平台向退款池注資
    public entry fun fund_refund_pool(
        pool: &mut RefundPool,
        payment: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        // 只有平台可以注資
        assert!(tx_context::sender(ctx) == pool.platform_address, E_NOT_AUTHORIZED);

        let amount = coin::value(&payment);
        coin::join(&mut pool.balance, payment);
    }

    /// 創建退款請求（任何人都可以請求）
    public entry fun create_refund_request(
        trip_id: u64,
        escrow_object_id: address,
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
            escrow_object_id,
            original_amount,
            refund_amount,
            reason,
            status: STATUS_PENDING,
            created_at: current_time,
            approved_at: 0,
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

        // 共享退款請求對象
        transfer::share_object(refund_request);
    }

    /// 批准退款並執行（僅平台可調用）
    public entry fun approve_and_execute_refund(
        request: &mut RefundRequest,
        pool: &mut RefundPool,
        ctx: &mut TxContext
    ) {
        // 驗證調用者是平台
        assert!(tx_context::sender(ctx) == pool.platform_address, E_NOT_AUTHORIZED);

        // 驗證狀態
        assert!(request.status == STATUS_PENDING, E_INVALID_STATUS);

        // 檢查退款池餘額
        let pool_balance = coin::value(&pool.balance);
        assert!(pool_balance >= request.refund_amount, E_INSUFFICIENT_BALANCE);

        // 從退款池分離退款金額
        let refund_coin = coin::split(&mut pool.balance, request.refund_amount, ctx);

        // 轉帳給請求者
        transfer::public_transfer(refund_coin, request.requester);

        // 更新狀態
        request.status = STATUS_COMPLETED;
        request.approved_at = tx_context::epoch(ctx);
        pool.total_refunded = pool.total_refunded + request.refund_amount;

        // 發出退款完成事件
        let refund_id = object::uid_to_address(&request.id);
        event::emit(RefundEvent {
            refund_id,
            trip_id: request.trip_id,
            requester: request.requester,
            amount: request.refund_amount,
            status: STATUS_COMPLETED,
        });
    }

    /// 拒絕退款（僅平台可調用）
    public entry fun reject_refund(
        request: &mut RefundRequest,
        pool: &RefundPool,
        ctx: &mut TxContext
    ) {
        // 驗證調用者是平台
        assert!(tx_context::sender(ctx) == pool.platform_address, E_NOT_AUTHORIZED);

        // 驗證狀態
        assert!(request.status == STATUS_PENDING, E_INVALID_STATUS);

        // 更新狀態
        request.status = STATUS_REJECTED;

        // 發出退款拒絕事件
        let refund_id = object::uid_to_address(&request.id);
        event::emit(RefundEvent {
            refund_id,
            trip_id: request.trip_id,
            requester: request.requester,
            amount: request.refund_amount,
            status: STATUS_REJECTED,
        });
    }

    /// 查詢退款狀態
    public fun get_refund_status(request: &RefundRequest): u8 {
        request.status
    }

    /// 查詢退款金額
    public fun get_refund_amount(request: &RefundRequest): u64 {
        request.refund_amount
    }

    /// 查詢退款池餘額
    public fun get_pool_balance(pool: &RefundPool): u64 {
        coin::value(&pool.balance)
    }
}
