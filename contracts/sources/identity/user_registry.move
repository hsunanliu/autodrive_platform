module decentralized_ride::user_registry {
    use std::string::String;
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use decentralized_ride::constants;
    use decentralized_ride::events;
    
    // ============================================================================
    // 簡化的資料結構 (Simplified Data Structures)
    // ============================================================================
    
    /// 極簡用戶資料 - 只保留核心信息
    public struct UserProfile has key, store {
        id: UID,
        user_address: address,           // 用戶地址
        did_hash: vector<u8>,           // DID 雜湊 - 隱私保護
        reputation: u64,                // 信譽分數
        total_rides: u64,               // 總行程數 (作為乘客)
        total_drives: u64,              // 總行程數 (作為司機)
        status: u8,                     // 用戶狀態
        created_at: u64,                // 註冊時間
    }
    
    /// 簡化的用戶註冊表
    public struct UserRegistry has key {
        id: UID,
        total_users: u64,
        admin: address,
    }
    
    // ============================================================================
    // 初始化 (Initialization)
    // ============================================================================
    
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
    
    fun init(ctx: &mut TxContext) {
        let registry = UserRegistry {
            id: object::new(ctx),
            total_users: 0,
            admin: tx_context::sender(ctx),
        };
        transfer::share_object(registry);
    }
    
    
    
    // ============================================================================
    // 核心功能 (Core Functions)
    // ============================================================================

    // 添加 getter 函數
    public fun get_total_users(registry: &UserRegistry): u64 {
        registry.total_users
    }
    
    /// 用戶註冊 - 簡化版
    public entry fun register_user(
        registry: &mut UserRegistry,
        did_hash: vector<u8>,           // 後端提供的 DID 雜湊
        ctx: &mut TxContext
    ) {
        let user_address = tx_context::sender(ctx);
        
        let user_profile = UserProfile {
            id: object::new(ctx),
            user_address,
            did_hash,
            reputation: constants::default_reputation(),
            total_rides: 0,
            total_drives: 0,
            status: constants::user_status_active(),
            created_at: tx_context::epoch(ctx),
        };

        registry.total_users = registry.total_users + 1;

        events::emit_user_registered(
            object::id(&user_profile),
            user_address,
            ctx
        );

        transfer::transfer(user_profile, user_address);
    }
    
    /// 更新用戶狀態 (管理員功能)
    public entry fun update_user_status(
        registry: &UserRegistry,
        user_profile: &mut UserProfile,
        new_status: u8,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == registry.admin, constants::e_unauthorized());
        assert!(constants::is_valid_user_status(new_status), constants::e_invalid_status());
        
        let old_status = user_profile.status;
        user_profile.status = new_status;

        events::emit_user_status_changed(
            object::id(user_profile),
            old_status,
            new_status,
            ctx
        );
    }
    
    /// 更新信譽分數 (由其他模組調用)
    public fun update_reputation(user_profile: &mut UserProfile, new_reputation: u64) {
        assert!(constants::is_valid_reputation(new_reputation), constants::e_invalid_reputation());
        user_profile.reputation = new_reputation;
    }
    
    /// 增加乘客行程計數
    public fun add_ride(user_profile: &mut UserProfile) {
        user_profile.total_rides = user_profile.total_rides + 1;
    }
    
    /// 增加司機行程計數
    public fun add_drive(user_profile: &mut UserProfile) {
        user_profile.total_drives = user_profile.total_drives + 1;
    }
    
    // ============================================================================
    // 查詢函數 (Query Functions)
    // ============================================================================
    
    public fun get_reputation(user_profile: &UserProfile): u64 {
        user_profile.reputation
    }
    
    public fun get_status(user_profile: &UserProfile): u8 {
        user_profile.status
    }
    
    public fun is_active(user_profile: &UserProfile): bool {
        user_profile.status == constants::user_status_active()
    }
    
    public fun get_ride_stats(user_profile: &UserProfile): (u64, u64) {
        (user_profile.total_rides, user_profile.total_drives)
    }
    
    public fun can_request_ride(user_profile: &UserProfile): bool {
        user_profile.status == constants::user_status_active() &&
        user_profile.reputation >= constants::min_driver_reputation()
    }
    
    public fun can_drive(user_profile: &UserProfile): bool {
        user_profile.status == constants::user_status_active() &&
        user_profile.reputation >= constants::min_driver_reputation()
    }
    
    public fun get_user_address(user_profile: &UserProfile): address {
        user_profile.user_address
    }
    
    public fun get_total_activity(user_profile: &UserProfile): u64 {
        user_profile.total_rides + user_profile.total_drives
    }
}
