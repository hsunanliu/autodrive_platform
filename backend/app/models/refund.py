from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Text
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base


class RefundRequest(Base):
    __tablename__ = "refund_requests"

    id = Column(Integer, primary_key=True, index=True)
    trip_id = Column(Integer, ForeignKey("trips.trip_id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    payment_transaction_id = Column(String(66), ForeignKey("payment_transactions.transaction_id"), nullable=True)

    reason = Column(Text, nullable=False)
    requested_refund_twd = Column(Float, nullable=True)
    requested_refund_points = Column(Integer, nullable=True)
    approved_refund_twd = Column(Float, nullable=True)
    approved_refund_points = Column(Integer, nullable=True)
    status = Column(String(20), default="refunded", nullable=False)  # 改為預設已退款
    decision_note = Column(Text, nullable=True)
    
    # 新增責任歸屬欄位
    liability = Column(String(20), nullable=True)  # driver, platform, passenger
    liability_note = Column(Text, nullable=True)
    recovery_status = Column(String(20), default="pending", nullable=True)  # pending, recovered, waived

    # IPFS 證據欄位
    evidence_cid = Column(String(100), nullable=True)  # IPFS Content Identifier
    evidence_hash = Column(String(64), nullable=True)  # SHA256 hash for verification
    evidence_filename = Column(String(255), nullable=True)  # Original filename
    evidence_content_type = Column(String(100), nullable=True)  # MIME type

    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    decided_at = Column(DateTime(timezone=True), nullable=True)
    refunded_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)  # 退款時間

    trip = relationship("Trip")
    user = relationship("User")
    payment_transaction = relationship("PaymentTransaction")
