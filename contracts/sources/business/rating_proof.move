/// 評價存證模組
/// 將車輛評價的 hash 存儲在區塊鏈上，確保評價內容不可篡改
module decentralized_ride::rating_proof {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;
    use decentralized_ride::trip_receipt::{Self, TripReceipt};

    // ============================================================
    // 錯誤碼
    // ============================================================

    /// 評分超出範圍
    const ERR_INVALID_RATING: u64 = 1;
    /// 無效的 hash 長度
    const ERR_INVALID_HASH_LENGTH: u64 = 2;
    /// 評價者不是該行程的乘客
    const ERR_NOT_TRIP_PASSENGER: u64 = 3;
    /// 行程 ID 與收據不符
    const ERR_TRIP_ID_MISMATCH: u64 = 4;
    /// 統計對象與車輛不符
    const ERR_VEHICLE_MISMATCH: u64 = 5;

    /// 評價統計管理權（部署時發給平台，用於建立每車唯一的統計對象）
    public struct RatingAdminCap has key, store {
        id: UID,
    }

    fun init(ctx: &mut TxContext) {
        transfer::transfer(RatingAdminCap { id: object::new(ctx) }, tx_context::sender(ctx));
    }

    // ============================================================
    // 結構體
    // ============================================================

    /// 評價存證 - 不可篡改的鏈上記錄
    public struct RatingProof has key, store {
        id: UID,
        /// 後端評價 ID
        rating_id: u64,
        /// 後端行程 ID
        trip_id: u64,
        /// 車輛 ID (hash 格式存儲)
        vehicle_id_hash: vector<u8>,
        /// 評價者地址
        rater: address,
        /// 評分 (1-5)
        rating: u8,
        /// 評價內容 SHA256 hash（完整性校驗）
        content_hash: vector<u8>,
        /// Walrus blob_id：完整評價文字/媒體存於 Walrus，鏈上只留 blob_id + hash。
        /// 空 vector 代表無額外內容（僅評分）。
        content_blob_id: vector<u8>,
        /// 創建時間 (epoch)
        created_at: u64,
    }

    /// 車輛評價統計 (共享對象)
    public struct VehicleRatingStats has key {
        id: UID,
        /// 車輛 ID hash
        vehicle_id_hash: vector<u8>,
        /// 總評價數
        total_ratings: u64,
        /// 總評分 (用於計算平均)
        total_score: u64,
        /// 評分分布
        rating_1_count: u64,
        rating_2_count: u64,
        rating_3_count: u64,
        rating_4_count: u64,
        rating_5_count: u64,
    }

    // ============================================================
    // 事件
    // ============================================================

    /// 評價存證創建事件
    public struct RatingProofCreated has copy, drop {
        proof_id: address,
        rating_id: u64,
        trip_id: u64,
        rater: address,
        rating: u8,
        content_hash: vector<u8>,
    }

    // ============================================================
    // 入口函數
    // ============================================================

    /// 創建評價存證
    /// 必須出示該行程的 `TripReceipt`（乘客持有的不可篡改收據），且：
    ///   - 呼叫者必須是該收據的乘客（證明真的搭過這趟車）
    ///   - 收據的 trip_id 必須與參數一致
    ///   - 傳入的統計對象必須對應同一輛車
    /// 評分與統計於同一筆交易原子更新，杜絕「未搭車卻評分」與「任意竄改統計」。
    public entry fun create_rating_proof(
        receipt: &TripReceipt,
        stats: &mut VehicleRatingStats,
        rating_id: u64,
        trip_id: u64,
        vehicle_id_hash: vector<u8>,
        rating: u8,
        content_hash: vector<u8>,
        content_blob_id: vector<u8>,
        ctx: &mut TxContext
    ) {
        let rater = tx_context::sender(ctx);

        // 1. 綁定行程：呼叫者必須是該行程乘客，且 trip_id 一致
        assert!(trip_receipt::passenger(receipt) == rater, ERR_NOT_TRIP_PASSENGER);
        assert!(trip_receipt::trip_id(receipt) == trip_id, ERR_TRIP_ID_MISMATCH);

        // 2. 統計對象須對應同一輛車
        assert!(stats.vehicle_id_hash == vehicle_id_hash, ERR_VEHICLE_MISMATCH);

        // 3. 驗證評分範圍與 hash 長度 (SHA256 = 32 bytes)
        assert!(rating >= 1 && rating <= 5, ERR_INVALID_RATING);
        assert!(std::vector::length(&content_hash) == 32, ERR_INVALID_HASH_LENGTH);

        let proof = RatingProof {
            id: object::new(ctx),
            rating_id,
            trip_id,
            vehicle_id_hash,
            rater,
            rating,
            content_hash,
            content_blob_id,
            created_at: tx_context::epoch(ctx),
        };

        let proof_id = object::uid_to_address(&proof.id);

        // 原子更新統計
        apply_rating_to_stats(stats, rating);

        // 發送事件
        event::emit(RatingProofCreated {
            proof_id,
            rating_id,
            trip_id,
            rater,
            rating,
            content_hash,
        });

        // 將存證轉移給評價者作為永久記錄
        transfer::transfer(proof, rater);
    }

    /// 創建車輛評價統計（每車一個，由平台以 RatingAdminCap 建立，避免任意重複建立）
    public entry fun create_vehicle_stats(
        _cap: &RatingAdminCap,
        vehicle_id_hash: vector<u8>,
        ctx: &mut TxContext
    ) {
        let stats = VehicleRatingStats {
            id: object::new(ctx),
            vehicle_id_hash,
            total_ratings: 0,
            total_score: 0,
            rating_1_count: 0,
            rating_2_count: 0,
            rating_3_count: 0,
            rating_4_count: 0,
            rating_5_count: 0,
        };

        // 共享對象，任何人都可以讀取
        transfer::share_object(stats);
    }

    /// 內部函式：把一筆評分計入統計。只能由 create_rating_proof 呼叫，
    /// 因此每次統計更新都必然對應一筆經行程驗證的評價。
    fun apply_rating_to_stats(stats: &mut VehicleRatingStats, rating: u8) {
        stats.total_ratings = stats.total_ratings + 1;
        stats.total_score = stats.total_score + (rating as u64);

        if (rating == 1) {
            stats.rating_1_count = stats.rating_1_count + 1;
        } else if (rating == 2) {
            stats.rating_2_count = stats.rating_2_count + 1;
        } else if (rating == 3) {
            stats.rating_3_count = stats.rating_3_count + 1;
        } else if (rating == 4) {
            stats.rating_4_count = stats.rating_4_count + 1;
        } else if (rating == 5) {
            stats.rating_5_count = stats.rating_5_count + 1;
        };
    }

    // ============================================================
    // 視圖函數
    // ============================================================

    /// 獲取評價存證資訊
    public fun get_proof_info(proof: &RatingProof): (u64, u64, address, u8, vector<u8>) {
        (
            proof.rating_id,
            proof.trip_id,
            proof.rater,
            proof.rating,
            proof.content_hash
        )
    }

    /// 獲取車輛統計資訊
    public fun get_stats_info(stats: &VehicleRatingStats): (u64, u64, u64, u64, u64, u64, u64) {
        (
            stats.total_ratings,
            stats.total_score,
            stats.rating_1_count,
            stats.rating_2_count,
            stats.rating_3_count,
            stats.rating_4_count,
            stats.rating_5_count
        )
    }

    /// 驗證評價 hash
    public fun verify_content_hash(
        proof: &RatingProof,
        expected_hash: vector<u8>
    ): bool {
        proof.content_hash == expected_hash
    }

    #[test_only]
    public fun new_admin_cap_for_testing(ctx: &mut TxContext): RatingAdminCap {
        RatingAdminCap { id: object::new(ctx) }
    }

    #[test_only]
    public fun destroy_admin_cap_for_testing(cap: RatingAdminCap) {
        let RatingAdminCap { id } = cap;
        object::delete(id);
    }
}
