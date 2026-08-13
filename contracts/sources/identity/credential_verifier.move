/// Credential Verifier with ZKP
/// 憑證驗證器（零知識證明）
/// 驗證 Verifiable Credentials 的 ZKP 證明，無需揭露原始數據
module autodrive::credential_verifier {
    use std::string::{Self, String};
    use std::vector;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::table::{Self, Table};
    use sui::event;
    use sui::clock::{Self, Clock};
    use sui::groth16;
    use autodrive::trusted_issuers::{Self, TrustedIssuersRegistry};
    use autodrive::did_registry::{Self, DIDRegistry};
    use autodrive::profile::{Self, PassengerProfile, DriverProfile};

    /// 錯誤碼
    const E_INVALID_PROOF: u64 = 1;
    const E_ISSUER_NOT_TRUSTED: u64 = 2;
    const E_CREDENTIAL_EXPIRED: u64 = 3;
    const E_COMMITMENT_ALREADY_USED: u64 = 4;
    const E_DID_NOT_FOUND: u64 = 5;
    const E_INVALID_PUBLIC_SIGNALS: u64 = 6;
    const E_NOT_PROFILE_OWNER: u64 = 7;

    /// 憑證類型
    const CREDENTIAL_TYPE_AGE: u64 = 1;
    const CREDENTIAL_TYPE_LICENSE: u64 = 2;
    const CREDENTIAL_TYPE_REPUTATION: u64 = 3;

    /// 驗證密鑰（用於驗證 ZKP）
    /// 存儲完整的 Groth16 驗證密鑰（Arkworks canonical compressed 序列化），
    /// 供 sui::groth16::prepare_verifying_key 使用。
    public struct VerificationKey has key, store {
        id: UID,
        /// 憑證類型（此 vk 只能驗證此類型的憑證）
        credential_type: u64,
        /// 完整驗證密鑰 bytes（Arkworks 壓縮序列化，bn254 曲線）
        vk_bytes: vector<u8>,
        /// 創建時間
        created_at: u64,
    }

    /// 憑證系統管理權（部署時發給平台，用於註冊驗證密鑰）
    public struct CredentialAdminCap has key, store {
        id: UID,
    }

    /// 憑證註冊表（防止憑證重複使用）
    public struct CredentialRegistry has key {
        id: UID,
        /// 已使用的承諾值（commitment -> true）
        /// 防止同一憑證被多次使用
        used_commitments: Table<vector<u8>, bool>,
        /// 用戶 DID -> 憑證類型 -> 驗證時間戳
        user_credentials: Table<String, Table<u64, u64>>,
        /// 總驗證次數
        total_verifications: u64,
    }

    /// 憑證驗證成功事件
    public struct CredentialVerified has copy, drop {
        user_did: String,
        credential_type: u64,
        issuer_did: String,
        verified_at: u64,
        commitment: vector<u8>,
    }

    /// 初始化函數
    fun init(ctx: &mut TxContext) {
        let registry = CredentialRegistry {
            id: object::new(ctx),
            used_commitments: table::new(ctx),
            user_credentials: table::new(ctx),
            total_verifications: 0,
        };
        transfer::share_object(registry);

        // 發行管理權給部署者，用於註冊驗證密鑰
        transfer::transfer(
            CredentialAdminCap { id: object::new(ctx) },
            tx_context::sender(ctx)
        );
    }

    /// 註冊驗證密鑰（僅平台以 CredentialAdminCap 可呼叫）
    /// 用於驗證特定類型憑證的 ZKP。vk_bytes 是 bn254 曲線的 Arkworks 壓縮序列化驗證密鑰。
    public entry fun register_verification_key(
        _cap: &CredentialAdminCap,
        credential_type: u64,
        vk_bytes: vector<u8>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let vk = VerificationKey {
            id: object::new(ctx),
            credential_type,
            vk_bytes,
            created_at: clock::timestamp_ms(clock),
        };
        transfer::share_object(vk);
    }

    /// 驗證年齡憑證 ZKP
    /// 證明用戶年齡 >= 18 歲，而不揭露實際出生日期
    ///
    /// @param user_did 用戶 DID
    /// @param issuer_did 簽發者 DID（例如：政府機關）
    /// @param proof ZKP 證明（Groth16 格式）
    /// @param public_signals 公開信號 [isValid, didCommitment, currentDate, minAge]
    /// @param commitment 憑證承諾值（防止重複使用）
    public entry fun verify_age_credential(
        registry: &mut CredentialRegistry,
        did_registry: &DIDRegistry,
        trusted_issuers: &TrustedIssuersRegistry,
        vk: &VerificationKey,
        profile: &mut PassengerProfile,
        user_did: String,
        issuer_did: String,
        proof: vector<u8>,
        public_inputs: vector<u8>,
        commitment: vector<u8>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // 0. Profile 必須屬於發起者本人（owned 物件，發起者即擁有者）
        assert!(profile::passenger_owner(profile) == tx_context::sender(ctx), E_NOT_PROFILE_OWNER);

        // 1. 驗證用戶 DID 存在且未停用
        assert!(
            did_registry::did_exists(did_registry, user_did),
            E_DID_NOT_FOUND
        );
        assert!(
            !did_registry::is_deactivated(did_registry, user_did),
            E_DID_NOT_FOUND
        );

        // 2. 驗證簽發者是否受信任
        assert!(
            trusted_issuers::is_trusted_issuer(trusted_issuers, issuer_did),
            E_ISSUER_NOT_TRUSTED
        );

        // 3. 驗證憑證承諾值未被使用過（防止雙花）
        assert!(
            !table::contains(&registry.used_commitments, commitment),
            E_COMMITMENT_ALREADY_USED
        );

        // 4. 以 sui::groth16 對已註冊的驗證密鑰做真正的 Groth16 驗證。
        //    proof 為 Arkworks 序列化的三個證明點；public_inputs 為 32-byte-per-scalar 的
        //    公開輸入 blob。驗證失敗即 abort，無法再用「任意非空 proof」蒙混。
        verify_groth16_proof(vk, CREDENTIAL_TYPE_AGE, proof, public_inputs);

        // 6. 標記承諾值為已使用
        table::add(&mut registry.used_commitments, commitment, true);

        // 7. 記錄用戶憑證
        let timestamp = clock::timestamp_ms(clock);
        if (!table::contains(&registry.user_credentials, user_did)) {
            table::add(
                &mut registry.user_credentials,
                user_did,
                table::new(ctx)
            );
        };
        let user_creds = table::borrow_mut(&mut registry.user_credentials, user_did);
        table::add(user_creds, CREDENTIAL_TYPE_AGE, timestamp);

        // 8. 更新統計
        registry.total_verifications = registry.total_verifications + 1;

        // 8b. 在使用者自己的（soulbound）Profile 設定 is_adult=true（只存 boolean + commitment）
        profile::set_passenger_adult(profile, commitment, timestamp);

        // 9. 發出事件
        event::emit(CredentialVerified {
            user_did,
            credential_type: CREDENTIAL_TYPE_AGE,
            issuer_did,
            verified_at: timestamp,
            commitment,
        });
    }

    /// 驗證駕照憑證 ZKP
    /// 證明用戶持有有效駕照，而不揭露駕照號碼
    public entry fun verify_license_credential(
        registry: &mut CredentialRegistry,
        did_registry: &DIDRegistry,
        trusted_issuers: &TrustedIssuersRegistry,
        vk: &VerificationKey,
        profile: &mut DriverProfile,
        user_did: String,
        issuer_did: String,
        proof: vector<u8>,
        public_inputs: vector<u8>,
        commitment: vector<u8>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // 0. Profile 必須屬於發起者本人
        assert!(profile::driver_owner(profile) == tx_context::sender(ctx), E_NOT_PROFILE_OWNER);

        // 1. 驗證用戶 DID 存在且未停用（原本漏了 is_deactivated 檢查）
        assert!(
            did_registry::did_exists(did_registry, user_did),
            E_DID_NOT_FOUND
        );
        assert!(
            !did_registry::is_deactivated(did_registry, user_did),
            E_DID_NOT_FOUND
        );

        // 2. 驗證簽發者
        assert!(
            trusted_issuers::is_trusted_issuer(trusted_issuers, issuer_did),
            E_ISSUER_NOT_TRUSTED
        );

        // 3. 防止重複使用
        assert!(
            !table::contains(&registry.used_commitments, commitment),
            E_COMMITMENT_ALREADY_USED
        );

        // 4. 以 sui::groth16 做真正的 Groth16 驗證
        verify_groth16_proof(vk, CREDENTIAL_TYPE_LICENSE, proof, public_inputs);

        // 6. 記錄
        table::add(&mut registry.used_commitments, commitment, true);
        let timestamp = clock::timestamp_ms(clock);

        if (!table::contains(&registry.user_credentials, user_did)) {
            table::add(
                &mut registry.user_credentials,
                user_did,
                table::new(ctx)
            );
        };
        let user_creds = table::borrow_mut(&mut registry.user_credentials, user_did);
        table::add(user_creds, CREDENTIAL_TYPE_LICENSE, timestamp);

        registry.total_verifications = registry.total_verifications + 1;

        // 在司機 Profile 設定 has_valid_license=true（只存 boolean + commitment）
        profile::set_driver_license(profile, commitment, timestamp);

        event::emit(CredentialVerified {
            user_did,
            credential_type: CREDENTIAL_TYPE_LICENSE,
            issuer_did,
            verified_at: timestamp,
            commitment,
        });
    }

    /// 驗證 Groth16 ZKP 證明（bn254 曲線）
    /// 使用 Sui 原生 `sui::groth16` 預編譯，做真正的配對驗證：
    ///   e(A, B) = e(α, β) · e(L, γ) · e(C, δ)
    /// （先前 Sui 不支援配對的說法已過時——sui::groth16 提供 bn254/bls12381 原生驗證。）
    fun verify_groth16_proof(
        vk: &VerificationKey,
        expected_type: u64,
        proof: vector<u8>,
        public_inputs: vector<u8>
    ) {
        // 1. 驗證密鑰必須是對應此憑證類型的（防止拿駕照 vk 驗年齡）
        assert!(vk.credential_type == expected_type, E_INVALID_PROOF);

        // 2. 基本格式：proof 非空、public_inputs 為 32-byte scalar 的整數倍
        assert!(vector::length(&proof) > 0, E_INVALID_PROOF);
        let inputs_len = vector::length(&public_inputs);
        assert!(inputs_len > 0 && inputs_len % 32 == 0, E_INVALID_PUBLIC_SIGNALS);

        // 3. 真正的 Groth16 配對驗證
        let curve = groth16::bn254();
        let pvk = groth16::prepare_verifying_key(&curve, &vk.vk_bytes);
        let proof_inputs = groth16::public_proof_inputs_from_bytes(public_inputs);
        let proof_points = groth16::proof_points_from_bytes(proof);
        let verified = groth16::verify_groth16_proof(&curve, &pvk, &proof_inputs, &proof_points);
        assert!(verified, E_INVALID_PROOF);
    }

    /// 檢查用戶是否已驗證特定類型的憑證
    public fun has_credential(
        registry: &CredentialRegistry,
        user_did: String,
        credential_type: u64
    ): bool {
        if (!table::contains(&registry.user_credentials, user_did)) {
            return false
        };

        let user_creds = table::borrow(&registry.user_credentials, user_did);
        table::contains(user_creds, credential_type)
    }

    /// 獲取用戶憑證驗證時間
    public fun get_credential_timestamp(
        registry: &CredentialRegistry,
        user_did: String,
        credential_type: u64
    ): u64 {
        let user_creds = table::borrow(&registry.user_credentials, user_did);
        *table::borrow(user_creds, credential_type)
    }

    /// 獲取總驗證次數
    public fun get_total_verifications(registry: &CredentialRegistry): u64 {
        registry.total_verifications
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}
