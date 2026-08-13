/// 使用者身分狀態物件（Profile）
///
/// 把「是否成年 / 是否持有效駕照」等**驗證後身分狀態**存成使用者自己擁有的物件，
/// 而非塞進共享 registry 的巨型 Table（避免 Shared Object 狀態膨脹 griefing，威脅 T9）。
///
/// 安全不變式：
///   - **Soulbound**：`key` only（無 `store`）、且本模組不提供任何轉移函式 → 無法被轉讓/販售。
///   - **狀態只能由 credential_verifier 設定**：flag 的 setter 是 `public(package)`（非 public、非 entry），
///     外部套件與任何原生交易都無法直接呼叫；本套件內僅 `credential_verifier` 在 groth16 驗證通過後設定。
///     → 即使平台 Agent 完全被接管，也動不了身分狀態（OperatorCap 亦無觸及 Profile 的動作）。
///   - 只存 boolean 與 commitment，不存明文（DOB / 駕照號一律不上鏈）。
module autodrive::profile {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;

    const E_ALREADY_HAS_PROFILE: u64 = 1; // 保留

    /// 乘客身分（soulbound）
    public struct PassengerProfile has key {
        id: UID,
        owner: address,
        is_adult: bool,
        kyc_commitment: vector<u8>,
        updated_at: u64,
    }

    /// 司機身分（soulbound）
    public struct DriverProfile has key {
        id: UID,
        owner: address,
        is_adult: bool,
        has_valid_license: bool,
        license_commitment: vector<u8>,
        reputation: u64,
        updated_at: u64,
    }

    // ============================================================
    // 建立（使用者為自己建立，物件歸屬本人）
    // ============================================================

    public entry fun create_passenger_profile(ctx: &mut TxContext) {
        let owner = tx_context::sender(ctx);
        let profile = PassengerProfile {
            id: object::new(ctx),
            owner,
            is_adult: false,
            kyc_commitment: b"",
            updated_at: tx_context::epoch(ctx),
        };
        transfer::transfer(profile, owner);
    }

    public entry fun create_driver_profile(ctx: &mut TxContext) {
        let owner = tx_context::sender(ctx);
        let profile = DriverProfile {
            id: object::new(ctx),
            owner,
            is_adult: false,
            has_valid_license: false,
            license_commitment: b"",
            reputation: 0,
            updated_at: tx_context::epoch(ctx),
        };
        transfer::transfer(profile, owner);
    }

    // ============================================================
    // 狀態設定（public(package)：僅本套件內的 credential_verifier 於驗證後呼叫）
    // ============================================================

    public(package) fun set_passenger_adult(
        profile: &mut PassengerProfile,
        kyc_commitment: vector<u8>,
        now: u64,
    ) {
        profile.is_adult = true;
        profile.kyc_commitment = kyc_commitment;
        profile.updated_at = now;
    }

    public(package) fun set_driver_adult(
        profile: &mut DriverProfile,
        kyc_commitment: vector<u8>,
        now: u64,
    ) {
        profile.is_adult = true;
        profile.license_commitment = kyc_commitment;
        profile.updated_at = now;
    }

    public(package) fun set_driver_license(
        profile: &mut DriverProfile,
        license_commitment: vector<u8>,
        now: u64,
    ) {
        profile.has_valid_license = true;
        profile.license_commitment = license_commitment;
        profile.updated_at = now;
    }

    // ============================================================
    // 視圖函數
    // ============================================================
    public fun passenger_owner(p: &PassengerProfile): address { p.owner }
    public fun passenger_is_adult(p: &PassengerProfile): bool { p.is_adult }
    public fun driver_owner(p: &DriverProfile): address { p.owner }
    public fun driver_is_adult(p: &DriverProfile): bool { p.is_adult }
    public fun driver_has_license(p: &DriverProfile): bool { p.has_valid_license }

    #[test_only]
    public fun create_passenger_for_testing(owner: address, ctx: &mut TxContext): PassengerProfile {
        PassengerProfile { id: object::new(ctx), owner, is_adult: false, kyc_commitment: b"", updated_at: 0 }
    }

    #[test_only]
    public fun destroy_passenger_for_testing(p: PassengerProfile) {
        let PassengerProfile { id, owner: _, is_adult: _, kyc_commitment: _, updated_at: _ } = p;
        object::delete(id);
    }
}
