from fastapi import APIRouter

from . import auth, dashboard, refunds, trips, users, vehicles

router = APIRouter()
router.include_router(auth.router)
router.include_router(dashboard.router)
router.include_router(refunds.router)
router.include_router(vehicles.router)
router.include_router(users.router)
router.include_router(trips.router)

__all__ = ["router"]
