# backend/app/models/payment.py

"""
Payment 相關資料庫模型
管理支付方式與交易記錄
"""

from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, CheckConstraint, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base

class PaymentMethod(Base):
    """
    支付方式模型 - 管理用戶支付方式
    """
    
    __tablename__ = "payment_methods"
    
    # === 主鍵 ===
    payment_id = Column(Integer, primary_key=True, comment="支付方式ID")
    
    # === 用戶關聯 ===
    user_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=False,
        comment="用戶ID"
    )
    
    # === 支付方式資訊 ===
    method_type = Column(
        String(20),
        nullable=False,
        comment="支付類型：credit_card, debit_card, ewallet, crypto"
    )
    
    provider_name = Column(
        String(50),
        nullable=True,
        comment="發卡機構/服務商"
    )
    
    account_number = Column(
        String(255),
        nullable=False,
        comment="帳號/卡號（加密存儲）"
    )
    
    expiration_date = Column(
        String(10),
        nullable=True,
        comment="到期日期（MM/YY）"
    )
    
    is_default = Column(
        Boolean,
        default=False,
        nullable=False,
        comment="是否為預設支付方式"
    )
    
    is_active = Column(
        Boolean,
        default=True,
        nullable=False,
        comment="是否啟用"
    )
    
    # === 時間戳記 ===
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        comment="新增時間"
    )
    
    updated_at = Column(
        DateTime(timezone=True),
        onupdate=func.now(),
        comment="最後更新時間"
    )
    
    # === 關聯關係 ===
    user = relationship("User")
    
    # === 約束條件 ===
    __table_args__ = (
        CheckConstraint(
            "method_type IN ('credit_card', 'debit_card', 'ewallet', 'crypto')",
            name='valid_payment_method_type'
        ),
    )
    
    def __repr__(self):
        return f"<PaymentMethod {self.payment_id} ({self.method_type})>"

class PaymentTransaction(Base):
    """
    支付交易模型 - 記錄所有支付交易
    """
    
    __tablename__ = "payment_transactions"
    
    # === 主鍵 ===
    transaction_id = Column(String(66), primary_key=True, comment="交易ID")
    
    # === 關聯資訊 ===
    trip_id = Column(
        Integer,
        ForeignKey("trips.trip_id"),
        nullable=False,
        comment="行程ID"
    )
    
    payer_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=False,
        comment="付款人ID"
    )
    
    payee_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=False,
        comment="收款人ID"
    )
    
    payment_method_id = Column(
        Integer,
        ForeignKey("payment_methods.payment_id"),
        nullable=True,
        comment="支付方式ID"
    )
    
    # === 金額資訊 ===
    amount = Column(
        Float,
        nullable=False,
        comment="交易金額（台幣）"
    )
    
    amount_micro_iota = Column(
        String(50),
        nullable=True,
        comment="IOTA金額（micro IOTA）"
    )
    
    service_fee = Column(
        Float,
        default=0.0,
        nullable=False,
        comment="服務費"
    )
    
    # === 交易狀態 ===
    status = Column(
        String(20),
        default="pending",
        nullable=False,
        comment="交易狀態：pending, completed, failed, refunded"
    )
    
    payment_type = Column(
        String(20),
        nullable=False,
        comment="支付類型：fiat, crypto, hybrid"
    )
    
    # === 區塊鏈資訊 ===
    blockchain_tx_hash = Column(
        String(66),
        nullable=True,
        comment="區塊鏈交易哈希"
    )
    
    blockchain_block_number = Column(
        Integer,
        nullable=True,
        comment="區塊號"
    )
    
    # === 時間戳記 ===
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        comment="交易發起時間"
    )
    
    completed_at = Column(
        DateTime(timezone=True),
        nullable=True,
        comment="交易完成時間"
    )
    
    # === 關聯關係 ===
    trip = relationship("Trip")
    payer = relationship("User", foreign_keys=[payer_id])
    payee = relationship("User", foreign_keys=[payee_id])
    payment_method = relationship("PaymentMethod")
    
    # === 約束條件 ===
    __table_args__ = (
        CheckConstraint(
            "status IN ('pending', 'completed', 'failed', 'refunded')",
            name='valid_transaction_status'
        ),
        CheckConstraint(
            "payment_type IN ('fiat', 'crypto', 'hybrid')",
            name='valid_payment_type'
        ),
        CheckConstraint(
            'amount > 0',
            name='valid_amount'
        ),
    )
    
    def __repr__(self):
        return f"<PaymentTransaction {self.transaction_id} ({self.status})>"
