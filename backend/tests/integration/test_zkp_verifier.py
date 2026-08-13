"""zkp_verifier：缺驗證密鑰必須 fail-closed，不得退回可偽造的模擬驗證。"""
import json
from types import SimpleNamespace

import pytest

import app.services.zkp_verifier as zkp_module
from app.services.zkp_verifier import ZKPVerifier

PROOF = {"pi_a": ["1"], "pi_b": [["1"]], "pi_c": ["1"]}
SIGNALS = [1, 12345]


def test_missing_vkey_fails_closed(tmp_path, monkeypatch):
    def _boom(*_a, **_k):
        raise AssertionError("缺 key 時不應呼叫 snarkjs")
    monkeypatch.setattr(zkp_module.subprocess, "run", _boom)

    verifier = ZKPVerifier(keys_dir=str(tmp_path))  # 空目錄 = 無 vkey
    result = verifier.verify_proof("age_verification", PROOF, SIGNALS)
    assert result["valid"] is False
    assert "缺少驗證密鑰" in result["error"]


def _write_vkey(tmp_path, circuit):
    (tmp_path / f"{circuit}_vkey.json").write_text(json.dumps({"protocol": "groth16"}))


def test_snarkjs_ok_passes(tmp_path, monkeypatch):
    _write_vkey(tmp_path, "age_verification")
    monkeypatch.setattr(
        zkp_module.subprocess, "run",
        lambda *a, **k: SimpleNamespace(returncode=0, stdout="[INFO] snarkJS: OK!", stderr=""),
    )
    result = ZKPVerifier(keys_dir=str(tmp_path)).verify_proof("age_verification", PROOF, SIGNALS)
    assert result["valid"] is True


def test_snarkjs_failure_rejected(tmp_path, monkeypatch):
    _write_vkey(tmp_path, "age_verification")
    monkeypatch.setattr(
        zkp_module.subprocess, "run",
        lambda *a, **k: SimpleNamespace(returncode=1, stdout="", stderr="Invalid proof"),
    )
    result = ZKPVerifier(keys_dir=str(tmp_path)).verify_proof("age_verification", PROOF, SIGNALS)
    assert result["valid"] is False
    assert "Invalid proof" in result["error"]


def test_valid_signal_alone_is_not_enough(tmp_path, monkeypatch):
    """public_signals[0]==1 不能當通過條件（舊模擬路徑的漏洞）。"""
    def _boom(*_a, **_k):
        raise AssertionError("不應呼叫 snarkjs")
    monkeypatch.setattr(zkp_module.subprocess, "run", _boom)

    verifier = ZKPVerifier(keys_dir=str(tmp_path))
    result = verifier.verify_proof("license_verification", PROOF, [1])
    assert result["valid"] is False
