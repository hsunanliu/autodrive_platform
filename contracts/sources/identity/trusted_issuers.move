/// Trusted Issuers Registry
/// 受信任的憑證簽發者註冊表
/// 管理哪些實體可以簽發 Verifiable Credentials
module autodrive::trusted_issuers {
    use std::string::{Self, String};
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::table::{Self, Table};
    use sui::event;
    use sui::clock::{Self, Clock};

    /// 錯誤碼
    const E_NOT_ADMIN: u64 = 1;
    const E_ISSUER_ALREADY_EXISTS: u64 = 2;
    const E_ISSUER_NOT_FOUND: u64 = 3;
    const E_ISSUER_REVOKED: u64 = 4;

    /// 憑證類型常量
    const CREDENTIAL_TYPE_AGE: vector<u8> = b"AgeCredential";
    const CREDENTIAL_TYPE_LICENSE: vector<u8> = b"DriverLicenseCredential";
    const CREDENTIAL_TYPE_REPUTATION: vector<u8> = b"ReputationCredential";

    /// 簽發者信息
    public struct IssuerInfo has store, drop, copy {
        /// 簽發者 DID
        issuer_did: String,
        /// 簽發者名稱
        name: String,
        /// 可簽發的憑證類型（序列化 JSON 數組）
        /// 例如：["AgeCredential", "DriverLicenseCredential"]
        credential_types: String,
        /// 簽發者地址
        issuer_address: address,
        /// 是否已撤銷
        revoked: bool,
        /// 添加時間戳
        added_at: u64,
        /// 最後更新時間
        updated_at: u64,
    }

    /// 受信任簽發者註冊表（全局單例）
    public struct TrustedIssuersRegistry has key {
        id: UID,
        /// 管理員地址（只有管理員可以添加/撤銷簽發者）
        admin: address,
        /// 簽發者列表（DID -> IssuerInfo）
        issuers: Table<String, IssuerInfo>,
        /// 簽發者數量
        total_issuers: u64,
        /// 活躍簽發者數量
        active_issuers: u64,
    }

    /// 簽發者添加事件
    public struct IssuerAdded has copy, drop {
        issuer_did: String,
        name: String,
        issuer_address: address,
        added_at: u64,
    }

    /// 簽發者撤銷事件
    public struct IssuerRevoked has copy, drop {
        issuer_did: String,
        revoked_at: u64,
    }

    /// 簽發者更新事件
    public struct IssuerUpdated has copy, drop {
        issuer_did: String,
        updated_at: u64,
    }

    /// 管理員變更事件
    public struct AdminChanged has copy, drop {
        old_admin: address,
        new_admin: address,
        changed_at: u64,
    }

    /// 初始化函數（只執行一次）
    fun init(ctx: &mut TxContext) {
        let registry = TrustedIssuersRegistry {
            id: object::new(ctx),
            admin: tx_context::sender(ctx),
            issuers: table::new(ctx),
            total_issuers: 0,
            active_issuers: 0,
        };
        transfer::share_object(registry);
    }

    /// 添加受信任簽發者
    /// 只有管理員可以調用
    public entry fun add_issuer(
        registry: &mut TrustedIssuersRegistry,
        issuer_did: String,
        name: String,
        credential_types: String,
        issuer_address: address,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // 1. 檢查調用者是否為管理員
        let sender = tx_context::sender(ctx);
        assert!(sender == registry.admin, E_NOT_ADMIN);

        // 2. 檢查簽發者是否已存在
        assert!(
            !table::contains(&registry.issuers, issuer_did),
            E_ISSUER_ALREADY_EXISTS
        );

        // 3. 創建簽發者信息
        let timestamp = clock::timestamp_ms(clock);
        let issuer_info = IssuerInfo {
            issuer_did,
            name,
            credential_types,
            issuer_address,
            revoked: false,
            added_at: timestamp,
            updated_at: timestamp,
        };

        // 4. 添加到註冊表
        table::add(&mut registry.issuers, issuer_did, issuer_info);

        // 5. 更新統計
        registry.total_issuers = registry.total_issuers + 1;
        registry.active_issuers = registry.active_issuers + 1;

        // 6. 發出事件
        event::emit(IssuerAdded {
            issuer_did,
            name,
            issuer_address,
            added_at: timestamp,
        });
    }

    /// 撤銷簽發者
    /// 只有管理員可以調用
    public entry fun revoke_issuer(
        registry: &mut TrustedIssuersRegistry,
        issuer_did: String,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // 1. 檢查調用者是否為管理員
        let sender = tx_context::sender(ctx);
        assert!(sender == registry.admin, E_NOT_ADMIN);

        // 2. 檢查簽發者是否存在
        assert!(
            table::contains(&registry.issuers, issuer_did),
            E_ISSUER_NOT_FOUND
        );

        // 3. 獲取並更新簽發者信息
        let issuer_info = table::borrow_mut(&mut registry.issuers, issuer_did);
        assert!(!issuer_info.revoked, E_ISSUER_REVOKED);

        let timestamp = clock::timestamp_ms(clock);
        issuer_info.revoked = true;
        issuer_info.updated_at = timestamp;

        // 4. 更新統計
        registry.active_issuers = registry.active_issuers - 1;

        // 5. 發出事件
        event::emit(IssuerRevoked {
            issuer_did,
            revoked_at: timestamp,
        });
    }

    /// 更新簽發者信息
    /// 只有管理員可以調用
    public entry fun update_issuer(
        registry: &mut TrustedIssuersRegistry,
        issuer_did: String,
        name: String,
        credential_types: String,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // 1. 檢查調用者是否為管理員
        let sender = tx_context::sender(ctx);
        assert!(sender == registry.admin, E_NOT_ADMIN);

        // 2. 檢查簽發者是否存在
        assert!(
            table::contains(&registry.issuers, issuer_did),
            E_ISSUER_NOT_FOUND
        );

        // 3. 更新簽發者信息
        let issuer_info = table::borrow_mut(&mut registry.issuers, issuer_did);
        issuer_info.name = name;
        issuer_info.credential_types = credential_types;
        issuer_info.updated_at = clock::timestamp_ms(clock);

        // 4. 發出事件
        event::emit(IssuerUpdated {
            issuer_did,
            updated_at: issuer_info.updated_at,
        });
    }

    /// 變更管理員
    /// 只有當前管理員可以調用
    public entry fun change_admin(
        registry: &mut TrustedIssuersRegistry,
        new_admin: address,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // 1. 檢查調用者是否為管理員
        let sender = tx_context::sender(ctx);
        assert!(sender == registry.admin, E_NOT_ADMIN);

        // 2. 變更管理員
        let old_admin = registry.admin;
        registry.admin = new_admin;

        // 3. 發出事件
        event::emit(AdminChanged {
            old_admin,
            new_admin,
            changed_at: clock::timestamp_ms(clock),
        });
    }

    /// 檢查簽發者是否受信任且未撤銷
    public fun is_trusted_issuer(
        registry: &TrustedIssuersRegistry,
        issuer_did: String
    ): bool {
        if (!table::contains(&registry.issuers, issuer_did)) {
            return false
        };

        let issuer_info = table::borrow(&registry.issuers, issuer_did);
        !issuer_info.revoked
    }

    /// 檢查簽發者是否可以簽發特定類型的憑證
    public fun can_issue_credential_type(
        registry: &TrustedIssuersRegistry,
        issuer_did: String,
        credential_type: String
    ): bool {
        if (!table::contains(&registry.issuers, issuer_did)) {
            return false
        };

        let issuer_info = table::borrow(&registry.issuers, issuer_did);
        if (issuer_info.revoked) {
            return false
        };

        // 檢查憑證類型是否在允許的列表中
        // 簡化實現：檢查 credential_types 字符串是否包含目標類型
        // 實際應該解析 JSON 數組進行檢查
        let types_str = string::bytes(&issuer_info.credential_types);
        let target_str = string::bytes(&credential_type);

        // 簡單的字符串包含檢查（實際應該更嚴格）
        contains_substring(types_str, target_str)
    }

    /// 獲取簽發者信息
    public fun get_issuer_info(
        registry: &TrustedIssuersRegistry,
        issuer_did: String
    ): (String, String, address, bool, u64, u64) {
        assert!(
            table::contains(&registry.issuers, issuer_did),
            E_ISSUER_NOT_FOUND
        );

        let issuer_info = table::borrow(&registry.issuers, issuer_did);
        (
            issuer_info.name,
            issuer_info.credential_types,
            issuer_info.issuer_address,
            issuer_info.revoked,
            issuer_info.added_at,
            issuer_info.updated_at
        )
    }

    /// 獲取管理員地址
    public fun get_admin(registry: &TrustedIssuersRegistry): address {
        registry.admin
    }

    /// 獲取註冊表統計信息
    public fun get_stats(registry: &TrustedIssuersRegistry): (u64, u64) {
        (registry.total_issuers, registry.active_issuers)
    }

    /// 輔助函數：檢查字符串是否包含子字符串
    fun contains_substring(haystack: &vector<u8>, needle: &vector<u8>): bool {
        let haystack_len = std::vector::length(haystack);
        let needle_len = std::vector::length(needle);

        if (needle_len > haystack_len) {
            return false
        };

        let mut i = 0;
        while (i <= haystack_len - needle_len) {
            let mut j = 0;
            let mut found = true;
            while (j < needle_len) {
                if (*std::vector::borrow(haystack, i + j) != *std::vector::borrow(needle, j)) {
                    found = false;
                    break
                };
                j = j + 1;
            };
            if (found) {
                return true
            };
            i = i + 1;
        };
        false
    }

    #[test_only]
    /// 測試用的初始化函數
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}
