#!/bin/bash
# ZKP 電路編譯腳本
# 編譯 Circom 電路並生成證明密鑰

set -e

echo "=== ZKP Circuit Build Script ==="
echo ""

CIRCUITS_DIR="/zkp/circuits"
BUILD_DIR="/zkp/build"
KEYS_DIR="/zkp/keys"
PTAU_FILE="/zkp/ptau/pot12_final.ptau"

mkdir -p "$BUILD_DIR" "$KEYS_DIR"

# 編譯年齡驗證電路
echo "1. 編譯年齡驗證電路..."
circom "$CIRCUITS_DIR/age_verification.circom" \
    --r1cs --wasm --sym \
    -o "$BUILD_DIR"

echo "   - 生成 r1cs: $BUILD_DIR/age_verification.r1cs"
echo "   - 生成 wasm: $BUILD_DIR/age_verification_js/"
echo ""

# 編譯駕照驗證電路
echo "2. 編譯駕照驗證電路..."
circom "$CIRCUITS_DIR/license_verification.circom" \
    --r1cs --wasm --sym \
    -o "$BUILD_DIR"

echo "   - 生成 r1cs: $BUILD_DIR/license_verification.r1cs"
echo "   - 生成 wasm: $BUILD_DIR/license_verification_js/"
echo ""

# 生成年齡驗證密鑰
echo "3. 生成年齡驗證證明密鑰 (Groth16 Setup)..."
snarkjs groth16 setup \
    "$BUILD_DIR/age_verification.r1cs" \
    "$PTAU_FILE" \
    "$KEYS_DIR/age_verification_0000.zkey"

# 貢獻隨機性 (實際生產環境需要更多參與者)
echo "   - 添加隨機貢獻..."
snarkjs zkey contribute \
    "$KEYS_DIR/age_verification_0000.zkey" \
    "$KEYS_DIR/age_verification_final.zkey" \
    --name="AutoDrive Contribution" \
    -v -e="random entropy for age verification"

# 導出驗證密鑰
echo "   - 導出驗證密鑰..."
snarkjs zkey export verificationkey \
    "$KEYS_DIR/age_verification_final.zkey" \
    "$KEYS_DIR/age_verification_vkey.json"

echo ""

# 生成駕照驗證密鑰
echo "4. 生成駕照驗證證明密鑰..."
snarkjs groth16 setup \
    "$BUILD_DIR/license_verification.r1cs" \
    "$PTAU_FILE" \
    "$KEYS_DIR/license_verification_0000.zkey"

echo "   - 添加隨機貢獻..."
snarkjs zkey contribute \
    "$KEYS_DIR/license_verification_0000.zkey" \
    "$KEYS_DIR/license_verification_final.zkey" \
    --name="AutoDrive Contribution" \
    -v -e="random entropy for license verification"

echo "   - 導出驗證密鑰..."
snarkjs zkey export verificationkey \
    "$KEYS_DIR/license_verification_final.zkey" \
    "$KEYS_DIR/license_verification_vkey.json"

echo ""
echo "=== 編譯完成 ==="
echo ""
echo "生成的文件："
echo "  - $BUILD_DIR/age_verification_js/age_verification.wasm"
echo "  - $BUILD_DIR/license_verification_js/license_verification.wasm"
echo "  - $KEYS_DIR/age_verification_final.zkey"
echo "  - $KEYS_DIR/age_verification_vkey.json"
echo "  - $KEYS_DIR/license_verification_final.zkey"
echo "  - $KEYS_DIR/license_verification_vkey.json"
echo ""
echo "這些文件需要複製到後端和前端使用"
