"""refund_service_v2：approve 須鏈上成功才落 DB；reject 僅改 DB；已處理不得重複。"""
from types import SimpleNamespace

import pytest

from app.services.refund_service_v2 import RefundServiceV2
from app.services.sui_service import sui_service
from tests.integration.conftest import FakeResult

WALLET = "0x" + "7" * 64


def _pending_rr():
    return SimpleNamespace(
        id=11, trip_id=9, user_id=5, status="pending",
        requested_refund_twd=0.5, approved_refund_twd=0.5,
        decided_at=None, refunded_at=None, decision_note=None,
    )


def _user():
    return SimpleNamespace(id=5, wallet_address=WALLET)


async def test_approve_chain_failure_keeps_db_untouched(monkeypatch, fake_session_factory):
    async def _chain_fail(**_kw):
        return {"success": False, "error": "退款池餘額不足"}
    monkeypatch.setattr(sui_service, "call_contract_admin_refund", _chain_fail)

    rr = _pending_rr()
    db = fake_session_factory([FakeResult(rr), FakeResult(_user())])
    result = await RefundServiceV2(db).approve_and_execute_refund(11)

    assert result["success"] is False
    assert "鏈上退款失敗" in result["error"]
    assert rr.status == "pending"  # 鏈上沒成功，DB 不得標 completed
    assert db.commits == 0


async def test_approve_chain_success_completes_request(monkeypatch, fake_session_factory):
    captured = {}

    async def _chain_ok(**kw):
        captured.update(kw)
        return {"success": True, "transaction_hash": "8gVxDigestFromChain"}
    monkeypatch.setattr(sui_service, "call_contract_admin_refund", _chain_ok)

    rr = _pending_rr()
    db = fake_session_factory([FakeResult(rr), FakeResult(_user())])
    result = await RefundServiceV2(db).approve_and_execute_refund(11, admin_note="核准")

    assert result["success"] is True
    assert result["transaction_hash"] == "8gVxDigestFromChain"
    assert rr.status == "completed"
    assert db.commits == 1
    assert captured["recipient"] == WALLET
    assert captured["amount_mist"] == 500_000_000  # 0.5 SUI
    assert captured["trip_id"] == 9


async def test_approve_already_processed_rejected(monkeypatch, fake_session_factory):
    async def _chain_must_not_run(**_kw):
        raise AssertionError("已處理的請求不應再上鏈")
    monkeypatch.setattr(sui_service, "call_contract_admin_refund", _chain_must_not_run)

    rr = _pending_rr()
    rr.status = "completed"
    db = fake_session_factory([FakeResult(rr)])
    result = await RefundServiceV2(db).approve_and_execute_refund(11)
    assert result["success"] is False
    assert "已處理" in result["error"]
    assert db.commits == 0


async def test_approve_missing_request(fake_session_factory):
    db = fake_session_factory([FakeResult(None)])
    result = await RefundServiceV2(db).approve_and_execute_refund(404)
    assert result["success"] is False
    assert "不存在" in result["error"]


async def test_reject_marks_rejected_without_chain(fake_session_factory):
    rr = _pending_rr()
    db = fake_session_factory([FakeResult(rr)])
    result = await RefundServiceV2(db).reject_refund(11, admin_note="佐證不足")

    assert result["success"] is True
    assert rr.status == "rejected"
    assert rr.decision_note == "佐證不足"
    assert db.commits == 1


async def test_reject_already_processed_rejected(fake_session_factory):
    rr = _pending_rr()
    rr.status = "rejected"
    db = fake_session_factory([FakeResult(rr)])
    result = await RefundServiceV2(db).reject_refund(11)
    assert result["success"] is False
    assert "已處理" in result["error"]
    assert db.commits == 0
