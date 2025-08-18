# 1. 使用官方 Python 映像檔作為基礎
FROM python:3.11-slim

# 2. 設定工作目錄
WORKDIR /app

# 3. 安裝依賴套件
# 先複製 requirements.txt 並安裝，這一步可以被 Docker 快取，加速後續建置
COPY requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# 4. 複製後端專案的原始碼
COPY ./app /app/app

# 5. 暴露服務運行的端口
EXPOSE 8000

# 6. 設定啟動指令
# 使用 uvicorn 啟動 FastAPI 應用
# --host 0.0.0.0 讓容器外部可以訪問
# --reload 讓程式碼變更時服務自動重啟，方便開發
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
