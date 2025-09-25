// tests/unit_tests/utils/constants_test.move
#[test_only]
module decentralized_ride::constants_test {
    use decentralized_ride::constants;

    #[test]
    public fun test_system_constants() {
        // 測試基礎費率
        assert!(constants::base_fare() > 0, 1);
        assert!(constants::per_km_rate() > 0, 2);
        assert!(constants::per_minute_rate() > 0, 3);
        
        // 測試平台費率
        assert!(constants::platform_fee_rate() == 250, 4); // 2.5%
        assert!(constants::basis_points_denominator() == 10000, 5);
    }

    #[test]
    public fun test_timeout_constants() {
        // 測試時間設定
        assert!(constants::ride_request_timeout() == 300, 6); // 5 分鐘
        assert!(constants::driver_offer_timeout() == 180, 7); // 3 分鐘
        assert!(constants::pickup_timeout() == 900, 8); // 15 分鐘
    }

    #[test]
    public fun test_reputation_system() {
        // 測試信譽系統
        assert!(constants::default_reputation() == 500, 9);
        assert!(constants::min_driver_reputation() == 300, 10);
        assert!(constants::max_reputation() == 1000, 11);
    }

    #[test]
    public fun test_status_constants() {
        // 測試用戶狀態
        assert!(constants::user_status_active() == 0, 12);
        assert!(constants::user_status_suspended() == 1, 13);
        assert!(constants::user_status_banned() == 2, 14);
        
        // 測試車輛狀態
        assert!(constants::vehicle_status_offline() == 0, 15);
        assert!(constants::vehicle_status_available() == 1, 16);
        assert!(constants::vehicle_status_busy() == 2, 17);
        
        // 測試行程狀態
        assert!(constants::ride_status_pending() == 0, 18);
        assert!(constants::ride_status_matched() == 1, 19);
        assert!(constants::ride_status_active() == 2, 20);
        assert!(constants::ride_status_completed() == 3, 21);
        assert!(constants::ride_status_cancelled() == 4, 22);
        assert!(constants::ride_status_disputed() == 5, 23);
    }

    #[test]
    public fun test_validation_functions() {
        // 測試用戶狀態驗證
        assert!(constants::is_valid_user_status(0), 24);
        assert!(constants::is_valid_user_status(1), 25);
        assert!(constants::is_valid_user_status(2), 26);
        assert!(!constants::is_valid_user_status(3), 27);
        
        // 測試車輛狀態驗證
        assert!(constants::is_valid_vehicle_status(0), 28);
        assert!(constants::is_valid_vehicle_status(1), 29);
        assert!(constants::is_valid_vehicle_status(2), 30);
        assert!(!constants::is_valid_vehicle_status(3), 31);
        
        // 測試評分驗證
        assert!(!constants::is_valid_rating(0), 32);
        assert!(constants::is_valid_rating(1), 33);
        assert!(constants::is_valid_rating(5), 34);
        assert!(!constants::is_valid_rating(6), 35);
        
        // 測試信譽驗證
        assert!(constants::is_valid_reputation(0), 36);
        assert!(constants::is_valid_reputation(500), 37);
        assert!(constants::is_valid_reputation(1000), 38);
        assert!(!constants::is_valid_reputation(1001), 39);
    }

    #[test]
    public fun test_error_codes() {
        // 測試系統級錯誤碼
        assert!(constants::e_unauthorized() == 1001, 40);
        assert!(constants::e_invalid_data_format() == 1002, 41);
        assert!(constants::e_service_suspended() == 1003, 42);
        
        // 測試用戶相關錯誤碼
        assert!(constants::e_user_not_found() == 2001, 43);
        assert!(constants::e_user_suspended() == 2002, 44);
        
        // 測試車輛相關錯誤碼
        assert!(constants::e_vehicle_not_found() == 2101, 45);
        assert!(constants::e_vehicle_not_verified() == 2102, 46);
        assert!(constants::e_vehicle_not_available() == 2103, 47);
        
        // 測試配對相關錯誤碼
        assert!(constants::e_ride_not_found() == 2201, 48);
        assert!(constants::e_price_mismatch() == 2203, 49);
        assert!(constants::e_request_expired() == 2204, 50);
    }
}
