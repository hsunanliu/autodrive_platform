/// DID Registry
/// 去中心化身份標識符註冊表
/// 符合 W3C DID Core 1.0 規範
module autodrive::did_registry {
    use std::string::{Self, String};
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::dynamic_field;
    use sui::event;
    use sui::clock::{Self, Clock};
    use sui::address;

    /// 錯誤碼
    const E_DID_ALREADY_EXISTS: u64 = 1;
    const E_DID_NOT_FOUND: u64 = 2;
    const E_NOT_CONTROLLER: u64 = 3;
    const E_DID_DEACTIVATED: u64 = 4;
    const E_INVALID_DID_FORMAT: u64 = 5;
    const E_INVALID_VERIFICATION_METHOD: u64 = 6;

    /// DID 文檔結構（鏈上存儲）
    /// 符合 W3C DID Core 1.0 標準
    public struct DIDDocument has key, store {
        id: UID,
        /// DID 字符串（例如：did:sui:0x1a2b...）
        did: String,
        /// 控制者地址（可以是自己或其他 DID）
        controller: address,
        /// 驗證方法（序列化 JSON 字符串）
        /// 格式：[{"id": "did:sui:0x...#key-1", "type": "Ed25519VerificationKey2020", "publicKeyHex": "..."}]
        verification_methods: String,
        /// 認證方法引用（序列化 JSON 數組）
        authentication: String,
        /// 斷言方法引用（序列化 JSON 數組）
        assertion_method: String,
        /// 創建時間戳（毫秒）
        created_at: u64,
        /// 更新時間戳（毫秒）
        updated_at: u64,
        /// 是否已停用
        deactivated: bool,
    }

    /// DID 註冊表（全局單例）
    public struct DIDRegistry has key {
        id: UID,
        /// 已註冊的 DID 數量
        total_dids: u64,
        /// 活躍的 DID 數量
        active_dids: u64,
    }

    /// DID 註冊事件
    public struct DIDRegistered has copy, drop {
        did: String,
        controller: address,
        created_at: u64,
    }

    /// DID 更新事件
    public struct DIDUpdated has copy, drop {
        did: String,
        updated_at: u64,
    }

    /// DID 停用事件
    public struct DIDDeactivated has copy, drop {
        did: String,
        deactivated_at: u64,
    }

    /// 初始化函數（只執行一次）
    fun init(ctx: &mut TxContext) {
        let registry = DIDRegistry {
            id: object::new(ctx),
            total_dids: 0,
            active_dids: 0,
        };
        transfer::share_object(registry);
    }

    /// 註冊新的 DID
    /// @param did DID 字符串（例如：did:sui:0x1a2b...）
    /// @param verification_methods 驗證方法 JSON 字符串
    /// @param authentication 認證方法 JSON 數組
    /// @param assertion_method 斷言方法 JSON 數組
    public entry fun register_did(
        registry: &mut DIDRegistry,
        did: String,
        verification_methods: String,
        authentication: String,
        assertion_method: String,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // 1. 驗證 DID 格式（必須是 did:sui:<address> 且 address 匹配調用者）
        let controller = tx_context::sender(ctx);
        validate_did_format(&did, controller);

        // 2. 檢查 DID 是否已存在
        assert!(
            !dynamic_field::exists_(&registry.id, did),
            E_DID_ALREADY_EXISTS
        );

        // 3. 創建 DID 文檔
        let timestamp = clock::timestamp_ms(clock);
        let did_doc = DIDDocument {
            id: object::new(ctx),
            did,
            controller,
            verification_methods,
            authentication,
            assertion_method,
            created_at: timestamp,
            updated_at: timestamp,
            deactivated: false,
        };

        // 4. 存儲到註冊表（使用 dynamic field）
        dynamic_field::add(&mut registry.id, did, did_doc);

        // 5. 更新統計
        registry.total_dids = registry.total_dids + 1;
        registry.active_dids = registry.active_dids + 1;

        // 6. 發出事件
        event::emit(DIDRegistered {
            did,
            controller,
            created_at: timestamp,
        });
    }

    /// 更新 DID 文檔
    /// 只有控制者可以更新
    public entry fun update_did(
        registry: &mut DIDRegistry,
        did: String,
        verification_methods: String,
        authentication: String,
        assertion_method: String,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // 0. 先確認存在（否則 borrow_mut 會拋出泛用的 dynamic field 錯誤）
        assert!(dynamic_field::exists_(&registry.id, did), E_DID_NOT_FOUND);

        // 1. 獲取 DID 文檔
        let did_doc = dynamic_field::borrow_mut<String, DIDDocument>(&mut registry.id, did);

        // 2. 檢查是否已停用
        assert!(!did_doc.deactivated, E_DID_DEACTIVATED);

        // 3. 驗證調用者是控制者
        let sender = tx_context::sender(ctx);
        assert!(sender == did_doc.controller, E_NOT_CONTROLLER);

        // 4. 更新文檔
        did_doc.verification_methods = verification_methods;
        did_doc.authentication = authentication;
        did_doc.assertion_method = assertion_method;
        did_doc.updated_at = clock::timestamp_ms(clock);

        // 5. 發出事件
        event::emit(DIDUpdated {
            did,
            updated_at: did_doc.updated_at,
        });
    }

    /// 停用 DID
    /// 只有控制者可以停用
    public entry fun deactivate_did(
        registry: &mut DIDRegistry,
        did: String,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // 0. 先確認存在（否則 borrow_mut 會拋出泛用的 dynamic field 錯誤）
        assert!(dynamic_field::exists_(&registry.id, did), E_DID_NOT_FOUND);

        // 1. 獲取 DID 文檔
        let did_doc = dynamic_field::borrow_mut<String, DIDDocument>(&mut registry.id, did);

        // 2. 檢查是否已停用
        assert!(!did_doc.deactivated, E_DID_DEACTIVATED);

        // 3. 驗證調用者是控制者
        let sender = tx_context::sender(ctx);
        assert!(sender == did_doc.controller, E_NOT_CONTROLLER);

        // 4. 停用
        did_doc.deactivated = true;
        did_doc.updated_at = clock::timestamp_ms(clock);

        // 5. 更新統計（此處 active_dids 必 > 0：每個未停用的 DID 都曾 +1，
        //    且上面的 deactivated 檢查確保不會對同一 DID 重複扣減）
        registry.active_dids = registry.active_dids - 1;

        // 6. 發出事件
        event::emit(DIDDeactivated {
            did,
            deactivated_at: did_doc.updated_at,
        });
    }

    /// 解析 DID（查詢視圖函數）
    /// 返回 DID 文檔的各個字段
    public fun resolve_did(
        registry: &DIDRegistry,
        did: String
    ): (String, address, String, String, String, u64, u64, bool) {
        // 檢查 DID 是否存在
        assert!(
            dynamic_field::exists_(&registry.id, did),
            E_DID_NOT_FOUND
        );

        let did_doc = dynamic_field::borrow<String, DIDDocument>(&registry.id, did);

        (
            did_doc.did,
            did_doc.controller,
            did_doc.verification_methods,
            did_doc.authentication,
            did_doc.assertion_method,
            did_doc.created_at,
            did_doc.updated_at,
            did_doc.deactivated
        )
    }

    /// 檢查 DID 是否存在
    public fun did_exists(registry: &DIDRegistry, did: String): bool {
        dynamic_field::exists_(&registry.id, did)
    }

    /// 獲取 DID 控制者地址
    public fun get_controller(registry: &DIDRegistry, did: String): address {
        assert!(
            dynamic_field::exists_(&registry.id, did),
            E_DID_NOT_FOUND
        );
        let did_doc = dynamic_field::borrow<String, DIDDocument>(&registry.id, did);
        did_doc.controller
    }

    /// 檢查 DID 是否已停用
    public fun is_deactivated(registry: &DIDRegistry, did: String): bool {
        assert!(
            dynamic_field::exists_(&registry.id, did),
            E_DID_NOT_FOUND
        );
        let did_doc = dynamic_field::borrow<String, DIDDocument>(&registry.id, did);
        did_doc.deactivated
    }

    /// 獲取註冊表統計信息
    public fun get_stats(registry: &DIDRegistry): (u64, u64) {
        (registry.total_dids, registry.active_dids)
    }

    /// 驗證 DID 格式並綁定控制者。
    /// 規範格式：`did:sui:0x<64 位小寫 hex>`，且 hex 部分必須等於 controller（= 交易發起者）。
    /// 這可防止使用者註冊 `did:sui:0x<別人的位址>` 卻由自己控制的冒名 DID。
    fun validate_did_format(did: &String, controller: address) {
        let did_bytes = string::as_bytes(did);
        // "did:sui:0x" 前綴 10 bytes + 64 hex = 74
        let prefix = b"did:sui:0x";
        let prefix_len = 10;
        assert!(std::vector::length(did_bytes) == prefix_len + 64, E_INVALID_DID_FORMAT);

        // 1. 檢查前綴
        let mut i = 0;
        while (i < prefix_len) {
            assert!(
                *std::vector::borrow(did_bytes, i) == *std::vector::borrow(&prefix, i),
                E_INVALID_DID_FORMAT
            );
            i = i + 1;
        };

        // 2. 位址部分必須逐字元等於 controller 的 canonical hex（64 位小寫、補零）
        let addr_str = address::to_string(controller);
        let addr_hex = string::as_bytes(&addr_str);
        let mut j = 0;
        while (j < 64) {
            assert!(
                *std::vector::borrow(did_bytes, prefix_len + j) == *std::vector::borrow(addr_hex, j),
                E_INVALID_DID_FORMAT
            );
            j = j + 1;
        };
    }

    #[test_only]
    /// 測試用的初始化函數
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}
