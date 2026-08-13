# ZKP Builder Dockerfile
# 用於編譯 Circom 電路和生成證明密鑰
FROM node:20-slim

# 安裝必要工具
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

# 安裝 Rust (用於編譯 Circom)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# 安裝 Circom
RUN git clone https://github.com/iden3/circom.git /tmp/circom \
    && cd /tmp/circom \
    && cargo build --release \
    && cargo install --path circom \
    && rm -rf /tmp/circom

# 安裝 snarkjs
RUN npm install -g snarkjs

# 工作目錄
WORKDIR /zkp

# 複製電路文件
COPY circuits/ ./circuits/
COPY scripts/ ./scripts/

# 下載 Powers of Tau (trusted setup 公共參數)
# 使用 iden3/snarkjs 官方的 ptau 文件
RUN mkdir -p /zkp/ptau && \
    curl -L --fail -o /zkp/ptau/pot12_final.ptau \
    "https://storage.googleapis.com/zkevm/ptau/powersOfTau28_hez_final_12.ptau"

# 設置執行權限
RUN chmod +x /zkp/scripts/*.sh

CMD ["bash"]
