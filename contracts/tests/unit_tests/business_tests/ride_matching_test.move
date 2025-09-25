// tests/unit_tests/business/ride_matching_test.move
#[test_only]
module decentralized_ride::ride_matching_test {
    use std::string;
    use iota::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use decentralized_ride::ride_matching::{Self, MatchingService, RideRequest, RideMatch};
    use decentralized_ride::user_registry::{Self, UserProfile};
    use decentralized_ride::vehicle_registry::{Self, Vehicle};
    use decentralized_ride::constants;

    #[test]
    public fun test_only_init() {
    let admin = @admin;
    let mut scenario = test::begin(admin);
    
    
    // 🔍 只測試初始化，不做其他任何操作
    {
        ride_matching::init_for_testing(ctx(&mut scenario));
        next_tx(&mut scenario, admin);
    };
    
    // 🔍 立即嘗試獲取共享對象
    {
        let service = test::take_shared<MatchingService>(&scenario);
        // 如果這裡失敗，說明 init 函數內部有問題
        test::return_shared(service);
    };
    
    test::end(scenario);
}
#[test]
public fun comprehensive_debug_test() {
    use std::debug;
    
    let admin = @admin;
    let mut scenario = test::begin(admin);
  
    
    // 步驟 1: 確認測試框架基本功能
    {
        let current_sender = test::sender(&scenario);
        debug::print(&b"Current sender:");
        debug::print(&current_sender);
        assert!(current_sender == admin, 1000);
    };
    
    // 步驟 2: 嘗試初始化並捕獲任何錯誤
    {
        debug::print(&b"About to call init_for_testing");
        ride_matching::init_for_testing(ctx(&mut scenario));
        next_tx(&mut scenario, admin);
        debug::print(&b"init_for_testing completed");
    };
    
    // 步驟 3: 檢查是否有任何共享對象
    {
        debug::print(&b"Checking for shared objects");
        
        // 嘗試列出所有共享對象 (如果測試框架支持)
        // 這會告訴我們是否有任何對象被共享
        
        debug::print(&b"About to take_shared");
        let service = test::take_shared<MatchingService>(&scenario);
        debug::print(&b"take_shared succeeded");
        
        // 如果到達這裡，說明對象存在
        debug::print(&b"MatchingService found successfully");
        test::return_shared(service);
    };
    
    test::end(scenario);
}




    #[test]
    public fun test_create_ride_request() {
        let admin = @admin;
        let passenger = @alice;
        let mut scenario = test::begin(admin);

        
        // 初始化服務
        {
            ride_matching::init_for_testing(ctx(&mut scenario));
            user_registry::init_for_testing(ctx(&mut scenario));
            next_tx(&mut scenario, admin);
        };
         {
            let service = test::take_shared<MatchingService>(&scenario);
            
            // ✅ 使用 getter 函數
            let (requests, matches,completed, activate ) = ride_matching::get_service_stats(&service);
            assert!(requests == 0, 1);
            assert!(matches == 0, 2);  
            assert!(completed == 0, 3);
            assert!(activate , 4);
            
            test::return_shared(service);
        };
        // 註冊用戶
        next_tx(&mut scenario, admin);
        next_tx(&mut scenario, passenger);
        {
            let mut registry = test::take_shared<user_registry::UserRegistry>(&scenario);
            user_registry::register_user(&mut registry, b"passenger_did_alice", ctx(&mut scenario));
            test::return_shared(registry);
        };
        // 創建叫車請求
        next_tx(&mut scenario, passenger);
        {
            
            let mut service = test::take_shared<MatchingService>(&scenario);
            let user_profile = test::take_from_sender<UserProfile>(&scenario);
            
            ride_matching::create_ride_request(
                &mut service,
                &user_profile,
                b"request_hash_123",
                50000000000000000, // 0.05 IOTA
                ctx(&mut scenario)
            );
             let (total_requests, total_matches, total_completed, is_active) = 
            ride_matching::get_service_stats(&service);
            assert!(total_requests == 1, 1);
            assert!(total_matches == 0, 2);     // 原第 143 行的檢查
            assert!(total_completed == 0, 3);   // 還未完成
            assert!(is_active, 4);              // 服務應該是活躍的
            
            test::return_to_sender(&scenario, user_profile);
            test::return_shared(service);
        };
        
        //管理員驗證請求資料
        next_tx(&mut scenario, passenger);
        {
            let request = test::take_from_sender<RideRequest>(&scenario);
            assert!(ride_matching::get_request_status(&request) == constants::ride_status_pending(), 3);
            test::return_to_sender(&scenario, request);
        };
        
        test::end(scenario);
    }

    #[test]
    public fun test_complete_ride_flow() {
        let admin = @admin;
        let passenger = @alice;
        let driver = @bob;
        let mut scenario = test::begin(admin);
        
        // 初始化所有服務
        {
            ride_matching::init_for_testing(ctx(&mut scenario));
            user_registry::init_for_testing(ctx(&mut scenario));
            vehicle_registry::init_for_testing(ctx(&mut scenario));
            next_tx(&mut scenario, admin);
        };
        
        // 註冊乘客
        next_tx(&mut scenario, passenger);
        {
            let mut registry = test::take_shared<user_registry::UserRegistry>(&scenario);
            user_registry::register_user(&mut registry, b"passenger_did", ctx(&mut scenario));
            test::return_shared(registry);
        };
        
        // 註冊司機
        next_tx(&mut scenario, driver);
        {
            let mut user_reg = test::take_shared<user_registry::UserRegistry>(&scenario);
            let mut vehicle_reg = test::take_shared<vehicle_registry::VehicleRegistry>(&scenario);
            
            user_registry::register_user(&mut user_reg, b"driver_did", ctx(&mut scenario));
            vehicle_registry::register_vehicle(&mut vehicle_reg, b"vehicle_hash", ctx(&mut scenario));
            
            test::return_shared(user_reg);
            test::return_shared(vehicle_reg);
        };
        
        // 管理員驗證車輛
        next_tx(&mut scenario, admin);
        {
            let vehicle_registry_obj = test::take_shared<vehicle_registry::VehicleRegistry>(&scenario);
            let mut vehicle = test::take_from_address<Vehicle>(&scenario, driver);
            
            vehicle_registry::verify_vehicle(&vehicle_registry_obj, &mut vehicle, ctx(&mut scenario));
            
            test::return_to_address(driver, vehicle);
            test::return_shared(vehicle_registry_obj);
        };
        
        // 乘客創建請求
        next_tx(&mut scenario, passenger);
        {
            let mut service = test::take_shared<MatchingService>(&scenario);
            let user_profile = test::take_from_sender<UserProfile>(&scenario);
            
            ride_matching::create_ride_request(
                &mut service,
                &user_profile,
                b"request_hash",
                40000000000000000,
                ctx(&mut scenario)
            );
            
            test::return_to_sender(&scenario, user_profile);
            test::return_shared(service);
        };
        next_tx(&mut scenario, admin);
        // 司機確認配對
        next_tx(&mut scenario, driver);
        {
            let mut service = test::take_shared<MatchingService>(&scenario);
            let mut request = test::take_from_address<RideRequest>(&scenario, passenger);
            let mut vehicle = test::take_from_sender<Vehicle>(&scenario);
            let driver_profile = test::take_from_sender<UserProfile>(&scenario);
            
            ride_matching::confirm_match(
                &mut service,
                &mut request,
                &mut vehicle,
                &driver_profile,
                35000000000000000, // 0.035 IOTA
                b"match_signature",
                ctx(&mut scenario)
            );
              let (total_requests, total_matches, total_completed, is_active) = 
            ride_matching::get_service_stats(&service);
            
            assert!(total_requests >= 1, 1);
            assert!(total_matches >= 1, 2);
            assert!(total_completed == 0, 3);   // 原第 181 行的檢查  
            assert!(is_active, 4);              // 服務仍然活躍
      
            
            test::return_to_sender(&scenario, driver_profile);
            test::return_to_sender(&scenario, vehicle);
            test::return_to_address(passenger, request);
            test::return_shared(service);
        };
        
        // 開始行程
        next_tx(&mut scenario, driver);
        {
            let mut ride_match = test::take_from_sender<RideMatch>(&scenario);
            
            ride_matching::start_ride(&mut ride_match, ctx(&mut scenario));
            
            let (_, _, _, status) = ride_matching::get_match_info(&ride_match);
            assert!(status == constants::ride_status_active(), 5);
            
            test::return_to_sender(&scenario, ride_match);
        };
        // 完成行程
        next_tx(&mut scenario, driver);
        {
            let mut service = test::take_shared<MatchingService>(&scenario);
            let mut ride_match = test::take_from_sender<RideMatch>(&scenario);
            let mut vehicle = test::take_from_sender<Vehicle>(&scenario);
            let mut passenger_profile = test::take_from_address<UserProfile>(&scenario, passenger);
            let mut driver_profile = test::take_from_sender<UserProfile>(&scenario);
            
            ride_matching::complete_ride(
                &mut service,
                &mut ride_match,
                &mut vehicle,
                &mut passenger_profile,
                &mut driver_profile,
                ctx(&mut scenario)
            );
            
            let (total_requests, total_matches, total_completed, is_active) = 
            ride_matching::get_service_stats(&service);
            
            assert!(total_requests >= 1, 1);
            assert!(total_matches == 1, 2);
            assert!(total_completed == 1, 3);   // 原第 181 行的檢查  
            assert!(is_active, 4);              // 服務仍然活躍
      
            let (_, _, _, status) = ride_matching::get_match_info(&ride_match);
            assert!(status == constants::ride_status_completed(), 7);
            assert!(vehicle_registry::is_available(&vehicle), 8);
            
            test::return_to_sender(&scenario, driver_profile);
            test::return_to_address(passenger, passenger_profile);
            test::return_to_sender(&scenario, vehicle);
            test::return_to_sender(&scenario, ride_match);
            test::return_shared(service);
        };
        // 完成行程後提起爭議
        next_tx(&mut scenario, driver);
        {
            let mut ride_match = test::take_from_sender<RideMatch>(&scenario);
            ride_matching::raise_dispute(
                &mut ride_match,
                b"Driver took wrong route",
                ctx(&mut scenario)
            );
            
            let (_, _, _, status) = ride_matching::get_match_info(&ride_match);
            assert!(status == constants::ride_status_disputed(), 9);
            
            test::return_to_sender(&scenario, ride_match);
        };
        
        test::end(scenario);
    }


    #[test]
    #[expected_failure(abort_code = 2203, location = decentralized_ride::ride_matching)] // E_PRICE_MISMATCH
    public fun test_price_validation() {
        let admin = @admin;
        let passenger = @alice;
        let driver = @bob;
        let mut scenario = test::begin(admin);

        // 初始化所有服務
        next_tx(&mut scenario, admin);
        {
            ride_matching::init_for_testing(ctx(&mut scenario));
            user_registry::init_for_testing(ctx(&mut scenario));
            vehicle_registry::init_for_testing(ctx(&mut scenario));
        };

        // 提交初始化交易
        next_tx(&mut scenario, admin);

        // 註冊乘客
        next_tx(&mut scenario, passenger);
        {
            let mut registry = test::take_shared<user_registry::UserRegistry>(&scenario);
            user_registry::register_user(&mut registry, b"passenger_did_price", ctx(&mut scenario));
            test::return_shared(registry);
        };

        // 註冊司機與車輛
        next_tx(&mut scenario, driver);
        {
            let mut user_reg = test::take_shared<user_registry::UserRegistry>(&scenario);
            let mut vehicle_reg = test::take_shared<vehicle_registry::VehicleRegistry>(&scenario);
            user_registry::register_user(&mut user_reg, b"driver_did_price", ctx(&mut scenario));
            vehicle_registry::register_vehicle(&mut vehicle_reg, b"vehicle_hash_price", ctx(&mut scenario));
            test::return_shared(user_reg);
            test::return_shared(vehicle_reg);
        };

        // 管理員驗證車輛
        next_tx(&mut scenario, admin);
        {
            let vehicle_registry_obj = test::take_shared<vehicle_registry::VehicleRegistry>(&scenario);
            let mut vehicle = test::take_from_address<Vehicle>(&scenario, driver);
            vehicle_registry::verify_vehicle(&vehicle_registry_obj, &mut vehicle, ctx(&mut scenario));
            test::return_to_address(driver, vehicle);
            test::return_shared(vehicle_registry_obj);
        };

        // 乘客建立叫車請求
        next_tx(&mut scenario, passenger);
        {
            let mut service = test::take_shared<MatchingService>(&scenario);
            let user_profile = test::take_from_sender<UserProfile>(&scenario);
            ride_matching::create_ride_request(
                &mut service,
                &user_profile,
                b"request_hash_price",
                40000000000000000,
                ctx(&mut scenario)
            );
            test::return_to_sender(&scenario, user_profile);
            test::return_shared(service);
        };

        // 司機報價超過乘客預算（應該失敗）
        next_tx(&mut scenario, driver);
        {

            let mut service = test::take_shared<MatchingService>(&scenario);
            let mut request = test::take_from_address<RideRequest>(&scenario, passenger);
            let mut vehicle = test::take_from_sender<Vehicle>(&scenario);
            let driver_profile = test::take_from_sender<UserProfile>(&scenario);
            
            ride_matching::confirm_match(
                &mut service,
                &mut request,
                &mut vehicle,
                &driver_profile,
                100000000000000000, // 超過預算的價格
                b"match_signature",
                ctx(&mut scenario)
            );
            
            // 這裡不會執行到，因為應該在上面失敗
            test::return_to_sender(&scenario, driver_profile);
            test::return_to_sender(&scenario, vehicle);
            test::return_to_address(passenger, request);
            test::return_shared(service);
        };
        
        test::end(scenario);
    }
}
