// tests/unit_tests/identity/user_registry_test.move
#[test_only]
module decentralized_ride::user_registry_test {
    use std::string;
    use iota::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use decentralized_ride::user_registry::{Self, UserRegistry, UserProfile};
    use decentralized_ride::constants;
    use decentralized_ride::constants::e_unauthorized;

    #[test]
    public fun test_user_registration() {
        let admin = @admin;
        let user = @alice;
        let mut scenario = test::begin(admin);
        
        // 初始化註冊表
        {
            user_registry::init_for_testing(ctx(&mut scenario));
            next_tx(&mut scenario, admin);
        };
        
        // 用戶註冊
        next_tx(&mut scenario, user);
        {
            let mut registry = test::take_shared<UserRegistry>(&scenario);
            user_registry::register_user(
                &mut registry,
                b"did_hash_12345", 
                ctx(&mut scenario)
            );
            
            assert!(user_registry::get_total_users(&registry) == 1, 1);
            test::return_shared(registry);
        };
        next_tx(&mut scenario, user);
        // 驗證用戶資料
        {
            let user_profile = test::take_from_sender<UserProfile>(&scenario);
            assert!(user_registry::get_reputation(&user_profile) == constants::default_reputation(), 2);
            assert!(user_registry::is_active(&user_profile), 3);
            assert!(user_registry::can_request_ride(&user_profile), 4);
            assert!(user_registry::can_drive(&user_profile), 5);
            test::return_to_sender(&scenario, user_profile);
        };
        
        test::end(scenario);
    }

    #[test]
    public fun test_user_status_management() {
        let admin = @admin;
        let user = @alice;
        let mut scenario = test::begin(admin);
        
        // 註冊用戶
        {
            user_registry::init_for_testing(ctx(&mut scenario));
            next_tx(&mut scenario, admin);
        };
        
        next_tx(&mut scenario, user);
        {
            let mut registry = test::take_shared<UserRegistry>(&scenario);
            user_registry::register_user(&mut registry, b"did_hash", ctx(&mut scenario));
            test::return_shared(registry);
        };
        
        // 管理員更新用戶狀態
        next_tx(&mut scenario, admin);
        {
            let registry = test::take_shared<UserRegistry>(&scenario);
            let mut user_profile = test::take_from_address<UserProfile>(&scenario, user);
            
            user_registry::update_user_status(
                &registry,
                &mut user_profile,
                constants::user_status_suspended(),
                ctx(&mut scenario)
            );
            
            assert!(user_registry::get_status(&user_profile) == constants::user_status_suspended(), 6);
            assert!(!user_registry::is_active(&user_profile), 7);
            assert!(!user_registry::can_request_ride(&user_profile), 8);
            assert!(!user_registry::can_drive(&user_profile), 9);
            
            test::return_to_address(user, user_profile);
            test::return_shared(registry);
        };
        
        test::end(scenario);
    }

    #[test]
    public fun test_reputation_and_activity_updates() {
        let admin = @admin;
        let user = @alice;
        let mut scenario = test::begin(admin);
        
        // 註冊用戶
        {
            user_registry::init_for_testing(ctx(&mut scenario));
            next_tx(&mut scenario, admin);
        };
        
        next_tx(&mut scenario, user);
        {
            let mut registry = test::take_shared<UserRegistry>(&scenario);
            user_registry::register_user(&mut registry, b"did_hash", ctx(&mut scenario));
            test::return_shared(registry);
        };
        
        // 更新信譽和活動統計
        {
            next_tx(&mut scenario, user);
            let mut user_profile = test::take_from_sender<UserProfile>(&scenario);
            
            // 更新信譽
            user_registry::update_reputation(&mut user_profile, 800);
            assert!(user_registry::get_reputation(&user_profile) == 800, 4);
            
            // 增加行程統計
            user_registry::add_ride(&mut user_profile);
            user_registry::add_drive(&mut user_profile);
            
            let (rides, drives) = user_registry::get_ride_stats(&user_profile);
            assert!(rides == 1, 5);
            assert!(drives == 1, 6);
            assert!(user_registry::get_total_activity(&user_profile) == 2, 13);
            
            test::return_to_sender(&scenario, user_profile);
        };
        
        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1001, location = decentralized_ride::user_registry)] // E_UNAUTHORIZED
    public fun test_unauthorized_status_update() {
        let admin = @admin;
        let user = @alice;
        let unauthorized = @bob;
        let mut scenario = test::begin(admin);
        // 註冊用戶
        {
            user_registry::init_for_testing(ctx(&mut scenario));
            next_tx(&mut scenario, admin);
        };
        
        next_tx(&mut scenario, user);
        {
            let mut registry = test::take_shared<UserRegistry>(&scenario);
            user_registry::register_user(&mut registry, b"did_hash", ctx(&mut scenario));
            test::return_shared(registry);
        };
        
        // 非管理員嘗試更新狀態（應該失敗）
        next_tx(&mut scenario, unauthorized);
        {
            let registry = test::take_shared<UserRegistry>(&scenario);
            let mut user_profile = test::take_from_address<UserProfile>(&scenario, user);
            
            user_registry::update_user_status(
                &registry,
                &mut user_profile, 
                constants::user_status_suspended(),
                ctx(&mut scenario)
            );
            
            test::return_to_address(user, user_profile);
            test::return_shared(registry);
        };
        
        test::end(scenario);
    }
}
