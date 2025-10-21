# backend/app/models/__init__.py

from app.core.database import Base
from .user import User
from .vehicle import Vehicle
from .ride import Trip
from .review import Review
from .payment import PaymentMethod, PaymentTransaction
from .refund import RefundRequest
from .admin_user import AdminUser

# 確保所有模型都被導入，這樣 Base.metadata 才能找到它們
__all__ = [
    "Base", 
    "User", 
    "Vehicle", 
    "Trip", 
    "Review", 
    "PaymentMethod", 
    "PaymentTransaction",
    "RefundRequest",
    "AdminUser"
]
