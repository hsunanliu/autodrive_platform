"""
日誌配置模組
"""
import logging
import sys
from pathlib import Path
from logging.handlers import RotatingFileHandler

def setup_logging(log_level: str = "INFO", log_to_file: bool = True):
    """
    設置應用程式日誌
    
    Args:
        log_level: 日誌級別 (DEBUG, INFO, WARNING, ERROR, CRITICAL)
        log_to_file: 是否輸出到檔案
    """
    # 創建日誌目錄
    log_dir = Path(__file__).parent.parent.parent.parent / "logs"
    log_dir.mkdir(exist_ok=True)
    
    # 日誌格式
    log_format = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    # 根日誌記錄器
    root_logger = logging.getLogger()
    root_logger.setLevel(getattr(logging, log_level.upper()))
    
    # 清除現有的處理器
    root_logger.handlers.clear()
    
    # 控制台處理器
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(getattr(logging, log_level.upper()))
    console_handler.setFormatter(log_format)
    root_logger.addHandler(console_handler)
    
    # 檔案處理器（如果啟用）
    if log_to_file:
        log_file = log_dir / "backend.log"
        file_handler = RotatingFileHandler(
            log_file,
            maxBytes=10 * 1024 * 1024,  # 10MB
            backupCount=5,
            encoding='utf-8'
        )
        file_handler.setLevel(getattr(logging, log_level.upper()))
        file_handler.setFormatter(log_format)
        root_logger.addHandler(file_handler)
        
        logging.info(f"日誌檔案: {log_file}")
    
    # 設置第三方庫的日誌級別
    logging.getLogger("uvicorn").setLevel(logging.WARNING)
    logging.getLogger("sqlalchemy").setLevel(logging.WARNING)
    
    return root_logger
