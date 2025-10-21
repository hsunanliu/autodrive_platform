from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_async_session
from app.core.security import create_access_token, hash_password, verify_password
from app.models import AdminUser
from app.schemas.admin import AdminCreateRequest, AdminInfo, AdminLoginRequest, AdminLoginResponse

router = APIRouter(prefix="/admin/auth", tags=["admin-auth"])


@router.post("/login", response_model=AdminLoginResponse)
async def admin_login(
    payload: AdminLoginRequest,
    session: AsyncSession = Depends(get_async_session),
):
    stmt = select(AdminUser).where(AdminUser.email == payload.email, AdminUser.is_active.is_(True))
    result = await session.execute(stmt)
    admin = result.scalar_one_or_none()

    if not admin or not verify_password(payload.password, admin.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="電子郵件或密碼錯誤")

    token = create_access_token(subject=str(admin.id), expires_delta=timedelta(hours=24))
    return AdminLoginResponse(token=token, admin=AdminInfo.model_validate(admin))


@router.post("/create-admin", response_model=AdminInfo)
async def create_admin(
    payload: AdminCreateRequest,
    session: AsyncSession = Depends(get_async_session),
):
    stmt = select(AdminUser).where(AdminUser.email == payload.email)
    if (await session.execute(stmt)).scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="電子郵件已存在")

    admin = AdminUser(
        name=payload.name,
        email=payload.email,
        password_hash=hash_password(payload.password),
    )
    session.add(admin)
    await session.commit()
    await session.refresh(admin)
    return AdminInfo.model_validate(admin)
