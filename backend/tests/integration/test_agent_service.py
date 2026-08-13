"""agent_service：缺金鑰/髒參數送鏈前拒絕；鏈上失敗明確報錯、絕不回假 hash。"""
import pytest

from app.config import settings
from app.services.agent_service import AgentService

VALID_ESCROW = "0x" + "1" * 64
VALID_CAP = "0x" + "2" * 64


def _forbid_chain(monkeypatch):
    """任何測試都不允許真的建立鏈上 client。"""
    def _boom(self, _key):
        raise AssertionError("測試中不應建立鏈上 client")
    monkeypatch.setattr(AgentService, "_build_client", _boom)


async def test_missing_operator_key_rejected(monkeypatch):
    _forbid_chain(monkeypatch)
    monkeypatch.setattr(settings, "OPERATOR_PRIVATE_KEY", None)
    result = await AgentService().release_escrow_via_agent(VALID_ESCROW, VALID_CAP, trip_id=1)
    assert result["success"] is False
    assert "OPERATOR_PRIVATE_KEY" in result["error"]
    assert "transaction_hash" not in result  # 失敗不得夾帶任何 hash


async def test_malformed_object_id_rejected_before_chain(monkeypatch):
    _forbid_chain(monkeypatch)
    monkeypatch.setattr(settings, "OPERATOR_PRIVATE_KEY", "suiprivkey1-dummy")
    result = await AgentService().release_escrow_via_agent(
        "definitely-not-an-object-id", VALID_CAP, trip_id=1
    )
    assert result["success"] is False
    assert "object id" in result["error"]
    assert "transaction_hash" not in result


async def test_chain_failure_is_explicit_error_not_fake_hash(monkeypatch):
    monkeypatch.setattr(settings, "OPERATOR_PRIVATE_KEY", "suiprivkey1-dummy")

    def _rpc_down(self, _key):
        raise RuntimeError("RPC down: connection refused")
    monkeypatch.setattr(AgentService, "_build_client", _rpc_down)

    result = await AgentService().refund_escrow_via_agent(VALID_ESCROW, VALID_CAP)
    assert result["success"] is False
    assert "RPC down" in result["error"]
    assert "transaction_hash" not in result
