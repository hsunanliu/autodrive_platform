"""walrus_service：上傳/讀取/content-hash 校驗；hash 不符必須拋錯且不重試。"""
import hashlib

import httpx
import pytest

import app.services.walrus_service as walrus_module
from app.services.walrus_service import WalrusError, WalrusService

DATA = b"gps-trajectory-bytes"


class _FakeResponse:
    def __init__(self, json_data=None, content=b"", status_error=None):
        self._json = json_data
        self.content = content
        self._status_error = status_error

    def raise_for_status(self):
        if self._status_error:
            raise self._status_error

    def json(self):
        return self._json


class _FakeAsyncClient:
    """替身 httpx.AsyncClient：以類別屬性注入回應與記錄呼叫次數。"""

    response = None
    exception = None
    calls = 0

    def __init__(self, *args, **kwargs):
        pass

    async def __aenter__(self):
        return self

    async def __aexit__(self, *exc):
        return False

    async def put(self, url, content=None):
        return await self._respond()

    async def get(self, url):
        return await self._respond()

    async def _respond(self):
        type(self).calls += 1
        if type(self).exception:
            raise type(self).exception
        return type(self).response


@pytest.fixture
def fake_http(monkeypatch):
    _FakeAsyncClient.response = None
    _FakeAsyncClient.exception = None
    _FakeAsyncClient.calls = 0
    monkeypatch.setattr(httpx, "AsyncClient", _FakeAsyncClient)

    async def _no_sleep(_seconds):
        pass
    monkeypatch.setattr(walrus_module.asyncio, "sleep", _no_sleep)
    return _FakeAsyncClient


def _service(**over):
    kw = dict(
        publisher_url="http://fake-publisher",
        aggregator_url="http://fake-aggregator",
        epochs=1,
        max_retries=3,
    )
    kw.update(over)
    return WalrusService(**kw)


async def test_store_returns_blob_id_and_sha256(fake_http):
    fake_http.response = _FakeResponse(
        json_data={"newlyCreated": {"blobObject": {"blobId": "blob-abc"}}}
    )
    result = await _service().store(DATA)
    assert result["blob_id"] == "blob-abc"
    assert result["content_hash"] == hashlib.sha256(DATA).digest()
    assert result["content_hash_hex"] == hashlib.sha256(DATA).hexdigest()
    assert result["size"] == len(DATA)


async def test_store_already_certified_path(fake_http):
    fake_http.response = _FakeResponse(json_data={"alreadyCertified": {"blobId": "blob-xyz"}})
    result = await _service().store(DATA)
    assert result["blob_id"] == "blob-xyz"


async def test_store_empty_data_rejected(fake_http):
    with pytest.raises(WalrusError, match="空資料"):
        await _service().store(b"")
    assert fake_http.calls == 0


async def test_store_retries_then_raises(fake_http):
    fake_http.exception = ConnectionError("publisher unreachable")
    with pytest.raises(WalrusError, match="重試耗盡"):
        await _service(max_retries=2).store(DATA)
    assert fake_http.calls == 2


async def test_read_hash_match_returns_data(fake_http):
    fake_http.response = _FakeResponse(content=DATA)
    data = await _service().read("blob-abc", expected_hash=hashlib.sha256(DATA).digest())
    assert data == DATA


async def test_read_hash_mismatch_raises_without_retry(fake_http):
    fake_http.response = _FakeResponse(content=b"tampered-bytes")
    with pytest.raises(WalrusError, match="不符"):
        await _service().read("blob-abc", expected_hash=hashlib.sha256(DATA).digest())
    assert fake_http.calls == 1  # 雜湊不符不得重試
