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
        // Walrus 錨定：完整 GPS 軌跡存於 Walrus，鏈上只留 blob_id 與內容雜湊。
        // 讀取時後端從 Walrus 取回並比對 trajectory_hash，確保完整性。
        // 空 vector 代表此趟未上傳軌跡。
        trajectory_blob_id: vector<u8>,
        trajectory_hash: vector<u8>,
    }

    /// 創建收據 - 乘客本人調用（收據歸發起者）
    public entry fun create_receipt(
        trip_id: u64,
        driver: address,
        pickup_hash: vector<u8>,
        dropoff_hash: vector<u8>,
        distance_km: u64,
        final_amount: u64,
        trajectory_blob_id: vector<u8>,
        trajectory_hash: vector<u8>,
        ctx: &mut TxContext
    ) {
        create_receipt_for(
            tx_context::sender(ctx), trip_id, driver, pickup_hash, dropoff_hash,
            distance_km, final_amount, trajectory_blob_id, trajectory_hash, ctx
        );
    }

    /// 為指定乘客創建收據並轉移給該乘客。
    /// 供其他模組在複合交易中呼叫（例如 payment_escrow 在 Agent 結算時，發起者是 Agent
    /// 而非乘客，需明確指定收據歸屬的乘客）。
    public fun create_receipt_for(
        passenger: address,
        trip_id: u64,
        driver: address,
        pickup_hash: vector<u8>,
        dropoff_hash: vector<u8>,
        distance_km: u64,
        final_amount: u64,
        trajectory_blob_id: vector<u8>,
        trajectory_hash: vector<u8>,
        ctx: &mut TxContext
    ) {
        let receipt = TripReceipt {
            id: object::new(ctx),
            trip_id,
            passenger,
            driver,
            pickup_hash,
            dropoff_hash,
            distance_km,
            final_amount,
            completed_at: tx_context::epoch(ctx),
            trajectory_blob_id,
            trajectory_hash,
        };
        transfer::transfer(receipt, passenger);
    }

    // ===== 視圖函數 =====
    public fun trip_id(receipt: &TripReceipt): u64 { receipt.trip_id }
    public fun passenger(receipt: &TripReceipt): address { receipt.passenger }
    public fun driver(receipt: &TripReceipt): address { receipt.driver }
    public fun final_amount(receipt: &TripReceipt): u64 { receipt.final_amount }
    public fun trajectory_blob_id(receipt: &TripReceipt): vector<u8> { receipt.trajectory_blob_id }
    public fun trajectory_hash(receipt: &TripReceipt): vector<u8> { receipt.trajectory_hash }
}