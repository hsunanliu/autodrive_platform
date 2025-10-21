module autodrive::payment_escrow {
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    
    /// 託管狀態
    const STATUS_LOCKED: u8 = 1;
    const STATUS_RELEASED: u8 = 2;
    const STATUS_REFUNDED: u8 = 3;
    
    /// 錯誤碼
    const E_INVALID_STATUS: u64 = 1;
    const E_TRIP_ID_MISMATCH: u64 = 2;
    const E_NOT_PASSENGER: u64 = 3;
    const E_INSUFFICIENT_AMOUNT: u64 = 4;
    
    /// 託管對象
    public struct Escrow has key, store {
        id: UID,
        trip_id: u64,
        passenger: address,
        driver: address,
        platform: address,
        total_amount: u64,
        driver_amount: u64,
        platform_fee: u64,
        payment: Coin<SUI>,
        status: u8,
    }
    
    /// 鎖定支付 - 乘客調用
    public entry fun lock_payment(
        payment: Coin<SUI>,
        trip_id: u64,
        driver: address,
        platform: address,
        platform_fee: u64,
        ctx: &mut TxContext
    ) {
        let total_amount = coin::value(&payment);
        assert!(total_amount > platform_fee, E_INSUFFICIENT_AMOUNT);
        
        let driver_amount = total_amount - platform_fee;
        let passenger = tx_context::sender(ctx);
        
        let escrow = Escrow {
            id: object::new(ctx),
            trip_id,
            passenger,
            driver,
            platform,
            total_amount,
            driver_amount,
            platform_fee,
            payment,
            status: STATUS_LOCKED,
        };
        
        // 轉移託管對象給平台（或共享對象）
        transfer::share_object(escrow);
    }
    
    /// 釋放支付 - 任何人都可以調用（通常是後端）
    public entry fun release_payment(
        escrow: &mut Escrow,
        trip_id: u64,
        ctx: &mut TxContext
    ) {
        // 驗證狀態
        assert!(escrow.status == STATUS_LOCKED, E_INVALID_STATUS);
        // 驗證 trip_id
        assert!(escrow.trip_id == trip_id, E_TRIP_ID_MISMATCH);
        
        // 分割支付
        let driver_coin = coin::split(&mut escrow.payment, escrow.driver_amount, ctx);
        let platform_coin = coin::split(&mut escrow.payment, escrow.platform_fee, ctx);
        
        // 轉帳給司機
        transfer::public_transfer(driver_coin, escrow.driver);
        
        // 轉帳平台費用
        transfer::public_transfer(platform_coin, escrow.platform);
        
        // 更新狀態
        escrow.status = STATUS_RELEASED;
    }
    
    /// 退款 - 只有乘客可以調用（取消行程時）
    public entry fun refund_payment(
        escrow: &mut Escrow,
        ctx: &mut TxContext
    ) {
        // 驗證狀態
        assert!(escrow.status == STATUS_LOCKED, E_INVALID_STATUS);
        // 驗證調用者是乘客
        assert!(tx_context::sender(ctx) == escrow.passenger, E_NOT_PASSENGER);
        
        // 取出全部金額
        let refund_amount = coin::value(&escrow.payment);
        let refund_coin = coin::split(&mut escrow.payment, refund_amount, ctx);
        
        // 退款給乘客
        transfer::public_transfer(refund_coin, escrow.passenger);
        
        // 更新狀態
        escrow.status = STATUS_REFUNDED;
    }
    
    /// 查詢託管狀態
    public fun get_status(escrow: &Escrow): u8 {
        escrow.status
    }
    
    /// 查詢行程 ID
    public fun get_trip_id(escrow: &Escrow): u64 {
        escrow.trip_id
    }
}
