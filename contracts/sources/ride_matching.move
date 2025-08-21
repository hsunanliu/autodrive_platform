// sources/ride_matching.move
module decentralized_ride::ride_matching {
    use std::string::{Self, String};

    use iota::event;

    // ===== Constants and Errors =====
    const STATUS_PENDING: u8 = 0;
    const STATUS_MATCHED: u8 = 1; 
    const STATUS_COMPLETED: u8 = 2;

    const E_INVALID_STATUS: u64 = 1;
    const E_NOT_AUTHORIZED: u64 = 2;

    // ===== Data Structures =====
    
    /// Simplified ride request
    public struct RideRequest has key, store {
        id: UID,
        passenger: address,
        pickup_location: String,
        destination: String,
        max_price: u64,
        passenger_count: u8,
        status: u8,
        requester: address,
    }

    /// Simplified ride match record
    public struct RideMatch has key, store {
        id: UID,
        request_id: ID,
        vehicle_id: ID,
        passenger: address,
        driver: address,
        agreed_price: u64,
        status: u8,
    }

    /// Matching service
    public struct MatchingService has key {
        id: UID,
        total_requests: u64,
        total_matches: u64,
        service_fee_rate: u64,      // Service fee rate (basis points)
        admin: address,
    }

    // ===== Events =====
    
    public struct RideRequestCreated has copy, drop {
        request_id: ID,
        passenger: address,
        pickup_location: String,
        destination: String,
    }

    public struct RideMatched has copy, drop {
        request_id: ID,
        match_id: ID,
        vehicle_id: ID,
        passenger: address,
        driver: address,
        agreed_price: u64,
    }

    public struct RideCompleted has copy, drop {
        match_id: ID,
        request_id: ID,
    }

    // ===== Initialization =====
    
    fun init(ctx: &mut TxContext) {
        let service = MatchingService {
            id: object::new(ctx),
            total_requests: 0,
            total_matches: 0,
            service_fee_rate: 250,  // 2.5%
            admin: tx_context::sender(ctx),
        };
        transfer::share_object(service);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx)
    }

    // ===== Public Functions =====
    
    /// Create ride request
    public entry fun create_ride_request(
        service: &mut MatchingService,
        pickup_location: vector<u8>,
        destination: vector<u8>,
        max_price: u64,
        passenger_count: u8,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        
        let request = RideRequest {
            id: object::new(ctx),
            passenger: sender,
            pickup_location: string::utf8(pickup_location),
            destination: string::utf8(destination),
            max_price,
            passenger_count,
            status: STATUS_PENDING,
            requester: sender,
        };

        let request_id = object::id(&request);
        service.total_requests = service.total_requests + 1;

        // Emit event
        event::emit(RideRequestCreated {
            request_id,
            passenger: sender,
            pickup_location: string::utf8(pickup_location),
            destination: string::utf8(destination),
        });

        // Transfer to requester
        transfer::transfer(request, sender);
    }

    /// Match ride request
    public entry fun match_request(
        service: &mut MatchingService,
        request: &mut RideRequest,
        vehicle_id: ID,
        driver_address: address,
        agreed_price: u64,
        ctx: &mut TxContext
    ) {
        assert!(request.status == STATUS_PENDING, E_INVALID_STATUS);
        assert!(agreed_price <= request.max_price, 0);

        let request_id = object::id(request);
        
        let ride_match = RideMatch {
            id: object::new(ctx),
            request_id,
            vehicle_id,
            passenger: request.passenger,
            driver: driver_address,
            agreed_price,
            status: STATUS_MATCHED,
        };

        let match_id = object::id(&ride_match);
        
        // Update request status
        request.status = STATUS_MATCHED;
        service.total_matches = service.total_matches + 1;

        // Emit event
        event::emit(RideMatched {
            request_id,
            match_id,
            vehicle_id,
            passenger: request.passenger,
            driver: driver_address,
            agreed_price,
        });

        // Transfer to driver
        transfer::transfer(ride_match, driver_address);
    }

    /// Complete ride
    public entry fun complete_ride(
        ride_match: &mut RideMatch,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == ride_match.driver, E_NOT_AUTHORIZED);
        assert!(ride_match.status == STATUS_MATCHED, E_INVALID_STATUS);

        ride_match.status = STATUS_COMPLETED;

        event::emit(RideCompleted {
            match_id: object::id(ride_match),
            request_id: ride_match.request_id,
        });
    }

    // ===== Query Functions =====
    
    public fun get_request_status(request: &RideRequest): u8 {
        request.status
    }

    public fun get_match_status(ride_match: &RideMatch): u8 {
        ride_match.status
    }

    public fun get_agreed_price(ride_match: &RideMatch): u64 {
        ride_match.agreed_price
    }

    /// Calculate service fee
    public fun calculate_service_fee(service: &MatchingService, amount: u64): u64 {
        (amount * service.service_fee_rate) / 10000
    }
}
