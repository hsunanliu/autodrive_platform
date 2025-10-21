from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_async_session
from app.core.security import verify_token
from app.models import AdminUser


_admin_bearer = HTTPBearer(auto_error=True)


async def get_current_admin(
    credentials: HTTPAuthorizationCredentials = Depends(_admin_bearer),
    session: AsyncSession = Depends(get_async_session),
) -> AdminUser:
    token = credentials.credentials
    admin_id = verify_token(token)
    if not admin_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="無效的認證令牌")

    admin = await session.get(AdminUser, int(admin_id))
    if not admin or not admin.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="管理員不存在或未啟用")

    return admin
