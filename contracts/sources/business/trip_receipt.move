module decentralized_ride::trip_receipt {
    use std::string::String;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;

    /// 行程收據 - 不可篡改的證明
    public struct TripReceipt has key, store {
        id: UID,
        trip_id: u64,           // 後端行程ID
        passenger: address,
        driver: address,
        pickup_hash: vector<u8>,    // 位置資料哈希
        dropoff_hash: vector<u8>,
        distance_km: u64,
        final_amount: u64,
        completed_at: u64,
    }

    /// 創建收據 - 只能在支付釋放後調用
    public entry fun create_receipt(
        trip_id: u64,
        driver: address,
        pickup_hash: vector<u8>,
        dropoff_hash: vector<u8>,
        distance_km: u64,
        final_amount: u64,
        ctx: &mut TxContext
    ) {
        let receipt = TripReceipt {
            id: object::new(ctx),
            trip_id,
            passenger: tx_context::sender(ctx),
            driver,
            pickup_hash,
            dropoff_hash,
            distance_km,
            final_amount,
            completed_at: tx_context::epoch(ctx),
        };
        
        // 轉移給乘客作為永久記錄
        transfer::transfer(receipt, tx_context::sender(ctx));
    }
}