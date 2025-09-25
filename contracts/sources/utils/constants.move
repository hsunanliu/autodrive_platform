module decentralized_ride::constants {
    // ============================================================================
    // 系統級常數 (System Constants)
    // ============================================================================
    
    /// 系統版本
    const SYSTEM_VERSION: u64 = 1;
    
    /// 基礎費率設定
    const BASE_FARE: u64 = 5000000000000000;        // 0.005 IOTA
    const PER_KM_RATE: u64 = 2000000000000000;      // 0.002 IOTA per km
    const PER_MINUTE_RATE: u64 = 500000000000000;   // 0.0005 IOTA per minute
    
    /// 時間相關常數 (秒)
    const RIDE_REQUEST_TIMEOUT: u64 = 300;          // 5分鐘
    const DRIVER_OFFER_TIMEOUT: u64 = 180;          // 3分鐘
    const PICKUP_TIMEOUT: u64 = 900;                // 15分鐘
    
    /// 信譽系統
    const DEFAULT_REPUTATION: u64 = 500;            // 預設信譽分數
    const MIN_DRIVER_REPUTATION: u64 = 300;         // 最低司機信譽要求
    const MAX_REPUTATION: u64 = 1000;               // 最高信譽分數
    
    /// 評分系統
    const MIN_RATING: u8 = 1;                       // 最低評分
    const MAX_RATING: u8 = 5;                       // 最高評分
    
    /// 狀態常數 - 用戶
    const USER_STATUS_ACTIVE: u8 = 0;               // 活躍
    const USER_STATUS_SUSPENDED: u8 = 1;            // 暫停
    const USER_STATUS_BANNED: u8 = 2;               // 封禁
    
    /// 狀態常數 - 車輛
    const VEHICLE_STATUS_OFFLINE: u8 = 0;           // 離線
    const VEHICLE_STATUS_AVAILABLE: u8 = 1;         // 可用
    const VEHICLE_STATUS_BUSY: u8 = 2;              // 使用中
    
    /// 狀態常數 - 行程
    const RIDE_STATUS_PENDING: u8 = 0;              // 等待中
    const RIDE_STATUS_MATCHED: u8 = 1;              // 已配對
    const RIDE_STATUS_ACTIVE: u8 = 2;               // 進行中  
    const RIDE_STATUS_COMPLETED: u8 = 3;            // 已完成
    const RIDE_STATUS_CANCELLED: u8 = 4;            // 已取消
    const RIDE_STATUS_DISPUTED: u8 = 5;             // 糾紛中
    
    /// 車輛等級
    const VEHICLE_CLASS_ECONOMY: u8 = 0;            // 經濟型
    const VEHICLE_CLASS_COMFORT: u8 = 1;            // 舒適型
    const VEHICLE_CLASS_PREMIUM: u8 = 2;            // 豪華型
    
    /// 平台手續費 (基點，10000 = 100%)
    const PLATFORM_FEE_RATE: u64 = 250;             // 2.5%
    const BASIS_POINTS_DENOMINATOR: u64 = 10000;    // 基點分母
    
    // ============================================================================
    // 統一錯誤碼系統 (Unified Error Codes)
    // ============================================================================
    
    /// 系統級錯誤 (1000-1999)
    const E_UNAUTHORIZED: u64 = 1001;               // 無權限
    const E_INVALID_DATA_FORMAT: u64 = 1002;        // 資料格式錯誤
    const E_SERVICE_SUSPENDED: u64 = 1003;          // 服務暫停
    const E_INSUFFICIENT_FUNDS: u64 = 1004;         // 資金不足
    const E_OPERATION_TIMEOUT: u64 = 1005;          // 操作逾時
    const E_DUPLICATE_OPERATION: u64 = 1006;        // 重複操作
    const E_INVALID_STATUS: u64 = 1007;             // 狀態錯誤
    
    /// 用戶相關錯誤 (2000-2099)
    const E_USER_NOT_FOUND: u64 = 2001;             // 用戶不存在
    const E_USER_SUSPENDED: u64 = 2002;             // 用戶被暫停
    const E_INVALID_REPUTATION: u64 = 2003;         // 信譽分數無效
    const E_INVALID_RATING: u64 = 2004;             // 評分無效
    
    /// 車輛相關錯誤 (2100-2199)
    const E_VEHICLE_NOT_FOUND: u64 = 2101;          // 車輛不存在
    const E_VEHICLE_NOT_VERIFIED: u64 = 2102;       // 車輛未驗證
    const E_VEHICLE_NOT_AVAILABLE: u64 = 2103;      // 車輛不可用
    const E_NOT_VEHICLE_OWNER: u64 = 2104;          // 非車輛所有者
    const E_INVALID_VEHICLE_STATUS: u64 = 2105;     // 車輛狀態無效
    
    /// 配對相關錯誤 (2200-2299)
    const E_RIDE_NOT_FOUND: u64 = 2201;             // 行程不存在
    const E_INVALID_RIDE_STATUS: u64 = 2202;        // 行程狀態無效
    const E_PRICE_MISMATCH: u64 = 2203;             // 價格不匹配
    const E_REQUEST_EXPIRED: u64 = 2204;            // 請求已過期
    const E_ALREADY_MATCHED: u64 = 2205;            // 已配對
    const E_REPUTATION_TOO_LOW: u64 = 2206;         // 信譽太低
    
    // ============================================================================
    // Getter 函數 (Public Access Functions)
    // ============================================================================
    
    // 系統參數
    public fun system_version(): u64 { SYSTEM_VERSION }
    public fun base_fare(): u64 { BASE_FARE }
    public fun per_km_rate(): u64 { PER_KM_RATE }
    public fun per_minute_rate(): u64 { PER_MINUTE_RATE }
    public fun platform_fee_rate(): u64 { PLATFORM_FEE_RATE }
    public fun basis_points_denominator(): u64 { BASIS_POINTS_DENOMINATOR }
    
    // 時間設定
    public fun ride_request_timeout(): u64 { RIDE_REQUEST_TIMEOUT }
    public fun driver_offer_timeout(): u64 { DRIVER_OFFER_TIMEOUT }
    public fun pickup_timeout(): u64 { PICKUP_TIMEOUT }
    
    // 信譽系統
    public fun default_reputation(): u64 { DEFAULT_REPUTATION }
    public fun min_driver_reputation(): u64 { MIN_DRIVER_REPUTATION }
    public fun max_reputation(): u64 { MAX_REPUTATION }
    
    // 評分系統
    public fun min_rating(): u8 { MIN_RATING }
    public fun max_rating(): u8 { MAX_RATING }
    
    // 用戶狀態
    public fun user_status_active(): u8 { USER_STATUS_ACTIVE }
    public fun user_status_suspended(): u8 { USER_STATUS_SUSPENDED }
    public fun user_status_banned(): u8 { USER_STATUS_BANNED }
    
    // 車輛狀態
    public fun vehicle_status_offline(): u8 { VEHICLE_STATUS_OFFLINE }
    public fun vehicle_status_available(): u8 { VEHICLE_STATUS_AVAILABLE }
    public fun vehicle_status_busy(): u8 { VEHICLE_STATUS_BUSY }
    
    // 行程狀態
    public fun ride_status_pending(): u8 { RIDE_STATUS_PENDING }
    public fun ride_status_matched(): u8 { RIDE_STATUS_MATCHED }
    public fun ride_status_active(): u8 { RIDE_STATUS_ACTIVE }
    public fun ride_status_completed(): u8 { RIDE_STATUS_COMPLETED }
    public fun ride_status_cancelled(): u8 { RIDE_STATUS_CANCELLED }
    public fun ride_status_disputed(): u8 { RIDE_STATUS_DISPUTED }
    
    // 車輛等級
    public fun vehicle_class_economy(): u8 { VEHICLE_CLASS_ECONOMY }
    public fun vehicle_class_comfort(): u8 { VEHICLE_CLASS_COMFORT }
    public fun vehicle_class_premium(): u8 { VEHICLE_CLASS_PREMIUM }
    
    // 錯誤碼 getter
    public fun e_unauthorized(): u64 { E_UNAUTHORIZED }
    public fun e_invalid_data_format(): u64 { E_INVALID_DATA_FORMAT }
    public fun e_service_suspended(): u64 { E_SERVICE_SUSPENDED }
    public fun e_insufficient_funds(): u64 { E_INSUFFICIENT_FUNDS }
    public fun e_operation_timeout(): u64 { E_OPERATION_TIMEOUT }
    public fun e_duplicate_operation(): u64 { E_DUPLICATE_OPERATION }
    public fun e_invalid_status(): u64 { E_INVALID_STATUS }
    
    public fun e_user_not_found(): u64 { E_USER_NOT_FOUND }
    public fun e_user_suspended(): u64 { E_USER_SUSPENDED }
    public fun e_invalid_reputation(): u64 { E_INVALID_REPUTATION }
    public fun e_invalid_rating(): u64 { E_INVALID_RATING }
    
    public fun e_vehicle_not_found(): u64 { E_VEHICLE_NOT_FOUND }
    public fun e_vehicle_not_verified(): u64 { E_VEHICLE_NOT_VERIFIED }
    public fun e_vehicle_not_available(): u64 { E_VEHICLE_NOT_AVAILABLE }
    public fun e_not_vehicle_owner(): u64 { E_NOT_VEHICLE_OWNER }
    public fun e_invalid_vehicle_status(): u64 { E_INVALID_VEHICLE_STATUS }
    
    public fun e_ride_not_found(): u64 { E_RIDE_NOT_FOUND }
    public fun e_invalid_ride_status(): u64 { E_INVALID_RIDE_STATUS }
    public fun e_price_mismatch(): u64 { E_PRICE_MISMATCH }
    public fun e_request_expired(): u64 { E_REQUEST_EXPIRED }
    public fun e_already_matched(): u64 { E_ALREADY_MATCHED }
    public fun e_reputation_too_low(): u64 { E_REPUTATION_TOO_LOW }
    
    // ============================================================================
    // 驗證函數 (Validation Functions)
    // ============================================================================
    
    public fun is_valid_user_status(status: u8): bool {
        status == USER_STATUS_ACTIVE || 
        status == USER_STATUS_SUSPENDED || 
        status == USER_STATUS_BANNED
    }
    
    public fun is_valid_vehicle_status(status: u8): bool {
        status == VEHICLE_STATUS_OFFLINE || 
        status == VEHICLE_STATUS_AVAILABLE || 
        status == VEHICLE_STATUS_BUSY
    }
    
    public fun is_valid_ride_status(status: u8): bool {
        status == RIDE_STATUS_PENDING || 
        status == RIDE_STATUS_MATCHED || 
        status == RIDE_STATUS_ACTIVE || 
        status == RIDE_STATUS_COMPLETED || 
        status == RIDE_STATUS_CANCELLED || 
        status == RIDE_STATUS_DISPUTED
    }
    
    public fun is_valid_rating(rating: u8): bool {
        rating >= MIN_RATING && rating <= MAX_RATING
    }
    
    public fun is_valid_reputation(reputation: u64): bool {
        reputation <= MAX_REPUTATION
    }
    
    public fun is_valid_vehicle_class(class: u8): bool {
        class == VEHICLE_CLASS_ECONOMY || 
        class == VEHICLE_CLASS_COMFORT || 
        class == VEHICLE_CLASS_PREMIUM
    }
}
