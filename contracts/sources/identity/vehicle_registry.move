module decentralized_ride::vehicle_registry {
    use std::string::String;
    use iota::object::{Self, UID, ID};
    use iota::tx_context::{Self, TxContext};
    use iota::transfer;
    use decentralized_ride::constants;
    use decentralized_ride::events;

    // ===== 簡化的資料結構 =====
    
    /// 極簡車輛記錄 - 只保留核心信息
    public struct Vehicle has key, store {
        id: UID,
        owner: address,              // 所有權 - 核心
        vehicle_data_hash: vector<u8>, // 車輛資料雜湊 - 防篡改
        status: u8,                  // 基本狀態 (0:離線, 1:可用, 2:使用中)
        is_verified: bool,           // 驗證狀態 - 信任關鍵
        total_trips: u64,            // 行程統計 - 信譽計算
        created_at: u64,             // 註冊時間
    }

    /// 簡化的註冊表
    public struct VehicleRegistry has key {
        id: UID,
        total_vehicles: u64,
        admin: address,
    }
     // ===== 初始化 =====
    // 添加測試初始化函數
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }

    fun init(ctx: &mut TxContext) {
        let registry = VehicleRegistry {
            id: object::new(ctx),
            total_vehicles: 0,
            admin: tx_context::sender(ctx),
        };
        transfer::share_object(registry);
    }

    // ===== 核心功能 (僅保留必要操作) =====
    

    // 添加 getter 函數用於測試
    public fun get_total_vehicles(registry: &VehicleRegistry): u64 {
        registry.total_vehicles
    }

    /// 註冊車輛 - 簡化版
    public entry fun register_vehicle(
        registry: &mut VehicleRegistry,
        vehicle_data_hash: vector<u8>,  // 後端提供的車輛資料雜湊
        ctx: &mut TxContext
    ) {
        let owner = tx_context::sender(ctx);
        
        let vehicle = Vehicle {
            id: object::new(ctx),
            owner,
            vehicle_data_hash,
            status: constants::vehicle_status_offline(),
            is_verified: false,
            total_trips: 0,
            created_at: tx_context::epoch(ctx),
        };

        registry.total_vehicles = registry.total_vehicles + 1;

        events::emit_vehicle_registered(
            object::id(&vehicle),
            owner,
            ctx
        );

        transfer::transfer(vehicle, owner);
    }

    /// 管理員驗證車輛
    public entry fun verify_vehicle(
        registry: &VehicleRegistry,
        vehicle: &mut Vehicle,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == registry.admin, constants::e_unauthorized());
        vehicle.is_verified = true;
        vehicle.status = constants::vehicle_status_available();

        events::emit_vehicle_verified(
            object::id(vehicle),
            registry.admin,
            ctx
        );
    }

    /// 更新車輛狀態
    public entry fun update_status(
        vehicle: &mut Vehicle,
        new_status: u8,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == vehicle.owner, constants::e_not_vehicle_owner());
        assert!(vehicle.is_verified, constants::e_vehicle_not_verified());
        assert!(constants::is_valid_vehicle_status(new_status), constants::e_invalid_vehicle_status());

        let old_status = vehicle.status;
        vehicle.status = new_status;

        events::emit_vehicle_status_changed(
            object::id(vehicle),
            old_status,
            new_status,
            ctx
        );
    }

    /// 增加行程計數 (由配對模組調用)
    public fun add_trip(vehicle: &mut Vehicle) {
        vehicle.total_trips = vehicle.total_trips + 1;
    }

    /// 轉移所有權
    public entry fun transfer_ownership(
        vehicle: &mut Vehicle,
        new_owner: address,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == vehicle.owner, constants::e_not_vehicle_owner());
        
        let old_owner = vehicle.owner;
        vehicle.owner = new_owner;
        vehicle.is_verified = false; // 需重新驗證

        events::emit_vehicle_ownership_transferred(
            object::id(vehicle),
            old_owner,
            new_owner,
            ctx
        );
    }

    // ===== 查詢函數 =====
    
    public fun is_available(vehicle: &Vehicle): bool {
        vehicle.status == constants::vehicle_status_available() && vehicle.is_verified
    }

    public fun get_owner(vehicle: &Vehicle): address {
        vehicle.owner
    }

    public fun get_total_trips(vehicle: &Vehicle): u64 {
        vehicle.total_trips
    }
    
}
