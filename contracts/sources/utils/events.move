module decentralized_ride::events {
    use std::string::String;
    use iota::object::ID;
    use iota::tx_context::{Self, TxContext};
    use iota::event;
    
    // ============================================================================
    // 簡化的事件結構 (Simplified Event Structures)
    // ============================================================================
    
    // 用戶相關事件
    public struct UserRegistered has copy, drop {
        user_id: ID,
        user_address: address,
        timestamp: u64,
    }
    
    public struct UserStatusChanged has copy, drop {
        user_id: ID,
        old_status: u8,
        new_status: u8,
        timestamp: u64,
    }
    
    // 車輛相關事件
    public struct VehicleRegistered has copy, drop {
        vehicle_id: ID,
        owner: address,
        timestamp: u64,
    }
    
    public struct VehicleVerified has copy, drop {
        vehicle_id: ID,
        verified_by: address,
        timestamp: u64,
    }
    
    public struct VehicleStatusChanged has copy, drop {
        vehicle_id: ID,
        old_status: u8,
        new_status: u8,
        timestamp: u64,
    }
    
    public struct VehicleOwnershipTransferred has copy, drop {
        vehicle_id: ID,
        old_owner: address,
        new_owner: address,
        timestamp: u64,
    }
    
    // 行程相關事件
    public struct RideRequestCreated has copy, drop {
        request_id: ID,
        passenger: address,
        timestamp: u64,
    }
    
    public struct RideMatched has copy, drop {
        match_id: ID,
        request_id: ID,
        passenger: address,
        driver: address,
        vehicle_id: ID,
        agreed_price: u64,
        timestamp: u64,
    }
    
    public struct RideStarted has copy, drop {
        match_id: ID,
        timestamp: u64,
    }
    
    public struct RideCompleted has copy, drop {
        match_id: ID,
        final_fare: u64,
        timestamp: u64,
    }
    
    public struct RideCancelled has copy, drop {
        ride_id: ID,
        cancelled_by: address,
        reason: String,
        timestamp: u64,
    }
    
    // 金融相關事件
    public struct FundsLocked has copy, drop {
        escrow_id: ID,
        match_id: ID,
        amount: u64,
        timestamp: u64,
    }
    
    public struct FundsReleased has copy, drop {
        escrow_id: ID,
        recipient: address,
        amount: u64,
        timestamp: u64,
    }
    
    // 爭議相關事件
    public struct DisputeRaised has copy, drop {
        dispute_id: ID,
        match_id: ID,
        initiator: address,
        reason: String,
        timestamp: u64,
    }
    
    // ============================================================================
    // 事件發送函數 (Event Emission Functions)
    // ============================================================================
    
    // 用戶事件
    public fun emit_user_registered(user_id: ID, user_address: address, ctx: &TxContext) {
        event::emit(UserRegistered {
            user_id,
            user_address,
            timestamp: tx_context::epoch(ctx),
        });
    }
    
    public fun emit_user_status_changed(
        user_id: ID, 
        old_status: u8, 
        new_status: u8, 
        ctx: &TxContext
    ) {
        event::emit(UserStatusChanged {
            user_id,
            old_status,
            new_status,
            timestamp: tx_context::epoch(ctx),
        });
    }
    
    // 車輛事件
    public fun emit_vehicle_registered(vehicle_id: ID, owner: address, ctx: &TxContext) {
        event::emit(VehicleRegistered {
            vehicle_id,
            owner,
            timestamp: tx_context::epoch(ctx),
        });
    }
    
    public fun emit_vehicle_verified(vehicle_id: ID, verified_by: address, ctx: &TxContext) {
        event::emit(VehicleVerified {
            vehicle_id,
            verified_by,
            timestamp: tx_context::epoch(ctx),
        });
    }
    
    public fun emit_vehicle_status_changed(
        vehicle_id: ID, 
        old_status: u8, 
        new_status: u8, 
        ctx: &TxContext
    ) {
        event::emit(VehicleStatusChanged {
            vehicle_id,
            old_status,
            new_status,
            timestamp: tx_context::epoch(ctx),
        });
    }
    
    public fun emit_vehicle_ownership_transferred(
        vehicle_id: ID, 
        old_owner: address, 
        new_owner: address, 
        ctx: &TxContext
    ) {
        event::emit(VehicleOwnershipTransferred {
            vehicle_id,
            old_owner,
            new_owner,
            timestamp: tx_context::epoch(ctx),
        });
    }
    
    // 行程事件
    public fun emit_ride_request_created(request_id: ID, passenger: address, ctx: &TxContext) {
        event::emit(RideRequestCreated {
            request_id,
            passenger,
            timestamp: tx_context::epoch(ctx),
        });
    }
    
    public fun emit_ride_matched(
        match_id: ID,
        request_id: ID,
        passenger: address,
        driver: address,
        vehicle_id: ID,
        agreed_price: u64,
        ctx: &TxContext
    ) {
        event::emit(RideMatched {
            match_id,
            request_id,
            passenger,
            driver,
            vehicle_id,
            agreed_price,
            timestamp: tx_context::epoch(ctx),
        });
    }
    
    public fun emit_ride_started(match_id: ID, ctx: &TxContext) {
        event::emit(RideStarted {
            match_id,
            timestamp: tx_context::epoch(ctx),
        });
    }
    
    public fun emit_ride_completed(match_id: ID, final_fare: u64, ctx: &TxContext) {
        event::emit(RideCompleted {
            match_id,
            final_fare,
            timestamp: tx_context::epoch(ctx),
        });
    }
    
    public fun emit_ride_cancelled(
        ride_id: ID, 
        cancelled_by: address, 
        reason: String, 
        ctx: &TxContext
    ) {
        event::emit(RideCancelled {
            ride_id,
            cancelled_by,
            reason,
            timestamp: tx_context::epoch(ctx),
        });
    }
    
    // 金融事件
    public fun emit_funds_locked(escrow_id: ID, match_id: ID, amount: u64, ctx: &TxContext) {
        event::emit(FundsLocked {
            escrow_id,
            match_id,
            amount,
            timestamp: tx_context::epoch(ctx),
        });
    }
    
    public fun emit_funds_released(
        escrow_id: ID, 
        recipient: address, 
        amount: u64, 
        ctx: &TxContext
    ) {
        event::emit(FundsReleased {
            escrow_id,
            recipient,
            amount,
            timestamp: tx_context::epoch(ctx),
        });
    }
    
    // 爭議事件
    public fun emit_dispute_raised(
        dispute_id: ID,
        match_id: ID,
        initiator: address,
        reason: String,
        ctx: &TxContext
    ) {
        event::emit(DisputeRaised {
            dispute_id,
            match_id,
            initiator,
            reason,
            timestamp: tx_context::epoch(ctx),
        });
    }
}
