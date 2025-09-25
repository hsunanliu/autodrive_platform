// tests/unit_tests/identity/vehicle_registry_test.move
#[test_only]
module decentralized_ride::vehicle_registry_test {
    use iota::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use decentralized_ride::vehicle_registry::{Self, VehicleRegistry, Vehicle};
    use decentralized_ride::constants;

    #[test]
    public fun test_vehicle_registration() {
        let admin = @admin;
        let owner = @alice;
        let mut scenario = test::begin(admin);
        
        
        // 初始化註冊表
        {
            vehicle_registry::init_for_testing(ctx(&mut scenario));
            next_tx(&mut scenario, admin);
        };
        
        // 車輛註冊
        next_tx(&mut scenario, owner);
        {
            let mut registry = test::take_shared<VehicleRegistry>(&scenario);
            vehicle_registry::register_vehicle(
                &mut registry,
                b"vehicle_data_hash_123",
                ctx(&mut scenario)
            );
            
            assert!(vehicle_registry::get_total_vehicles(&registry) == 1, 1);
            test::return_shared(registry);
        };
        
        // 驗證車輛資料
        {
            next_tx(&mut scenario, owner);
            let vehicle = test::take_from_sender<Vehicle>(&scenario);
            assert!(vehicle_registry::get_owner(&vehicle) == owner, 2);
            assert!(!vehicle_registry::is_available(&vehicle), 3); // 未驗證不可用
            assert!(vehicle_registry::get_total_trips(&vehicle) == 0, 4);
            test::return_to_sender(&scenario, vehicle);
        };
        
        test::end(scenario);
    }

    #[test]
    public fun test_vehicle_verification() {
        let admin = @admin;
        let owner = @alice;
        let mut scenario = test::begin(admin);
        next_tx(&mut scenario, admin);
        
        // 初始化並註冊車輛
        {
            vehicle_registry::init_for_testing(ctx(&mut scenario));
            next_tx(&mut scenario, admin);
        };
        
        next_tx(&mut scenario, owner);
        {
            let mut registry = test::take_shared<VehicleRegistry>(&scenario);
            vehicle_registry::register_vehicle(&mut registry, b"vehicle_hash", ctx(&mut scenario));
            test::return_shared(registry);
        };
        
        // 管理員驗證車輛
        next_tx(&mut scenario, admin);
        {
            let registry = test::take_shared<VehicleRegistry>(&scenario);
            let mut vehicle = test::take_from_address<Vehicle>(&scenario, owner);
            
            vehicle_registry::verify_vehicle(&registry, &mut vehicle, ctx(&mut scenario));
            assert!(vehicle_registry::is_available(&vehicle), 5); // 驗證後可用
            
            test::return_to_address(owner, vehicle);
            test::return_shared(registry);
        };
        
        test::end(scenario);
    }

    #[test]
    public fun test_vehicle_status_management() {
        let admin = @admin;
        let owner = @alice;
        let mut scenario = test::begin(admin);
        next_tx(&mut scenario, admin);
        
        // 註冊並驗證車輛
        {
            vehicle_registry::init_for_testing(ctx(&mut scenario));
            next_tx(&mut scenario, admin);
        };
        
        next_tx(&mut scenario, owner);
        {
            let mut registry = test::take_shared<VehicleRegistry>(&scenario);
            vehicle_registry::register_vehicle(&mut registry, b"vehicle_hash", ctx(&mut scenario));
            test::return_shared(registry);
        };
        
        next_tx(&mut scenario, admin);
        {
            let registry = test::take_shared<VehicleRegistry>(&scenario);
            let mut vehicle = test::take_from_address<Vehicle>(&scenario, owner);
            vehicle_registry::verify_vehicle(&registry, &mut vehicle, ctx(&mut scenario));
            test::return_to_address(owner, vehicle);
            test::return_shared(registry);
        };
        
        // 車主更新狀態
        next_tx(&mut scenario, owner);
        {
            let mut vehicle = test::take_from_sender<Vehicle>(&scenario);
            
            vehicle_registry::update_status(
                &mut vehicle,
                constants::vehicle_status_busy(),
                ctx(&mut scenario)
            );
            
            assert!(!vehicle_registry::is_available(&vehicle), 6); // 忙碌中不可用
            test::return_to_sender(&scenario, vehicle);
        };
        
        test::end(scenario);
    }

    #[test]
    public fun test_ownership_transfer() {
        let admin = @admin;
        let old_owner = @alice;
        let new_owner = @bob;
        let mut scenario = test::begin(admin);
        next_tx(&mut scenario, admin);
        
        // 註冊車輛
        {
            vehicle_registry::init_for_testing(ctx(&mut scenario));
            next_tx(&mut scenario, admin);
        };
        
        next_tx(&mut scenario, old_owner);
        {
            let mut registry = test::take_shared<VehicleRegistry>(&scenario);
            vehicle_registry::register_vehicle(&mut registry, b"vehicle_hash", ctx(&mut scenario));
            test::return_shared(registry);
        };
        next_tx(&mut scenario, old_owner);
        // 轉移所有權
        {
            let mut vehicle = test::take_from_sender<Vehicle>(&scenario);
            
            vehicle_registry::transfer_ownership(
                &mut vehicle,
                new_owner,
                ctx(&mut scenario)
            );
            
            assert!(vehicle_registry::get_owner(&vehicle) == new_owner, 7);
            assert!(!vehicle_registry::is_available(&vehicle), 8); // 轉移後需重新驗證
            
            test::return_to_sender(&scenario, vehicle);
        };
        
        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 2104, location = decentralized_ride::vehicle_registry)] // E_NOT_VEHICLE_OWNER
    public fun test_unauthorized_status_update() {
        let admin = @admin;
        let owner = @alice;
        let unauthorized = @bob;
        let mut scenario = test::begin(admin);
        
        // 註冊車輛
        {
            vehicle_registry::init_for_testing(ctx(&mut scenario));
            next_tx(&mut scenario, admin);
        };
        
        next_tx(&mut scenario, owner);
        {
            let mut registry = test::take_shared<VehicleRegistry>(&scenario);
            vehicle_registry::register_vehicle(&mut registry, b"vehicle_hash", ctx(&mut scenario));
            test::return_shared(registry);
        };
        
        // 非車主嘗試更新狀態（應該失敗）
        next_tx(&mut scenario, unauthorized);
        {
            let mut vehicle = test::take_from_address<Vehicle>(&scenario, owner);

            vehicle_registry::update_status(
                &mut vehicle,
                constants::vehicle_status_busy(),
                ctx(&mut scenario)
            );
            
            test::return_to_address(owner, vehicle);
        };
        
        test::end(scenario);
    }
}
