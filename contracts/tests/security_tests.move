/// 安全性回歸測試
///
/// 針對本次生產級加固修復的核心行為，用可執行測試釘死：
///   - 託管釋放/退款的授權（乘客本人 / OperatorCap）
///   - OperatorCap 的額度與撤銷邊界
///   - 評價必須綁定行程收據
///   - 信譽更新僅限平台 admin（防自我提權）
#[test_only]
module autodrive::security_tests {
    use sui::test_scenario as ts;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use autodrive::payment_escrow::{Self, Escrow, Dispute};
    use autodrive::agent_registry::{Self, OperatorCap};
    use decentralized_ride::user_registry::{Self, UserRegistry, UserProfile};
    use decentralized_ride::trip_receipt::{Self, TripReceipt};
    use decentralized_ride::rating_proof::{Self, VehicleRatingStats};
    use autodrive::did_registry::{Self, DIDRegistry};
    use autodrive::profile::{Self, PassengerProfile};
    use autodrive::refund_module_v2::{Self, RefundPoolV2, RefundCapability};
    use std::string;

    const PASSENGER: address = @0xA1;
    const DRIVER: address = @0xD1;
    const PLATFORM: address = @0xF0;
    const AGENT: address = @0xA6;
    const BOB: address = @0xB0;
    const ADMIN: address = @0xAD;

    // 1_000_000 MIST（0.001 SUI，達車資地板）、費率 2.5% → 平台費 25_000、司機 975_000
    const AMOUNT: u64 = 1_000_000;
    const DRIVER_AMT: u64 = 975_000;
    const FEE_AMT: u64 = 25_000;

    fun zero_hash32(): vector<u8> {
        x"0000000000000000000000000000000000000000000000000000000000000000"
    }

    // ============================================================
    // 託管：乘客本人釋放
    // ============================================================
    #[test]
    fun test_escrow_passenger_release_success() {
        let mut sc = ts::begin(PASSENGER);
        {
            let c = coin::mint_for_testing<SUI>(AMOUNT, ts::ctx(&mut sc));
            payment_escrow::lock_payment(c, 1, DRIVER, PLATFORM, ts::ctx(&mut sc));
        };
        ts::next_tx(&mut sc, PASSENGER);
        {
            let escrow = ts::take_shared<Escrow>(&sc);
            payment_escrow::release_payment(escrow, 1, ts::ctx(&mut sc));
        };
        // 司機收到 975
        ts::next_tx(&mut sc, DRIVER);
        {
            let c = ts::take_from_address<Coin<SUI>>(&sc, DRIVER);
            assert!(coin::value(&c) == DRIVER_AMT, 0);
            coin::burn_for_testing(c);
        };
        // 平台收到 25
        ts::next_tx(&mut sc, PLATFORM);
        {
            let c = ts::take_from_address<Coin<SUI>>(&sc, PLATFORM);
            assert!(coin::value(&c) == FEE_AMT, 1);
            coin::burn_for_testing(c);
        };
        ts::end(sc);
    }

    // 非乘客釋放應被拒（E_NOT_AUTHORIZED = 5）
    #[test]
    #[expected_failure(abort_code = 5, location = autodrive::payment_escrow)]
    fun test_escrow_unauthorized_release_aborts() {
        let mut sc = ts::begin(PASSENGER);
        {
            let c = coin::mint_for_testing<SUI>(AMOUNT, ts::ctx(&mut sc));
            payment_escrow::lock_payment(c, 1, DRIVER, PLATFORM, ts::ctx(&mut sc));
        };
        ts::next_tx(&mut sc, BOB);
        {
            let escrow = ts::take_shared<Escrow>(&sc);
            payment_escrow::release_payment(escrow, 1, ts::ctx(&mut sc));
        };
        ts::end(sc);
    }

    // 退款一律回到乘客
    #[test]
    fun test_refund_returns_to_passenger() {
        let mut sc = ts::begin(PASSENGER);
        {
            let c = coin::mint_for_testing<SUI>(AMOUNT, ts::ctx(&mut sc));
            payment_escrow::lock_payment(c, 1, DRIVER, PLATFORM, ts::ctx(&mut sc));
        };
        ts::next_tx(&mut sc, PASSENGER);
        {
            let escrow = ts::take_shared<Escrow>(&sc);
            payment_escrow::refund_payment(escrow, ts::ctx(&mut sc));
        };
        ts::next_tx(&mut sc, PASSENGER);
        {
            let c = ts::take_from_address<Coin<SUI>>(&sc, PASSENGER);
            assert!(coin::value(&c) == AMOUNT, 0);
            coin::burn_for_testing(c);
        };
        ts::end(sc);
    }

    // ============================================================
    // Agent 委託釋放
    // ============================================================
    #[test]
    fun test_agent_release_with_valid_cap() {
        let mut sc = ts::begin(PASSENGER);
        { let clk = clock::create_for_testing(ts::ctx(&mut sc)); clock::share_for_testing(clk); };
        ts::next_tx(&mut sc, PASSENGER);
        {
            let clk = ts::take_shared<Clock>(&sc);
            agent_registry::issue_operator_cap(
                AGENT, 2_000_000, 5_000_000, 1_000_000,
                agent_registry::action_release_escrow(), &clk, ts::ctx(&mut sc)
            );
            ts::return_shared(clk);
            let c = coin::mint_for_testing<SUI>(AMOUNT, ts::ctx(&mut sc));
            payment_escrow::lock_payment(c, 7, DRIVER, PLATFORM, ts::ctx(&mut sc));
        };
        ts::next_tx(&mut sc, AGENT);
        {
            let escrow = ts::take_shared<Escrow>(&sc);
            let mut cap = ts::take_shared<OperatorCap>(&sc);
            let clk = ts::take_shared<Clock>(&sc);
            payment_escrow::release_payment_by_agent(escrow, &mut cap, 7, &clk, ts::ctx(&mut sc));
            ts::return_shared(cap);
            ts::return_shared(clk);
        };
        ts::next_tx(&mut sc, DRIVER);
        {
            let c = ts::take_from_address<Coin<SUI>>(&sc, DRIVER);
            assert!(coin::value(&c) == DRIVER_AMT, 0);
            coin::burn_for_testing(c);
        };
        ts::end(sc);
    }

    // 超過單筆額度上限應被拒（agent_registry E_OVER_TX_LIMIT = 6）
    #[test]
    #[expected_failure(abort_code = 6, location = autodrive::agent_registry)]
    fun test_agent_release_over_limit_aborts() {
        let mut sc = ts::begin(PASSENGER);
        { let clk = clock::create_for_testing(ts::ctx(&mut sc)); clock::share_for_testing(clk); };
        ts::next_tx(&mut sc, PASSENGER);
        {
            let clk = ts::take_shared<Clock>(&sc);
            // max_spend_per_tx = 500 < 1000
            agent_registry::issue_operator_cap(
                AGENT, 500_000, 5_000_000, 1_000_000,
                agent_registry::action_release_escrow(), &clk, ts::ctx(&mut sc)
            );
            ts::return_shared(clk);
            let c = coin::mint_for_testing<SUI>(AMOUNT, ts::ctx(&mut sc));
            payment_escrow::lock_payment(c, 7, DRIVER, PLATFORM, ts::ctx(&mut sc));
        };
        ts::next_tx(&mut sc, AGENT);
        {
            let escrow = ts::take_shared<Escrow>(&sc);
            let mut cap = ts::take_shared<OperatorCap>(&sc);
            let clk = ts::take_shared<Clock>(&sc);
            payment_escrow::release_payment_by_agent(escrow, &mut cap, 7, &clk, ts::ctx(&mut sc));
            ts::return_shared(cap);
            ts::return_shared(clk);
        };
        ts::end(sc);
    }

    // 已撤銷的 cap 不能再動用（agent_registry E_REVOKED = 3）
    #[test]
    #[expected_failure(abort_code = 3, location = autodrive::agent_registry)]
    fun test_agent_revoked_cap_aborts() {
        let mut sc = ts::begin(PASSENGER);
        { let clk = clock::create_for_testing(ts::ctx(&mut sc)); clock::share_for_testing(clk); };
        ts::next_tx(&mut sc, PASSENGER);
        {
            let clk = ts::take_shared<Clock>(&sc);
            agent_registry::issue_operator_cap(
                AGENT, 2_000_000, 5_000_000, 1_000_000,
                agent_registry::action_release_escrow(), &clk, ts::ctx(&mut sc)
            );
            ts::return_shared(clk);
            let c = coin::mint_for_testing<SUI>(AMOUNT, ts::ctx(&mut sc));
            payment_escrow::lock_payment(c, 7, DRIVER, PLATFORM, ts::ctx(&mut sc));
        };
        // 乘客撤銷授權
        ts::next_tx(&mut sc, PASSENGER);
        {
            let mut cap = ts::take_shared<OperatorCap>(&sc);
            agent_registry::revoke(&mut cap, ts::ctx(&mut sc));
            ts::return_shared(cap);
        };
        // Agent 仍嘗試釋放 → 應被拒
        ts::next_tx(&mut sc, AGENT);
        {
            let escrow = ts::take_shared<Escrow>(&sc);
            let mut cap = ts::take_shared<OperatorCap>(&sc);
            let clk = ts::take_shared<Clock>(&sc);
            payment_escrow::release_payment_by_agent(escrow, &mut cap, 7, &clk, ts::ctx(&mut sc));
            ts::return_shared(cap);
            ts::return_shared(clk);
        };
        ts::end(sc);
    }

    // ============================================================
    // 評價綁定行程
    // ============================================================
    #[test]
    fun test_rating_with_valid_receipt_success() {
        let mut sc = ts::begin(PASSENGER);
        // 乘客持有行程收據
        {
            trip_receipt::create_receipt(
                1, DRIVER, b"pick", b"drop", 5, 1000,
                b"", b"", ts::ctx(&mut sc)
            );
        };
        // 平台以 admin cap 建立車輛統計
        ts::next_tx(&mut sc, ADMIN);
        {
            let cap = rating_proof::new_admin_cap_for_testing(ts::ctx(&mut sc));
            rating_proof::create_vehicle_stats(&cap, b"veh123", ts::ctx(&mut sc));
            rating_proof::destroy_admin_cap_for_testing(cap);
        };
        // 乘客用收據評價
        ts::next_tx(&mut sc, PASSENGER);
        {
            let receipt = ts::take_from_sender<TripReceipt>(&sc);
            let mut stats = ts::take_shared<VehicleRatingStats>(&sc);
            rating_proof::create_rating_proof(
                &receipt, &mut stats, 100, 1, b"veh123", 5, zero_hash32(), b"blob1",
                ts::ctx(&mut sc)
            );
            let (total, _, _, _, _, _, _) = rating_proof::get_stats_info(&stats);
            assert!(total == 1, 0);
            ts::return_shared(stats);
            ts::return_to_sender(&sc, receipt);
        };
        ts::end(sc);
    }

    // trip_id 與收據不符應被拒（rating_proof ERR_TRIP_ID_MISMATCH = 4）
    #[test]
    #[expected_failure(abort_code = 4, location = decentralized_ride::rating_proof)]
    fun test_rating_wrong_trip_aborts() {
        let mut sc = ts::begin(PASSENGER);
        {
            trip_receipt::create_receipt(
                1, DRIVER, b"pick", b"drop", 5, 1000, b"", b"", ts::ctx(&mut sc)
            );
        };
        ts::next_tx(&mut sc, ADMIN);
        {
            let cap = rating_proof::new_admin_cap_for_testing(ts::ctx(&mut sc));
            rating_proof::create_vehicle_stats(&cap, b"veh123", ts::ctx(&mut sc));
            rating_proof::destroy_admin_cap_for_testing(cap);
        };
        ts::next_tx(&mut sc, PASSENGER);
        {
            let receipt = ts::take_from_sender<TripReceipt>(&sc);
            let mut stats = ts::take_shared<VehicleRatingStats>(&sc);
            // 收據 trip_id=1，這裡傳 2
            rating_proof::create_rating_proof(
                &receipt, &mut stats, 100, 2, b"veh123", 5, zero_hash32(), b"blob1",
                ts::ctx(&mut sc)
            );
            ts::return_shared(stats);
            ts::return_to_sender(&sc, receipt);
        };
        ts::end(sc);
    }

    // ============================================================
    // 信譽提權防護
    // ============================================================
    #[test]
    #[expected_failure(abort_code = 1001, location = decentralized_ride::user_registry)]
    fun test_reputation_update_by_non_admin_aborts() {
        let mut sc = ts::begin(ADMIN);
        { user_registry::init_for_testing(ts::ctx(&mut sc)); };
        // 用戶註冊（UserProfile 現為共享）
        ts::next_tx(&mut sc, PASSENGER);
        {
            let mut reg = ts::take_shared<UserRegistry>(&sc);
            user_registry::register_user(&mut reg, b"didhash", ts::ctx(&mut sc));
            ts::return_shared(reg);
        };
        // 非 admin（bob）嘗試自抬信譽 → 應被拒
        ts::next_tx(&mut sc, BOB);
        {
            let reg = ts::take_shared<UserRegistry>(&sc);
            let mut prof = ts::take_shared<UserProfile>(&sc);
            user_registry::update_reputation(&reg, &mut prof, 999, ts::ctx(&mut sc));
            ts::return_shared(prof);
            ts::return_shared(reg);
        };
        ts::end(sc);
    }

    // ============================================================
    // Agent cap：動作白名單與時效
    // ============================================================

    // cap 只授權 REFUND，卻拿去 release → 應被拒（agent_registry E_ACTION_NOT_ALLOWED = 5）
    #[test]
    #[expected_failure(abort_code = 5, location = autodrive::agent_registry)]
    fun test_agent_action_not_allowed_aborts() {
        let mut sc = ts::begin(PASSENGER);
        { let clk = clock::create_for_testing(ts::ctx(&mut sc)); clock::share_for_testing(clk); };
        ts::next_tx(&mut sc, PASSENGER);
        {
            let clk = ts::take_shared<Clock>(&sc);
            // 只允許 REFUND，不允許 RELEASE_ESCROW
            agent_registry::issue_operator_cap(
                AGENT, 2_000_000, 5_000_000, 1_000_000,
                agent_registry::action_refund(), &clk, ts::ctx(&mut sc)
            );
            ts::return_shared(clk);
            let c = coin::mint_for_testing<SUI>(AMOUNT, ts::ctx(&mut sc));
            payment_escrow::lock_payment(c, 7, DRIVER, PLATFORM, ts::ctx(&mut sc));
        };
        ts::next_tx(&mut sc, AGENT);
        {
            let escrow = ts::take_shared<Escrow>(&sc);
            let mut cap = ts::take_shared<OperatorCap>(&sc);
            let clk = ts::take_shared<Clock>(&sc);
            payment_escrow::release_payment_by_agent(escrow, &mut cap, 7, &clk, ts::ctx(&mut sc));
            ts::return_shared(cap);
            ts::return_shared(clk);
        };
        ts::end(sc);
    }

    // cap 過期後動用 → 應被拒（agent_registry E_EXPIRED = 4）
    #[test]
    #[expected_failure(abort_code = 4, location = autodrive::agent_registry)]
    fun test_agent_expired_cap_aborts() {
        let mut sc = ts::begin(PASSENGER);
        { let clk = clock::create_for_testing(ts::ctx(&mut sc)); clock::share_for_testing(clk); };
        ts::next_tx(&mut sc, PASSENGER);
        {
            let clk = ts::take_shared<Clock>(&sc);
            // 有效期只有 1000ms（clock 從 0 起算 → valid_until = 1000）
            agent_registry::issue_operator_cap(
                AGENT, 2_000_000, 5_000_000, 1000,
                agent_registry::action_release_escrow(), &clk, ts::ctx(&mut sc)
            );
            ts::return_shared(clk);
            let c = coin::mint_for_testing<SUI>(AMOUNT, ts::ctx(&mut sc));
            payment_escrow::lock_payment(c, 7, DRIVER, PLATFORM, ts::ctx(&mut sc));
        };
        // 時鐘前進到 2000ms，超過有效期
        ts::next_tx(&mut sc, PASSENGER);
        {
            let mut clk = ts::take_shared<Clock>(&sc);
            clock::increment_for_testing(&mut clk, 2000);
            ts::return_shared(clk);
        };
        ts::next_tx(&mut sc, AGENT);
        {
            let escrow = ts::take_shared<Escrow>(&sc);
            let mut cap = ts::take_shared<OperatorCap>(&sc);
            let clk = ts::take_shared<Clock>(&sc);
            payment_escrow::release_payment_by_agent(escrow, &mut cap, 7, &clk, ts::ctx(&mut sc));
            ts::return_shared(cap);
            ts::return_shared(clk);
        };
        ts::end(sc);
    }

    // ============================================================
    // DID 位址綁定
    // ============================================================

    // DID 內嵌位址與 controller（發起者）不符 → 應被拒（did_registry E_INVALID_DID_FORMAT = 5）
    #[test]
    #[expected_failure(abort_code = 5, location = autodrive::did_registry)]
    fun test_did_wrong_embedded_address_aborts() {
        let mut sc = ts::begin(@0xCAFE);
        { let clk = clock::create_for_testing(ts::ctx(&mut sc)); clock::share_for_testing(clk); };
        ts::next_tx(&mut sc, @0xCAFE);
        {
            did_registry::init_for_testing(ts::ctx(&mut sc));
        };
        // 發起者是 @0xCAFE，但 DID 內嵌位址是全 0 → 不符
        ts::next_tx(&mut sc, @0xCAFE);
        {
            let mut reg = ts::take_shared<DIDRegistry>(&sc);
            let clk = ts::take_shared<Clock>(&sc);
            let did = string::utf8(
                b"did:sui:0x0000000000000000000000000000000000000000000000000000000000000000"
            );
            did_registry::register_did(
                &mut reg, did,
                string::utf8(b"[]"), string::utf8(b"[]"), string::utf8(b"[]"),
                &clk, ts::ctx(&mut sc)
            );
            ts::return_shared(clk);
            ts::return_shared(reg);
        };
        ts::end(sc);
    }

    // ============================================================
    // Phase 4：爭議凍結與仲裁
    // ============================================================

    // 爭議中 → release 被凍結（E_DISPUTED = 6）
    #[test]
    #[expected_failure(abort_code = 6, location = autodrive::payment_escrow)]
    fun test_dispute_freezes_release() {
        let mut sc = ts::begin(PASSENGER);
        {
            let c = coin::mint_for_testing<SUI>(AMOUNT, ts::ctx(&mut sc));
            payment_escrow::lock_payment(c, 1, DRIVER, PLATFORM, ts::ctx(&mut sc));
        };
        ts::next_tx(&mut sc, PASSENGER);
        {
            let mut escrow = ts::take_shared<Escrow>(&sc);
            payment_escrow::raise_dispute(&mut escrow, b"driver no-show", ts::ctx(&mut sc));
            ts::return_shared(escrow);
        };
        ts::next_tx(&mut sc, PASSENGER);
        {
            let escrow = ts::take_shared<Escrow>(&sc);
            payment_escrow::release_payment(escrow, 1, ts::ctx(&mut sc)); // 應 abort E_DISPUTED
        };
        ts::end(sc);
    }

    // 仲裁判給司機 → 司機+平台收款
    #[test]
    fun test_dispute_resolve_to_driver() {
        let mut sc = ts::begin(PASSENGER);
        {
            let c = coin::mint_for_testing<SUI>(AMOUNT, ts::ctx(&mut sc));
            payment_escrow::lock_payment(c, 1, DRIVER, PLATFORM, ts::ctx(&mut sc));
        };
        ts::next_tx(&mut sc, PASSENGER);
        {
            let mut escrow = ts::take_shared<Escrow>(&sc);
            payment_escrow::raise_dispute(&mut escrow, b"dispute", ts::ctx(&mut sc));
            ts::return_shared(escrow);
        };
        ts::next_tx(&mut sc, PLATFORM);
        {
            let cap = payment_escrow::new_arbiter_cap_for_testing(ts::ctx(&mut sc));
            let escrow = ts::take_shared<Escrow>(&sc);
            let dispute = ts::take_shared<Dispute>(&sc);
            payment_escrow::resolve_dispute(&cap, escrow, dispute, payment_escrow::ruling_driver(), ts::ctx(&mut sc));
            payment_escrow::destroy_arbiter_cap_for_testing(cap);
        };
        ts::next_tx(&mut sc, DRIVER);
        {
            let c = ts::take_from_address<Coin<SUI>>(&sc, DRIVER);
            assert!(coin::value(&c) == DRIVER_AMT, 0);
            coin::burn_for_testing(c);
        };
        ts::end(sc);
    }

    // 仲裁退乘客 → 乘客全額收回
    #[test]
    fun test_dispute_resolve_to_passenger() {
        let mut sc = ts::begin(PASSENGER);
        {
            let c = coin::mint_for_testing<SUI>(AMOUNT, ts::ctx(&mut sc));
            payment_escrow::lock_payment(c, 1, DRIVER, PLATFORM, ts::ctx(&mut sc));
        };
        ts::next_tx(&mut sc, PASSENGER);
        {
            let mut escrow = ts::take_shared<Escrow>(&sc);
            payment_escrow::raise_dispute(&mut escrow, b"dispute", ts::ctx(&mut sc));
            ts::return_shared(escrow);
        };
        ts::next_tx(&mut sc, PLATFORM);
        {
            let cap = payment_escrow::new_arbiter_cap_for_testing(ts::ctx(&mut sc));
            let escrow = ts::take_shared<Escrow>(&sc);
            let dispute = ts::take_shared<Dispute>(&sc);
            payment_escrow::resolve_dispute(&cap, escrow, dispute, payment_escrow::ruling_passenger(), ts::ctx(&mut sc));
            payment_escrow::destroy_arbiter_cap_for_testing(cap);
        };
        ts::next_tx(&mut sc, PASSENGER);
        {
            let c = ts::take_from_address<Coin<SUI>>(&sc, PASSENGER);
            assert!(coin::value(&c) == AMOUNT, 0);
            coin::burn_for_testing(c);
        };
        ts::end(sc);
    }

    // ============================================================
    // Phase 2b：平台從退款池直接退款（admin 驅動）
    // ============================================================
    #[test]
    fun test_admin_pool_refund_success() {
        let rider = @0x51;
        let mut sc = ts::begin(PLATFORM);
        { refund_module_v2::init_for_testing(ts::ctx(&mut sc)); };
        ts::next_tx(&mut sc, PLATFORM);
        {
            let mut pool = ts::take_shared<RefundPoolV2>(&sc);
            let cap = ts::take_from_sender<RefundCapability>(&sc);
            // 平台注資 2_000_000
            let c = coin::mint_for_testing<SUI>(2_000_000, ts::ctx(&mut sc));
            refund_module_v2::fund_pool(&mut pool, c, ts::ctx(&mut sc));
            // 退 500_000 給乘客
            refund_module_v2::admin_refund_from_pool(&cap, &mut pool, rider, 500_000, 1, ts::ctx(&mut sc));
            assert!(refund_module_v2::get_pool_balance(&pool) == 1_500_000, 0);
            assert!(refund_module_v2::get_total_refunded(&pool) == 500_000, 1);
            ts::return_to_sender(&sc, cap);
            ts::return_shared(pool);
        };
        ts::next_tx(&mut sc, rider);
        {
            let coin = ts::take_from_address<Coin<SUI>>(&sc, rider);
            assert!(coin::value(&coin) == 500_000, 2);
            coin::burn_for_testing(coin);
        };
        ts::end(sc);
    }

    // 池餘額不足 → 應被拒（refund_module_v2 E_INSUFFICIENT_BALANCE = 3）
    #[test]
    #[expected_failure(abort_code = 3, location = autodrive::refund_module_v2)]
    fun test_admin_pool_refund_insufficient_aborts() {
        let rider = @0x51;
        let mut sc = ts::begin(PLATFORM);
        { refund_module_v2::init_for_testing(ts::ctx(&mut sc)); };
        ts::next_tx(&mut sc, PLATFORM);
        {
            let mut pool = ts::take_shared<RefundPoolV2>(&sc);
            let cap = ts::take_from_sender<RefundCapability>(&sc);
            // 未注資，餘額 0，卻要退 500_000
            refund_module_v2::admin_refund_from_pool(&cap, &mut pool, rider, 500_000, 1, ts::ctx(&mut sc));
            ts::return_to_sender(&sc, cap);
            ts::return_shared(pool);
        };
        ts::end(sc);
    }

    // ============================================================
    // P1-3：Profile 身分狀態（soulbound，狀態只由 verifier 設定）
    // ============================================================
    #[test]
    fun test_passenger_profile_defaults_and_gated_setter() {
        let mut sc = ts::begin(PASSENGER);
        { profile::create_passenger_profile(ts::ctx(&mut sc)); };
        ts::next_tx(&mut sc, PASSENGER);
        {
            let mut p = ts::take_from_sender<PassengerProfile>(&sc);
            // 擁有者正確，預設非成年
            assert!(profile::passenger_owner(&p) == PASSENGER, 0);
            assert!(!profile::passenger_is_adult(&p), 1);
            // 模擬 credential_verifier（同套件）於驗證後設定 → is_adult=true
            // （外部套件/原生交易無法呼叫此 public(package) setter，屬編譯期保證）
            profile::set_passenger_adult(&mut p, b"kyc-commit", 123);
            assert!(profile::passenger_is_adult(&p), 2);
            ts::return_to_sender(&sc, p);
        };
        ts::end(sc);
    }

    // ============================================================
    // F1：複合原子結算（release + receipt 一次交易）
    // ============================================================
    #[test]
    fun test_agent_settle_and_receipt_atomic() {
        let mut sc = ts::begin(PASSENGER);
        { let clk = clock::create_for_testing(ts::ctx(&mut sc)); clock::share_for_testing(clk); };
        ts::next_tx(&mut sc, PASSENGER);
        {
            let clk = ts::take_shared<Clock>(&sc);
            agent_registry::issue_operator_cap(
                AGENT, 2_000_000, 5_000_000, 1_000_000,
                agent_registry::action_release_escrow(), &clk, ts::ctx(&mut sc)
            );
            ts::return_shared(clk);
            let c = coin::mint_for_testing<SUI>(AMOUNT, ts::ctx(&mut sc));
            payment_escrow::lock_payment(c, 9, DRIVER, PLATFORM, ts::ctx(&mut sc));
        };
        // Agent 一次呼叫：釋放 + 開收據
        ts::next_tx(&mut sc, AGENT);
        {
            let escrow = ts::take_shared<Escrow>(&sc);
            let mut cap = ts::take_shared<OperatorCap>(&sc);
            let clk = ts::take_shared<Clock>(&sc);
            payment_escrow::release_and_receipt_by_agent(
                escrow, &mut cap, 9, b"pick", b"drop", 5, b"trajblob", b"",
                &clk, ts::ctx(&mut sc)
            );
            ts::return_shared(cap);
            ts::return_shared(clk);
        };
        // 司機收到 975
        ts::next_tx(&mut sc, DRIVER);
        {
            let c = ts::take_from_address<Coin<SUI>>(&sc, DRIVER);
            assert!(coin::value(&c) == DRIVER_AMT, 0);
            coin::burn_for_testing(c);
        };
        // 乘客拿到 TripReceipt，且錨定了軌跡 blob
        ts::next_tx(&mut sc, PASSENGER);
        {
            let receipt = ts::take_from_address<TripReceipt>(&sc, PASSENGER);
            assert!(trip_receipt::trip_id(&receipt) == 9, 1);
            assert!(trip_receipt::trajectory_blob_id(&receipt) == b"trajblob", 2);
            ts::return_to_address(PASSENGER, receipt);
        };
        ts::end(sc);
    }
}
