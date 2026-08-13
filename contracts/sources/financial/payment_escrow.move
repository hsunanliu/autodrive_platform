/// 支付託管 (Payment Escrow)
///
/// 乘客鎖定車資 → 行程完成後釋放給司機/平台，或取消時退款給乘客。
///
/// 安全模型（相對於舊版的重點修正）：
///   - 釋放不再「任何人都可調用」。只接受兩種授權來源：
///       (a) 乘客本人簽章（release_payment）
///       (b) Agent 持有效 OperatorCap 且該 cap 的 user == 乘客（release_payment_by_agent）
///   - 手續費由 PLATFORM_FEE_RATE 於鏈上計算，呼叫者無法自填 0 費。
///   - 釋放/退款皆以 by-value 消費 Escrow 並 object::delete，避免每趟殘留零餘額共享物件。
module autodrive::payment_escrow {
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::clock::Clock;
    use sui::event;
    use autodrive::agent_registry::{Self, OperatorCap};
    use decentralized_ride::constants;
    use decentralized_ride::trip_receipt;

    /// 託管狀態
    const STATUS_LOCKED: u8 = 1;

    /// 錯誤碼
    const E_INVALID_STATUS: u64 = 1;
    const E_TRIP_ID_MISMATCH: u64 = 2;
    const E_NOT_AUTHORIZED: u64 = 5;
    const E_INSUFFICIENT_AMOUNT: u64 = 4;
    const E_DISPUTED: u64 = 6;          // 爭議中，不可結算
    const E_INVALID_RULING: u64 = 7;    // 仲裁判決值非法

    /// 最低車資地板（0.001 SUI）。杜絕 0 元/塵埃金額車資（配合防 0 元車資，威脅 T10）。
    const MIN_PAYMENT_MIST: u64 = 1_000_000;

    /// 仲裁判決
    const RULING_DRIVER: u8 = 1;    // 判給司機（走 release）
    const RULING_PASSENGER: u8 = 2; // 退乘客（走 refund）

    /// 託管對象（shared，讓乘客/Agent 皆可在授權下操作）
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
        /// 爭議凍結旗標：raise_dispute 設 true，release/refund 一律被擋，只能由仲裁 resolve。
        disputed: bool,
    }

    /// 仲裁能力（部署時發給平台/仲裁者）
    public struct ArbiterCap has key, store { id: UID }

    /// 爭議記錄（shared，供仲裁者存取）
    public struct Dispute has key {
        id: UID,
        escrow_id: address,
        trip_id: u64,
        raised_by: address,
        reason: vector<u8>,
    }

    fun init(ctx: &mut TxContext) {
        transfer::transfer(ArbiterCap { id: object::new(ctx) }, tx_context::sender(ctx));
    }

    // ============================================================
    // 事件
    // ============================================================
    public struct PaymentLocked has copy, drop {
        escrow_id: address,
        trip_id: u64,
        passenger: address,
        total_amount: u64,
        driver_amount: u64,
        platform_fee: u64,
    }

    public struct PaymentReleased has copy, drop {
        trip_id: u64,
        driver: address,
        driver_amount: u64,
        platform_fee: u64,
        by_agent: bool,
    }

    public struct PaymentRefunded has copy, drop {
        trip_id: u64,
        passenger: address,
        amount: u64,
        by_agent: bool,
    }

    public struct DisputeRaised has copy, drop {
        escrow_id: address,
        trip_id: u64,
        raised_by: address,
    }

    public struct DisputeResolved has copy, drop {
        trip_id: u64,
        ruling: u8,
    }

    // ============================================================
    // 鎖定
    // ============================================================

    /// 鎖定支付 - 乘客調用。手續費由鏈上費率計算。
    public entry fun lock_payment(
        payment: Coin<SUI>,
        trip_id: u64,
        driver: address,
        platform: address,
        ctx: &mut TxContext
    ) {
        let total_amount = coin::value(&payment);
        // 車資地板：拒絕 0 元/塵埃金額
        assert!(total_amount >= MIN_PAYMENT_MIST, E_INSUFFICIENT_AMOUNT);

        // 平台費 = 總額 * 費率(bps) / 10000，於鏈上計算，呼叫者無法竄改
        let platform_fee =
            total_amount * constants::platform_fee_rate() / constants::basis_points_denominator();
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
            disputed: false,
        };

        event::emit(PaymentLocked {
            escrow_id: object::uid_to_address(&escrow.id),
            trip_id,
            passenger,
            total_amount,
            driver_amount,
            platform_fee,
        });

        transfer::share_object(escrow);
    }

    // ============================================================
    // 釋放（消費並刪除 Escrow）
    // ============================================================

    /// 乘客本人確認行程完成並釋放款項。
    public entry fun release_payment(
        escrow: Escrow,
        trip_id: u64,
        ctx: &mut TxContext
    ) {
        assert!(escrow.status == STATUS_LOCKED, E_INVALID_STATUS);
        assert!(!escrow.disputed, E_DISPUTED);
        assert!(escrow.trip_id == trip_id, E_TRIP_ID_MISMATCH);
        assert!(tx_context::sender(ctx) == escrow.passenger, E_NOT_AUTHORIZED);
        settle_release(escrow, false, ctx);
    }

    /// Agent 代表乘客釋放款項，需持有該乘客簽發、且允許 RELEASE_ESCROW 動作的 OperatorCap。
    public entry fun release_payment_by_agent(
        escrow: Escrow,
        cap: &mut OperatorCap,
        trip_id: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(escrow.status == STATUS_LOCKED, E_INVALID_STATUS);
        assert!(!escrow.disputed, E_DISPUTED);
        assert!(escrow.trip_id == trip_id, E_TRIP_ID_MISMATCH);
        let authorized_user = agent_registry::authorize_action(
            cap,
            agent_registry::action_release_escrow(),
            escrow.total_amount,
            clock,
            ctx
        );
        assert!(authorized_user == escrow.passenger, E_NOT_AUTHORIZED);
        settle_release(escrow, true, ctx);
    }

    /// 複合原子結算（PTB 友善）：Agent 一次呼叫同時「釋放託管 + 開立行程收據」。
    /// 相較於分兩筆交易（release 一筆、create_receipt 一筆），這裡合併為單一交易：
    ///   - 原子性：兩步全成或全敗，不會出現「已放款但沒收據」的中間態。
    ///   - 省 gas：只付一次交易與 gas 開銷。
    /// 收據歸屬 escrow.passenger（發起者是 Agent，故用 create_receipt_for 明確指定乘客）。
    public entry fun release_and_receipt_by_agent(
        escrow: Escrow,
        cap: &mut OperatorCap,
        trip_id: u64,
        pickup_hash: vector<u8>,
        dropoff_hash: vector<u8>,
        distance_km: u64,
        trajectory_blob_id: vector<u8>,
        trajectory_hash: vector<u8>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(escrow.status == STATUS_LOCKED, E_INVALID_STATUS);
        assert!(!escrow.disputed, E_DISPUTED);
        assert!(escrow.trip_id == trip_id, E_TRIP_ID_MISMATCH);
        let authorized_user = agent_registry::authorize_action(
            cap,
            agent_registry::action_release_escrow(),
            escrow.total_amount,
            clock,
            ctx
        );
        assert!(authorized_user == escrow.passenger, E_NOT_AUTHORIZED);

        let Escrow {
            id, trip_id: tid, passenger, driver, platform,
            total_amount, driver_amount, platform_fee, payment, status: _, disputed: _,
        } = escrow;

        let mut payment = payment;
        let driver_coin = coin::split(&mut payment, driver_amount, ctx);
        let platform_coin = coin::split(&mut payment, platform_fee, ctx);
        transfer::public_transfer(driver_coin, driver);
        transfer::public_transfer(platform_coin, platform);
        coin::destroy_zero(payment);

        // 同一交易內原子性地開立收據給乘客（錨定軌跡 Walrus blob）
        trip_receipt::create_receipt_for(
            passenger, tid, driver, pickup_hash, dropoff_hash,
            distance_km, total_amount, trajectory_blob_id, trajectory_hash, ctx
        );

        event::emit(PaymentReleased { trip_id: tid, driver, driver_amount, platform_fee, by_agent: true });
        object::delete(id);
    }

    fun settle_release(escrow: Escrow, by_agent: bool, ctx: &mut TxContext) {
        let Escrow {
            id, trip_id, passenger: _, driver, platform,
            total_amount: _, driver_amount, platform_fee, payment, status: _, disputed: _,
        } = escrow;

        let mut payment = payment;
        let driver_coin = coin::split(&mut payment, driver_amount, ctx);
        let platform_coin = coin::split(&mut payment, platform_fee, ctx);
        transfer::public_transfer(driver_coin, driver);
        transfer::public_transfer(platform_coin, platform);
        // 剩餘應為 0（driver_amount + platform_fee == total_amount）
        coin::destroy_zero(payment);

        event::emit(PaymentReleased { trip_id, driver, driver_amount, platform_fee, by_agent });
        object::delete(id);
    }

    // ============================================================
    // 退款（消費並刪除 Escrow）
    // ============================================================

    /// 取消行程退款 - 乘客或司機皆可發起，款項一律退回乘客。
    public entry fun refund_payment(escrow: Escrow, ctx: &mut TxContext) {
        assert!(escrow.status == STATUS_LOCKED, E_INVALID_STATUS);
        assert!(!escrow.disputed, E_DISPUTED);
        let sender = tx_context::sender(ctx);
        assert!(sender == escrow.passenger || sender == escrow.driver, E_NOT_AUTHORIZED);
        settle_refund(escrow, false);
    }

    /// Agent 代表乘客退款，需持有該乘客簽發、且允許 REFUND 動作的 OperatorCap。
    public entry fun refund_payment_by_agent(
        escrow: Escrow,
        cap: &mut OperatorCap,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(escrow.status == STATUS_LOCKED, E_INVALID_STATUS);
        assert!(!escrow.disputed, E_DISPUTED);
        let authorized_user = agent_registry::authorize_action(
            cap,
            agent_registry::action_refund(),
            escrow.total_amount,
            clock,
            ctx
        );
        assert!(authorized_user == escrow.passenger, E_NOT_AUTHORIZED);
        settle_refund(escrow, true);
    }

    fun settle_refund(escrow: Escrow, by_agent: bool) {
        let Escrow {
            id, trip_id, passenger, driver: _, platform: _,
            total_amount, driver_amount: _, platform_fee: _, payment, status: _, disputed: _,
        } = escrow;

        transfer::public_transfer(payment, passenger);
        event::emit(PaymentRefunded { trip_id, passenger, amount: total_amount, by_agent });
        object::delete(id);
    }

    // ============================================================
    // 爭議（凍結 → 仲裁）
    // ============================================================

    /// 乘客或司機發起爭議 → 凍結該筆 escrow（release/refund 全被擋），建立 Dispute 記錄。
    public entry fun raise_dispute(
        escrow: &mut Escrow,
        reason: vector<u8>,
        ctx: &mut TxContext
    ) {
        assert!(escrow.status == STATUS_LOCKED, E_INVALID_STATUS);
        assert!(!escrow.disputed, E_DISPUTED);
        let sender = tx_context::sender(ctx);
        assert!(sender == escrow.passenger || sender == escrow.driver, E_NOT_AUTHORIZED);

        escrow.disputed = true;
        let escrow_addr = object::uid_to_address(&escrow.id);
        let dispute = Dispute {
            id: object::new(ctx),
            escrow_id: escrow_addr,
            trip_id: escrow.trip_id,
            raised_by: sender,
            reason,
        };
        event::emit(DisputeRaised { escrow_id: escrow_addr, trip_id: escrow.trip_id, raised_by: sender });
        transfer::share_object(dispute);
    }

    /// 仲裁者（持 ArbiterCap）裁決爭議：判給司機（release）或退乘客（refund）。
    /// 消費 Dispute 與 Escrow，繞過凍結 guard（此為唯一授權的結算路徑）。
    public entry fun resolve_dispute(
        _arbiter: &ArbiterCap,
        escrow: Escrow,
        dispute: Dispute,
        ruling: u8,
        ctx: &mut TxContext
    ) {
        assert!(escrow.disputed, E_INVALID_STATUS);
        assert!(ruling == RULING_DRIVER || ruling == RULING_PASSENGER, E_INVALID_RULING);

        let Dispute { id: did, escrow_id: _, trip_id: _, raised_by: _, reason: _ } = dispute;
        object::delete(did);

        let tid = escrow.trip_id;
        if (ruling == RULING_DRIVER) {
            settle_release(escrow, true, ctx);
        } else {
            settle_refund(escrow, true);
        };
        event::emit(DisputeResolved { trip_id: tid, ruling });
    }

    public fun ruling_driver(): u8 { RULING_DRIVER }
    public fun ruling_passenger(): u8 { RULING_PASSENGER }

    // ============================================================
    // 視圖函數
    // ============================================================
    public fun get_status(escrow: &Escrow): u8 { escrow.status }
    public fun is_disputed(escrow: &Escrow): bool { escrow.disputed }
    public fun get_trip_id(escrow: &Escrow): u64 { escrow.trip_id }
    public fun get_passenger(escrow: &Escrow): address { escrow.passenger }
    public fun get_total_amount(escrow: &Escrow): u64 { escrow.total_amount }

    #[test_only]
    public fun new_arbiter_cap_for_testing(ctx: &mut TxContext): ArbiterCap {
        ArbiterCap { id: object::new(ctx) }
    }

    #[test_only]
    public fun destroy_arbiter_cap_for_testing(cap: ArbiterCap) {
        let ArbiterCap { id } = cap;
        object::delete(id);
    }
}
