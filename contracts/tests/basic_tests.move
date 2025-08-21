// tests/basic_tests.move
#[test_only]
module decentralized_ride::basic_tests {
    use decentralized_ride::user_registry::{Self, UserRegistry, UserProfile};
    use decentralized_ride::vehicle_registry::{Self, VehicleRegistry, Vehicle};
    use decentralized_ride::ride_matching::{Self, MatchingService, RideRequest};
    
    use iota::test_scenario::{Self as test, next_tx, ctx};

    #[test]
    fun test_user_registration() {
        let admin = @admin;
        let alice = @alice;
        
        let mut scenario = test::begin(admin);
        
        // Initialize user registry
        {
            user_registry::init_for_testing(ctx(&mut scenario));
        };
        
        // Alice registers user
        next_tx(&mut scenario, alice);
        {
            let mut registry = test::take_shared<UserRegistry>(&scenario);
            
            user_registry::register_user(
                &mut registry,
                b"Alice",
                b"did:iota:alice123",
                ctx(&mut scenario)
            );
            
            test::return_shared(registry);
        };
        
        // Verify user registered
        next_tx(&mut scenario, alice);
        {
            let user_profile = test::take_from_sender<UserProfile>(&scenario);
            assert!(user_registry::get_reputation(&user_profile) == 50, 0);
            assert!(!user_registry::is_verified(&user_profile), 1);
            test::return_to_sender(&scenario, user_profile);
        };
        
        test::end(scenario);
    }

    #[test]
    fun test_vehicle_registration() {
        let admin = @admin;
        let bob = @bob;
        
        let mut scenario = test::begin(admin);
        
        // Initialize vehicle registry
        {
            vehicle_registry::init_for_testing(ctx(&mut scenario));
        };
        
        // Bob registers vehicle
        next_tx(&mut scenario, bob);
        {
            let mut registry = test::take_shared<VehicleRegistry>(&scenario);
            
            vehicle_registry::register_vehicle(
                &mut registry,
                b"ABC123",
                b"Tesla Model S",
                true,  // 自動駕駛
                50000, // 每小時 50000 micro IOTA
                ctx(&mut scenario)
            );
            
            test::return_shared(registry);
        };
        
        // Verify vehicle registered
        next_tx(&mut scenario, bob);
        {
            let vehicle = test::take_from_sender<Vehicle>(&scenario);
            assert!(vehicle_registry::is_autonomous(&vehicle), 0);
            assert!(vehicle_registry::get_hourly_rate(&vehicle) == 50000, 1);
            assert!(vehicle_registry::get_status(&vehicle) == 0, 2); // Offline status
            test::return_to_sender(&scenario, vehicle);
        };
        
        test::end(scenario);
    }

    #[test]
    fun test_ride_matching() {
        let admin = @admin;
        let alice = @alice;  // 乘客
        let _bob = @bob;      // 司機
        
        let mut scenario = test::begin(admin);
        
        // Initialize matching service
        {
            ride_matching::init_for_testing(ctx(&mut scenario));
        };
        
        // Alice creates ride request
        next_tx(&mut scenario, alice);
        {
            let mut service = test::take_shared<MatchingService>(&scenario);
            
            ride_matching::create_ride_request(
                &mut service,
                b"Location A",
                b"Location B", 
                100000,  // Max price
                2,       // 2 passengers
                ctx(&mut scenario)
            );
            
            test::return_shared(service);
        };
        
        // Verify request created
        next_tx(&mut scenario, alice);
        {
            let request = test::take_from_sender<RideRequest>(&scenario);
            assert!(ride_matching::get_request_status(&request) == 0, 0); // PENDING
            test::return_to_sender(&scenario, request);
        };
        
        test::end(scenario);
    }
}
