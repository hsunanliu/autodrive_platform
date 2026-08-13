pragma circom 2.0.0;

/*
 * 年齡驗證電路 (Age Verification Circuit)
 *
 * 證明用戶年齡 >= minAge 而不揭露實際出生日期
 *
 * 私有輸入 (Private Inputs):
 *   - birthYear: 出生年份 (e.g., 1990)
 *   - birthMonth: 出生月份 (1-12)
 *   - birthDay: 出生日期 (1-31)
 *
 * 公開輸入 (Public Inputs):
 *   - currentYear: 當前年份
 *   - currentMonth: 當前月份
 *   - currentDay: 當前日期
 *   - minAge: 最小年齡要求 (e.g., 18)
 *   - didHash: DID 的哈希值 (用於綁定身份)
 *
 * 輸出 (Output):
 *   - isValid: 1 表示年齡合格, 0 表示不合格
 */

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

// 比較器：a <= b
template LessEqThan(n) {
    signal input in[2];
    signal output out;

    component lt = LessThan(n);
    lt.in[0] <== in[0];
    lt.in[1] <== in[1] + 1;
    out <== lt.out;
}

// 比較器：a >= b
template GreaterEqThan(n) {
    signal input in[2];
    signal output out;

    component leq = LessEqThan(n);
    leq.in[0] <== in[1];
    leq.in[1] <== in[0];
    out <== leq.out;
}

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

// 選擇器：如果 sel = 1，輸出 in1，否則輸出 in0
template Selector() {
    signal input in0;
    signal input in1;
    signal input sel;
    signal output out;

    out <== in0 + sel * (in1 - in0);
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

// 主電路：年齡驗證
template AgeVerification() {
    // 私有輸入
    signal input birthYear;
    signal input birthMonth;
    signal input birthDay;

    // 公開輸入
    signal input currentYear;
    signal input currentMonth;
    signal input currentDay;
    signal input minAge;
    signal input didHash;

    // 輸出
    signal output isValid;
    signal output didCommitment;

    // 計算基本年齡差
    signal yearDiff;
    yearDiff <== currentYear - birthYear;

    // 檢查是否已經過生日
    // 如果 currentMonth > birthMonth，或者 currentMonth == birthMonth && currentDay >= birthDay
    // 則今年已過生日

    // monthPassed: currentMonth > birthMonth
    component monthGt = GreaterEqThan(8);
    monthGt.in[0] <== currentMonth;
    monthGt.in[1] <== birthMonth + 1;
    signal monthPassed;
    monthPassed <== monthGt.out;

    // sameMonth: currentMonth == birthMonth (使用正確的 IsEqual 模板)
    component monthEq = IsEqual();
    monthEq.in[0] <== currentMonth;
    monthEq.in[1] <== birthMonth;
    signal sameMonth;
    sameMonth <== monthEq.out;

    // dayPassed: currentDay >= birthDay (when same month)
    component dayGeq = GreaterEqThan(8);
    dayGeq.in[0] <== currentDay;
    dayGeq.in[1] <== birthDay;
    signal dayPassed;
    dayPassed <== dayGeq.out;

    // birthdayPassed: 今年是否已過生日
    signal birthdayPassed;
    birthdayPassed <== monthPassed + sameMonth * dayPassed;

    // 計算實際年齡
    signal actualAge;
    component ageSel = Selector();
    ageSel.in0 <== yearDiff - 1;  // 還沒過生日
    ageSel.in1 <== yearDiff;       // 已過生日
    ageSel.sel <== birthdayPassed;
    actualAge <== ageSel.out;

    // 驗證年齡 >= minAge
    component ageCheck = GreaterEqThan(8);
    ageCheck.in[0] <== actualAge;
    ageCheck.in[1] <== minAge;
    isValid <== ageCheck.out;

    // DID 承諾值（直接輸出哈希）
    didCommitment <== didHash;

    // 約束：年份必須合理
    signal yearValid;
    component yearCheck = GreaterEqThan(16);
    yearCheck.in[0] <== birthYear;
    yearCheck.in[1] <== 1900;
    yearValid <== yearCheck.out;
    yearValid === 1;

    // 約束：月份必須在 1-12
    signal monthValid;
    component monthLow = GreaterEqThan(8);
    monthLow.in[0] <== birthMonth;
    monthLow.in[1] <== 1;
    component monthHigh = LessEqThan(8);
    monthHigh.in[0] <== birthMonth;
    monthHigh.in[1] <== 12;
    monthValid <== monthLow.out * monthHigh.out;
    monthValid === 1;

    // 約束：日期必須在 1-31
    signal dayValid;
    component dayLow = GreaterEqThan(8);
    dayLow.in[0] <== birthDay;
    dayLow.in[1] <== 1;
    component dayHigh = LessEqThan(8);
    dayHigh.in[0] <== birthDay;
    dayHigh.in[1] <== 31;
    dayValid <== dayLow.out * dayHigh.out;
    dayValid === 1;
}

component main {public [currentYear, currentMonth, currentDay, minAge, didHash]} = AgeVerification();
