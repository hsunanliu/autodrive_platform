"""delegation_service：過期/撤銷 cap 拒用；額度與時效正確解析入庫。"""
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import pytest

from app.config import settings
from app.services.delegation_service import DelegationService
from tests.integration.conftest import FakeResult

CAP_ID = "0x" + "c" * 64
PLATFORM = "0x" + "9" * 64
USER_WALLET = "0x" + "5" * 64


def _cap_row(cap_id, valid_until):
    return SimpleNamespace(cap_object_id=cap_id, valid_until=valid_until, revoked=False)


async def test_get_active_cap_skips_expired(fake_session_factory):
    expired = _cap_row("0xexpired", datetime.now(timezone.utc) - timedelta(days=1))
    valid = _cap_row(CAP_ID, datetime.now(timezone.utc) + timedelta(days=30))
    db = fake_session_factory([FakeResult(many=[expired, valid])])
    assert await DelegationService(db).get_active_cap(user_id=1) == CAP_ID


async def test_get_active_cap_all_expired_returns_none(fake_session_factory):
    expired = _cap_row("0xexpired", datetime.now(timezone.utc) - timedelta(seconds=1))
    db = fake_session_factory([FakeResult(many=[expired])])
    assert await DelegationService(db).get_active_cap(user_id=1) is None


async def test_get_active_cap_no_expiry_is_valid(fake_session_factory):
    db = fake_session_factory([FakeResult(many=[_cap_row(CAP_ID, None)])])
    assert await DelegationService(db).get_active_cap(user_id=1) == CAP_ID


async def test_record_delegation_rejects_revoked_cap(monkeypatch, fake_session_factory):
    monkeypatch.setattr(settings, "PLATFORM_WALLET", PLATFORM)

    async def _fields(self, _cap_id):
        return {"agent": PLATFORM, "user": USER_WALLET, "revoked": True}
    monkeypatch.setattr(DelegationService, "_fetch_cap_fields", _fields)

    db = fake_session_factory([])
    result = await DelegationService(db).record_delegation(user_id=1, cap_object_id=CAP_ID)
    assert result["success"] is False
    assert "撤銷" in result["error"]
    assert db.commits == 0


async def test_record_delegation_rejects_foreign_agent(monkeypatch, fake_session_factory):
    monkeypatch.setattr(settings, "PLATFORM_WALLET", PLATFORM)

    async def _fields(self, _cap_id):
        return {"agent": "0x" + "d" * 64, "user": USER_WALLET, "revoked": False}
    monkeypatch.setattr(DelegationService, "_fetch_cap_fields", _fields)

    db = fake_session_factory([])
    result = await DelegationService(db).record_delegation(user_id=1, cap_object_id=CAP_ID)
    assert result["success"] is False
    assert "agent" in result["error"]
    assert db.commits == 0


async def test_record_delegation_parses_limits_and_expiry(monkeypatch, fake_session_factory):
    monkeypatch.setattr(settings, "PLATFORM_WALLET", PLATFORM)
    valid_until_ms = 4_102_444_800_000  # 2100-01-01 UTC

    async def _fields(self, _cap_id):
        return {
            "agent": PLATFORM,
            "user": USER_WALLET,
            "revoked": False,
            "max_spend_per_tx": "1000000000",
            "daily_limit": "5000000000",
            "valid_until_ms": str(valid_until_ms),
            "allowed_actions": "3",
        }
    monkeypatch.setattr(DelegationService, "_fetch_cap_fields", _fields)

    user = SimpleNamespace(id=1, wallet_address=USER_WALLET)
    db = fake_session_factory([FakeResult(user), FakeResult(None)])  # 查 user、查既有委託
    result = await DelegationService(db).record_delegation(user_id=1, cap_object_id=CAP_ID)

    assert result["success"] is True
    assert db.commits == 1
    (row,) = db.added
    assert row.cap_object_id == CAP_ID
    assert row.max_spend_per_tx == 1_000_000_000
    assert row.daily_limit == 5_000_000_000
    assert row.allowed_actions == 3
    assert row.valid_until == datetime.fromtimestamp(valid_until_ms / 1000, tz=timezone.utc)
    assert row.revoked is False
