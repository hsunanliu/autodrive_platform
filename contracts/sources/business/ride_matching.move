module decentralized_ride::ride_matching {
    use std::string::{Self, String};
    use iota::object::{Self, UID, ID};
    use iota::tx_context::{Self, TxContext};
    use iota::transfer;
    
    use decentralized_ride::vehicle_registry;
    use decentralized_ride::user_registry;
    use decentralized_ride::constants;
    use decentralized_ride::events;

    // ============================================================================
    // 極簡資料結構 (Minimalist Data Structures)
    // ============================================================================
    
    /// 簡化的叫車請求 - 只保留核心信息
    public struct RideRequest has key, store {
        id: UID,
        passenger: address,              // 乘客地址
        request_hash: vector<u8>,        // 請求資料雜湊 (後端計算)
        max_price: u64,                  // 最高接受價格
        status: u8,                      // 請求狀態
        created_at: u64,                 // 創建時間
        expires_at: u64,                 // 過期時間
    }

    /// 極簡的配對記錄 - 只記錄關鍵狀態
    public struct RideMatch has key, store {
        id: UID,
        request_id: ID,                  // 關聯請求
        vehicle_id: ID,                  // 關聯車輛
        passenger: address,              // 乘客地址
        driver: address,                 // 司機地址
        agreed_price: u64,               // 成交價格
        status: u8,                      // 配對狀態
        matched_at: u64,                 // 配對時間
        started_at: u64,                 // 開始時間
        completed_at: u64,               // 完成時間
    }

    /// 配對服務管理 - 最小配置
    public struct MatchingService has key {
        id: UID,
        total_requests: u64,             // 總請求數
        total_matches: u64,              // 總配對數
        total_completed: u64,            // 總完成數
        admin: address,                  // 管理員
        is_active: bool,                 // 服務狀態
    }

    // ============================================================================
    // 初始化 (Initialization)
    // ============================================================================
     #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }

  fun init(ctx: &mut TxContext) {
    // 添加調試事件
    use iota::event;
    
    // 調試：確認函數被調用
    event::emit(InitDebugEvent {
        message: b"init function started".to_string(),
        sender: tx_context::sender(ctx),
    });
    
    let service = MatchingService {
        id: object::new(ctx),
        total_requests: 0,
        total_matches: 0,
        total_completed: 0,
        admin: tx_context::sender(ctx),
        is_active: true,
    };
    
    // 調試：確認對象創建
    event::emit(InitDebugEvent {
        message: b"MatchingService created".to_string(),
        sender: tx_context::sender(ctx),
    });
    
    transfer::share_object(service);
    
    // 調試：確認共享完成
    event::emit(InitDebugEvent {
        message: b"MatchingService shared".to_string(),
        sender: tx_context::sender(ctx),
    });
    }

// 添加調試事件結構
    public struct InitDebugEvent has copy, drop {
        message: String,
        sender: address,
    }


    // ============================================================================
    // 核心功能 - 信任關鍵操作 (Core Trust-Critical Functions)
    // ============================================================================

    /// 創建叫車請求 - 極簡版本
    /// 複雜的地理計算、司機過濾等邏輯由後端處理
    public entry fun create_ride_request(
        service: &mut MatchingService,
        user_profile: &user_registry::UserProfile,
        request_hash: vector<u8>,        // 後端計算的請求資料雜湊
        max_price: u64,                  // 最高接受價格
        ctx: &mut TxContext
    ) {
        let passenger = tx_context::sender(ctx);
        let current_time = tx_context::epoch(ctx);
        
        // 基本驗證
        assert!(service.is_active, constants::e_service_suspended());
        assert!(user_registry::can_request_ride(user_profile), constants::e_user_suspended());
        assert!(max_price > 0, constants::e_invalid_data_format());

        let request = RideRequest {
            id: object::new(ctx),
            passenger,
            request_hash,
            max_price,
            status: constants::ride_status_pending(),
            created_at: current_time,
            expires_at: current_time + constants::ride_request_timeout(),
        };

        service.total_requests = service.total_requests + 1;

        // 發送事件 - 後端監聽並開始配對算法
        events::emit_ride_request_created(
            object::id(&request),
            passenger,
            ctx
        );

        transfer::transfer(request, passenger);
    }

    /// 確認配對 - 由後端算法決定最佳配對後調用
    /// 這是信任關鍵操作，必須在鏈上執行
    public entry fun confirm_match(
        service: &mut MatchingService,
        request: &mut RideRequest,
        vehicle: &mut vehicle_registry::Vehicle,
        driver_profile: &user_registry::UserProfile,
        agreed_price: u64,
        match_signature: vector<u8>,     // 後端生成的配對簽名 (防作弊)
        ctx: &mut TxContext
    ) {
        let driver = tx_context::sender(ctx);
        let current_time = tx_context::epoch(ctx);
        
        // 嚴格驗證
        assert!(service.is_active, constants::e_service_suspended());
        assert!(request.status == constants::ride_status_pending(), constants::e_invalid_ride_status());
        assert!(current_time < request.expires_at, constants::e_request_expired());
        assert!(agreed_price <= request.max_price, constants::e_price_mismatch());
        
        // 驗證司機和車輛狀態
        assert!(user_registry::can_drive(driver_profile), constants::e_user_suspended());
        assert!(vehicle_registry::get_owner(vehicle) == driver, constants::e_not_vehicle_owner());
        assert!(vehicle_registry::is_available(vehicle), constants::e_vehicle_not_available());
        
        // TODO: 驗證後端配對簽名 (防止作弊配對)
        // assert!(verify_match_signature(match_signature, ...), E_INVALID_SIGNATURE);

        // 更新狀態
        request.status = constants::ride_status_matched();
        vehicle_registry::update_status(vehicle, constants::vehicle_status_busy(), ctx);

        let ride_match = RideMatch {
            id: object::new(ctx),
            request_id: object::id(request),
            vehicle_id: object::id(vehicle),
            passenger: request.passenger,
            driver,
            agreed_price,
            status: constants::ride_status_matched(),
            matched_at: current_time,
            started_at: 0,
            completed_at: 0,
        };

        service.total_matches = service.total_matches + 1;

        // 發送配對成功事件
        events::emit_ride_matched(
            object::id(&ride_match),
            object::id(request),
            request.passenger,
            driver,
            object::id(vehicle),
            agreed_price,
            ctx
        );

        transfer::transfer(ride_match, driver);
    }

    /// 開始行程 - 司機確認乘客上車
    public entry fun start_ride(
        ride_match: &mut RideMatch,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == ride_match.driver, constants::e_unauthorized());
        assert!(ride_match.status == constants::ride_status_matched(), constants::e_invalid_ride_status());

        ride_match.status = constants::ride_status_active();
        ride_match.started_at = tx_context::epoch(ctx);

        events::emit_ride_started(object::id(ride_match), ctx);
    }

    /// 完成行程 - 關鍵的狀態轉換和統計更新
    public entry fun complete_ride(
        service: &mut MatchingService,
        ride_match: &mut RideMatch,
        vehicle: &mut vehicle_registry::Vehicle,
        passenger_profile: &mut user_registry::UserProfile,
        driver_profile: &mut user_registry::UserProfile,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == ride_match.driver, constants::e_unauthorized());
        assert!(ride_match.status == constants::ride_status_active(), constants::e_invalid_ride_status());

        let current_time = tx_context::epoch(ctx);

        // 更新行程狀態
        ride_match.status = constants::ride_status_completed();
        ride_match.completed_at = current_time;

        // 更新車輛狀態
        vehicle_registry::update_status(vehicle, constants::vehicle_status_available(), ctx);
        vehicle_registry::add_trip(vehicle);

        // 更新用戶統計
        user_registry::add_ride(passenger_profile);
        user_registry::add_drive(driver_profile);

        // 更新服務統計
        service.total_completed = service.total_completed + 1;

        events::emit_ride_completed(
            object::id(ride_match),
            ride_match.agreed_price,
            ctx
        );
    }

    /// 取消請求 - 乘客可在配對前取消
    public entry fun cancel_request(
        request: &mut RideRequest,
        reason: vector<u8>,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == request.passenger, constants::e_unauthorized());
        assert!(request.status == constants::ride_status_pending(), constants::e_invalid_ride_status());

        request.status = constants::ride_status_cancelled();

        events::emit_ride_cancelled(
            object::id(request),
            request.passenger,
            string::utf8(reason),
            ctx
        );
    }

    // 修復爭議處理函數
    public entry fun raise_dispute(
        ride_match: &mut RideMatch,
        dispute_reason: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        
        assert!(
            sender == ride_match.passenger || sender == ride_match.driver,
            constants::e_unauthorized()
        );
        assert!(ride_match.status == constants::ride_status_completed(), constants::e_invalid_ride_status());

        ride_match.status = constants::ride_status_disputed();

        // 修復事件發送 - 創建簡單的 dispute ID
        let dispute_id = object::id_from_address(sender);
        events::emit_dispute_raised(
            dispute_id,
            object::id(ride_match),
            sender,
            string::utf8(dispute_reason),
            ctx
        );
    }

    // ============================================================================
    // 管理功能 (Administrative Functions)  
    // ============================================================================

    /// 暫停/恢復服務 - 緊急控制
    public entry fun toggle_service(
        service: &mut MatchingService,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == service.admin, constants::e_unauthorized());
        service.is_active = !service.is_active;
    }

    // ============================================================================
    // 查詢函數 (Query Functions)
    // ============================================================================

    public fun get_request_status(request: &RideRequest): u8 {
        request.status
    }

    public fun get_match_info(ride_match: &RideMatch): (address, address, u64, u8) {
        (ride_match.passenger, ride_match.driver, ride_match.agreed_price, ride_match.status)
    }

    public fun is_request_active(request: &RideRequest, current_time: u64): bool {
        request.status == constants::ride_status_pending() && current_time < request.expires_at
    }

    public fun get_service_stats(service: &MatchingService): (u64, u64, u64, bool) {
        (service.total_requests, service.total_matches, service.total_completed, service.is_active)
    }

    public fun get_ride_duration(ride_match: &RideMatch): u64 {
        if (ride_match.completed_at > 0 && ride_match.started_at > 0) {
            ride_match.completed_at - ride_match.started_at
        } else {
            0
        }
    }
    
}
