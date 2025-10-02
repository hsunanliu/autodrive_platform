module decentralized_ride::payment_escrow {
    use iota::object::{Self, UID, ID};
    use iota::tx_context::{Self, TxContext};
    use iota::transfer;
    use iota::coin::{Self, Coin};
    use iota::iota::IOTA;
    use decentralized_ride::constants;
    use decentralized_ride::events;

    /// 支付託管 - 僅處理資金鎖定與釋放
    public struct PaymentEscrow has key, store {
        id: UID,
        trip_id: u64,                    // 後端行程ID
        passenger: address,              // 乘客地址
        driver: address,                 // 司機地址
        locked_amount: u64,              // 鎖定金額
        platform_fee: u64,               // 平台費用
        status: u8,                      // 0:locked, 1:released, 2:refunded
        created_at: u64,
    }

    /// 鎖定支付 - 行程開始時調用
    public entry fun lock_payment(
        passenger_coin: Coin<IOTA>,
        trip_id: u64,
        driver: address,
        platform_fee: u64,
        ctx: &mut TxContext
    ) {
        let passenger = tx_context::sender(ctx);
        let locked_amount = coin::value(&passenger_coin);
        
        assert!(locked_amount > platform_fee, constants::e_insufficient_funds());
        
        let escrow = PaymentEscrow {
            id: object::new(ctx),
            trip_id,
            passenger,
            driver,
            locked_amount,
            platform_fee,
            status: 0, // locked
            created_at: tx_context::epoch(ctx),
        };
        
        // 將代幣轉移到託管對象
        transfer::public_transfer(passenger_coin, @platform_treasury);
        
        events::emit_funds_locked(
            object::id(&escrow),
            object::id_from_address(passenger), // 臨時使用
            locked_amount,
            ctx
        );
        
        transfer::share_object(escrow);
    }

    /// 釋放支付 - 行程完成時調用
    public entry fun release_payment(
        escrow: &mut PaymentEscrow,
        driver_verification: &driver_registry::DriverProfile, // 驗證司機身份
        ctx: &mut TxContext
    ) {
        assert!(escrow.status == 0, constants::e_invalid_status());
        assert!(tx_context::sender(ctx) == escrow.driver, constants::e_unauthorized());
        
        escrow.status = 1; // released
        
        // 實際支付邏輯會在這裡執行
        // 這裡簡化：只更新狀態，實際轉賬由平台處理
        
        events::emit_funds_released(
            object::id(escrow),
            escrow.driver,
            escrow.locked_amount - escrow.platform_fee,
            ctx
        );
    }

    /// 退款 - 行程取消時調用
    public entry fun refund_payment(
        escrow: &mut PaymentEscrow,
        ctx: &mut TxContext
    ) {
        // 只有乘客或平台管理員可以退款
        let sender = tx_context::sender(ctx);
        assert!(
            sender == escrow.passenger || sender == @platform_admin,
            constants::e_unauthorized()
        );
        assert!(escrow.status == 0, constants::e_invalid_status());
        
        escrow.status = 2; // refunded
    }

    // === 查詢函數 ===
    public fun get_escrow_status(escrow: &PaymentEscrow): (u64, address, address, u64, u8) {
        (escrow.trip_id, escrow.passenger, escrow.driver, escrow.locked_amount, escrow.status)
    }
}