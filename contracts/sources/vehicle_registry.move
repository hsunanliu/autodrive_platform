// sources/vehicle_registry.move
module decentralized_ride::vehicle_registry {
    use std::string::{Self, String};

    use iota::event;

    // ===== Constants and Errors =====
    const STATUS_OFFLINE: u8 = 0;
    const STATUS_AVAILABLE: u8 = 1;
    
    const E_NOT_OWNER: u64 = 1;
    const E_INVALID_STATUS: u64 = 2;

    // ===== Data Structures =====
    
    /// Simplified vehicle data
    public struct Vehicle has key, store {
        id: UID,
        license_plate: String,
        model: String,
        owner: address,
        is_autonomous: bool,
        status: u8,             // 0: Offline, 1: Available, 2: Busy
        hourly_rate: u64,       // Hourly rate (micro IOTA)
        total_trips: u64,
        is_verified: bool,
    }

    /// Vehicle registry
    public struct VehicleRegistry has key {
        id: UID,
        total_vehicles: u64,
        admin: address,
    }

    // ===== Events =====
    
    public struct VehicleRegistered has copy, drop {
        vehicle_id: ID,
        license_plate: String,
        owner: address,
        is_autonomous: bool,
    }

    public struct VehicleStatusChanged has copy, drop {
        vehicle_id: ID,
        old_status: u8,
        new_status: u8,
    }

    // ===== Initialization =====
    
    fun init(ctx: &mut TxContext) {
        let registry = VehicleRegistry {
            id: object::new(ctx),
            total_vehicles: 0,
            admin: tx_context::sender(ctx),
        };
        transfer::share_object(registry);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx)
    }

    // ===== Public Functions =====
    
    /// Register vehicle
    public entry fun register_vehicle(
        registry: &mut VehicleRegistry,
        license_plate: vector<u8>,
        model: vector<u8>,
        is_autonomous: bool,
        hourly_rate: u64,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        
        let vehicle = Vehicle {
            id: object::new(ctx),
            license_plate: string::utf8(license_plate),
            model: string::utf8(model),
            owner: sender,
            is_autonomous,
            status: STATUS_OFFLINE, // Initial status: Offline
            hourly_rate,
            total_trips: 0,
            is_verified: false,
        };

        let vehicle_id = object::id(&vehicle);
        registry.total_vehicles = registry.total_vehicles + 1;

        // Emit event
        event::emit(VehicleRegistered {
            vehicle_id,
            license_plate: string::utf8(license_plate),
            owner: sender,
            is_autonomous,
        });

        // Transfer to owner
        transfer::transfer(vehicle, sender);
    }

    /// Update vehicle status
    public entry fun set_vehicle_status(
        vehicle: &mut Vehicle,
        new_status: u8,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == vehicle.owner, E_NOT_OWNER);
        assert!(new_status <= 2, E_INVALID_STATUS);

        let old_status = vehicle.status;
        vehicle.status = new_status;

        event::emit(VehicleStatusChanged {
            vehicle_id: object::id(vehicle),
            old_status,
            new_status,
        });
    }

    /// Verify vehicle
    public entry fun verify_vehicle(
        registry: &VehicleRegistry,
        vehicle: &mut Vehicle,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == registry.admin, 0);
        vehicle.is_verified = true;
    }

    /// Increment trip count
    public fun add_trip(vehicle: &mut Vehicle) {
        vehicle.total_trips = vehicle.total_trips + 1;
    }

    // ===== Query Functions =====
    
    public fun is_available(vehicle: &Vehicle): bool {
        vehicle.status == STATUS_AVAILABLE && vehicle.is_verified
    }

    public fun get_hourly_rate(vehicle: &Vehicle): u64 {
        vehicle.hourly_rate
    }

    public fun is_autonomous(vehicle: &Vehicle): bool {
        vehicle.is_autonomous
    }

    public fun get_status(vehicle: &Vehicle): u8 {
        vehicle.status
    }
}
