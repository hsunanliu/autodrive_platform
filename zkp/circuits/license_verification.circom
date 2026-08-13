pragma circom 2.0.0;

/*
 * 駕照驗證電路 (License Verification Circuit)
 *
 * 證明用戶持有有效駕照而不揭露駕照號碼
 *
 * 私有輸入 (Private Inputs):
 *   - licenseNumber: 駕照號碼的哈希 (私密)
 *   - expiryYear: 駕照有效期年份
 *   - expiryMonth: 駕照有效期月份
 *   - expiryDay: 駕照有效期日期
 *   - licenseType: 駕照類型 (1=小客車, 2=大客車, 3=職業)
 *
 * 公開輸入 (Public Inputs):
 *   - currentYear: 當前年份
 *   - currentMonth: 當前月份
 *   - currentDay: 當前日期
 *   - requiredType: 要求的最低駕照類型
 *   - didHash: DID 的哈希值
 *
 * 輸出 (Output):
 *   - isValid: 1 表示駕照有效且類型符合, 0 表示無效
 *   - didCommitment: DID 承諾值
 */

// 數字轉位元
template Num2Bits(n) {
    signal input in;
    signal output out[n+1];

    var lc = 0;
    var bit_value = 1;

    for (var i = 0; i <= n; i++) {
        out[i] <-- (in >> i) & 1;
        out[i] * (out[i] - 1) === 0;
        lc += out[i] * bit_value;
        bit_value *= 2;
    }

    lc === in;
}

// 比較器：a < b (使用 circomlib 標準方法)
template LessThan(n) {
    signal input in[2];
    signal output out;

    component n2b = Num2Bits(n+1);
    n2b.in <== in[0] + (1 << n) - in[1];

    // 如果 in[0] < in[1]，則 in[0] + 2^n - in[1] < 2^n，最高位為 0
    // 如果 in[0] >= in[1]，則 in[0] + 2^n - in[1] >= 2^n，最高位為 1
    out <== 1 - n2b.out[n];
}

template LessEqThan(n) {
    signal input in[2];
    signal output out;

    component lt = LessThan(n);
    lt.in[0] <== in[0];
    lt.in[1] <== in[1] + 1;
    out <== lt.out;
}

template GreaterEqThan(n) {
    signal input in[2];
    signal output out;

    component leq = LessEqThan(n);
    leq.in[0] <== in[1];
    leq.in[1] <== in[0];
    out <== leq.out;
}

template GreaterThan(n) {
    signal input in[2];
    signal output out;

    component gt = GreaterEqThan(n);
    gt.in[0] <== in[0];
    gt.in[1] <== in[1] + 1;
    out <== gt.out;
}

// IsZero: 如果 in == 0，輸出 1，否則輸出 0
template IsZero() {
    signal input in;
    signal output out;

    signal inv;
    inv <-- in != 0 ? 1/in : 0;

    out <== -in*inv + 1;
    in*out === 0;
}

// IsEqual: 如果 in[0] == in[1]，輸出 1，否則輸出 0
template IsEqual() {
    signal input in[2];
    signal output out;

    component isz = IsZero();
    isz.in <== in[0] - in[1];
    out <== isz.out;
}

// 主電路：駕照驗證
template LicenseVerification() {
    // 私有輸入
    signal input licenseHash;       // 駕照號碼的哈希
    signal input expiryYear;
    signal input expiryMonth;
    signal input expiryDay;
    signal input licenseType;       // 1=普通, 2=職業, 3=大型

    // 公開輸入
    signal input currentYear;
    signal input currentMonth;
    signal input currentDay;
    signal input requiredType;      // 要求的駕照類型
    signal input didHash;

    // 輸出
    signal output isValid;
    signal output didCommitment;
    signal output licenseCommitment; // 駕照承諾值 (不揭露號碼)

    // 1. 檢查駕照是否過期
    // 比較日期：expiry >= current

    // 先比較年份
    component yearCmp = GreaterThan(16);
    yearCmp.in[0] <== expiryYear;
    yearCmp.in[1] <== currentYear;
    signal yearGreater;
    yearGreater <== yearCmp.out;

    // 年份相等時的處理 (使用正確的 IsEqual)
    component yearEq = IsEqual();
    yearEq.in[0] <== expiryYear;
    yearEq.in[1] <== currentYear;
    signal yearEqual;
    yearEqual <== yearEq.out;

    // 比較月份
    component monthCmp = GreaterThan(8);
    monthCmp.in[0] <== expiryMonth;
    monthCmp.in[1] <== currentMonth;
    signal monthGreater;
    monthGreater <== monthCmp.out;

    // 月份相等時的處理 (使用正確的 IsEqual)
    component monthEq = IsEqual();
    monthEq.in[0] <== expiryMonth;
    monthEq.in[1] <== currentMonth;
    signal monthEqual;
    monthEqual <== monthEq.out;

    // 比較日期
    component dayCmp = GreaterEqThan(8);
    dayCmp.in[0] <== expiryDay;
    dayCmp.in[1] <== currentDay;
    signal dayGeq;
    dayGeq <== dayCmp.out;

    // 綜合判斷是否未過期
    // notExpired = yearGreater || (yearEqual && monthGreater) || (yearEqual && monthEqual && dayGeq)
    signal case1;
    case1 <== yearGreater;

    signal case2;
    case2 <== yearEqual * monthGreater;

    signal case3a;
    case3a <== yearEqual * monthEqual;
    signal case3;
    case3 <== case3a * dayGeq;

    signal notExpired;
    notExpired <== case1 + case2 + case3;

    // 確保 notExpired 是布爾值
    signal notExpiredNormalized;
    component expCheck = GreaterEqThan(8);
    expCheck.in[0] <== notExpired;
    expCheck.in[1] <== 1;
    notExpiredNormalized <== expCheck.out;

    // 2. 檢查駕照類型是否符合要求
    component typeCheck = GreaterEqThan(8);
    typeCheck.in[0] <== licenseType;
    typeCheck.in[1] <== requiredType;
    signal typeValid;
    typeValid <== typeCheck.out;

    // 3. 綜合判斷
    isValid <== notExpiredNormalized * typeValid;

    // 4. 輸出承諾值
    didCommitment <== didHash;
    licenseCommitment <== licenseHash;

    // 約束：駕照類型必須在 1-3
    signal typeValid1;
    component typeLow = GreaterEqThan(8);
    typeLow.in[0] <== licenseType;
    typeLow.in[1] <== 1;
    component typeHigh = LessEqThan(8);
    typeHigh.in[0] <== licenseType;
    typeHigh.in[1] <== 3;
    typeValid1 <== typeLow.out * typeHigh.out;
    typeValid1 === 1;

    // 約束：有效期必須合理
    signal expiryValid;
    component expYearCheck = GreaterEqThan(16);
    expYearCheck.in[0] <== expiryYear;
    expYearCheck.in[1] <== 2020;
    expiryValid <== expYearCheck.out;
    expiryValid === 1;
}

component main {public [currentYear, currentMonth, currentDay, requiredType, didHash]} = LicenseVerification();
