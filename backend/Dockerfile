# backend/Dockerfile
FROM python:3.11-slim

# 設定工作目錄
WORKDIR /app

# 安裝系統依賴（Sui SDK 需要）
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    build-essential \
    libffi-dev \
    libssl-dev \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# 升級 pip
RUN pip install --upgrade pip

# 複製 requirements.txt
COPY requirements.txt .

# 安裝 Python 依賴
RUN pip install --no-cache-dir -r requirements.txt

# 複製應用代碼（初始時可能為空）
COPY . .

# 創建 app 目錄（如果不存在）
RUN mkdir -p /app/app

# 暴露端口
EXPOSE 8000

# 開發模式啟動命令
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
