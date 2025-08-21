// sources/user_registry.move
module decentralized_ride::user_registry {
    use std::string::{Self, String};

    use iota::event;

    // ===== Error Codes =====
    const E_NOT_AUTHORIZED: u64 = 2;

    // ===== Data Structures =====
    
    /// Simplified user profile
    public struct UserProfile has key, store {
        id: UID,
        name: String,
        did: String,
        reputation: u64,        // 0-100 points
        total_rides: u64,
        is_verified: bool,
        owner: address,
    }

    /// Global user registry
    public struct UserRegistry has key {
        id: UID,
        total_users: u64,
        admin: address,
    }

    // ===== Events =====
    
    public struct UserRegistered has copy, drop {
        user_id: ID,
        name: String,
        owner: address,
    }

    public struct UserVerified has copy, drop {
        user_id: ID,
        owner: address,
    }

    // ===== Initialization =====
    
    fun init(ctx: &mut TxContext) {
        let registry = UserRegistry {
            id: object::new(ctx),
            total_users: 0,
            admin: tx_context::sender(ctx),
        };
        transfer::share_object(registry);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx)
    }

    // ===== Public Functions =====
    
    /// Register new user
    public entry fun register_user(
        registry: &mut UserRegistry,
        name: vector<u8>,
        did: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        
        let user_profile = UserProfile {
            id: object::new(ctx),
            name: string::utf8(name),
            did: string::utf8(did),
            reputation: 50,     // Initial score
            total_rides: 0,
            is_verified: false,
            owner: sender,
        };

        let user_id = object::id(&user_profile);
        registry.total_users = registry.total_users + 1;

        // Emit event
        event::emit(UserRegistered {
            user_id,
            name: string::utf8(name),
            owner: sender,
        });

        // Transfer to user
        transfer::transfer(user_profile, sender);
    }

    /// Verify user (admin only)
    public entry fun verify_user(
        registry: &UserRegistry,
        user_profile: &mut UserProfile,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == registry.admin, E_NOT_AUTHORIZED);
        
        user_profile.is_verified = true;

        event::emit(UserVerified {
            user_id: object::id(user_profile),
            owner: user_profile.owner,
        });
    }

    /// Update reputation score
    public entry fun update_reputation(
        user_profile: &mut UserProfile,
        new_score: u64,
    ) {
        assert!(new_score <= 100, 0);
        user_profile.reputation = new_score;
    }

    /// Increment ride count
    public fun add_ride(user_profile: &mut UserProfile) {
        user_profile.total_rides = user_profile.total_rides + 1;
    }

    // ===== Query Functions =====
    
    public fun get_reputation(user: &UserProfile): u64 {
        user.reputation
    }

    public fun is_verified(user: &UserProfile): bool {
        user.is_verified
    }

    public fun get_total_rides(user: &UserProfile): u64 {
        user.total_rides
    }
}
