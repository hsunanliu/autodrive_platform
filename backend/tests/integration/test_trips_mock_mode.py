"""trips.verify-payment：模擬付款只在 MOCK_MODE 生效（封堵免費搭車漏洞）。"""
from types import SimpleNamespace

import pytest

import app.api.v1.trips as trips_module
from app.config import settings


def _fake_trip():
    return SimpleNamespace(
        user_id=1,
        fare=1.0,
        total_amount=1.05,
        payment_status="pending",
        payment_tx_hash=None,
        escrow_object_id=None,
    )


@pytest.fixture
def patched(monkeypatch, fake_session_factory):
    trip = _fake_trip()

    class _FakeTripService:
        def __init__(self, _db):
            pass

        async def _get_trip_by_id(self, _trip_id):
            return trip

    monkeypatch.setattr(trips_module, "TripService", _FakeTripService)
    db = fake_session_factory([])
    user = SimpleNamespace(id=1)
    return SimpleNamespace(trip=trip, db=db, user=user, monkeypatch=monkeypatch)


async def test_simulated_tx_rejected_when_mock_mode_off(patched):
    """MOCK_MODE 關閉時，0xtx… 假 hash 不得直接標記已付款（免費搭車漏洞）。"""
    patched.monkeypatch.setattr(settings, "MOCK_MODE", False)

    async def _chain_says_no(**_kw):
        return {"valid": False, "error": "transaction not found on chain"}
    patched.monkeypatch.setattr(
        trips_module.iota_service, "verify_payment_transaction", _chain_says_no
    )

    result = await trips_module.verify_trip_payment(
        trip_id=7, tx_hash="0xtx-free-ride-attempt",
        db=patched.db, current_user=patched.user,
    )
    assert result["success"] is False
    assert patched.trip.payment_status == "pending"  # 不得被標成 locked
    assert patched.db.commits == 0


async def test_simulated_tx_allowed_only_in_mock_mode(patched):
    patched.monkeypatch.setattr(settings, "MOCK_MODE", True)

    async def _chain_must_not_be_called(**_kw):
        raise AssertionError("MOCK_MODE 模擬路徑不應打鏈上驗證")
    patched.monkeypatch.setattr(
        trips_module.iota_service, "verify_payment_transaction", _chain_must_not_be_called
    )

    result = await trips_module.verify_trip_payment(
        trip_id=7, tx_hash="0xsimulated-test",
        db=patched.db, current_user=patched.user,
    )
    assert result["success"] is True
    assert result["simulated"] is True
    assert patched.trip.payment_status == "locked"
    assert patched.db.commits == 1


async def test_real_tx_verified_on_chain(patched):
    """非模擬 hash 一律走鏈上驗證，驗過才標記 locked。"""
    patched.monkeypatch.setattr(settings, "MOCK_MODE", False)

    async def _chain_says_yes(**_kw):
        return {"valid": True, "amount_received": 1_050_000_000, "recipient": "0xplatform"}
    patched.monkeypatch.setattr(
        trips_module.iota_service, "verify_payment_transaction", _chain_says_yes
    )

    result = await trips_module.verify_trip_payment(
        trip_id=7, tx_hash="8gVxRealDigest",
        db=patched.db, current_user=patched.user,
    )
    assert result["success"] is True
    assert result["simulated"] is False
    assert patched.trip.payment_status == "locked"
    assert patched.db.commits == 1
