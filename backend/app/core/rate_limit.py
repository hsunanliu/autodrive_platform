"""
輕量限流（Rate Limiting）— FastAPI 依賴

用途：擋經濟型 DoS（威脅 T6）。對觸發鏈上交易、Walrus 上傳、外部計費 API 的昂貴端點加上
每識別身分/IP 的請求上限。

實作說明：
  - 預設用「行程內記憶體滑動視窗」，零額外相依、可立即上線。
  - ⚠️ 記憶體版是**單行程**的；多實例部署時應改用 Redis（令牌桶）以跨實例共享計數。
    介面（`rate_limit(times, seconds, scope)` 依賴）不變，只需替換 `_Limiter` 實作。

用法：
    from app.core.rate_limit import rate_limit
    @router.post("/x", dependencies=[Depends(rate_limit(times=5, seconds=60, scope="pay"))])
"""

import time
from collections import defaultdict, deque
from typing import Deque, Dict

from fastapi import Request, HTTPException, status


class _Limiter:
    """滑動視窗計數器（單行程記憶體）。"""

    def __init__(self):
        self._hits: Dict[str, Deque[float]] = defaultdict(deque)

    def check(self, key: str, times: int, seconds: int) -> None:
        now = time.monotonic()
        cutoff = now - seconds
        dq = self._hits[key]
        while dq and dq[0] < cutoff:
            dq.popleft()
        if len(dq) >= times:
            retry_after = int(dq[0] + seconds - now) + 1
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="請求過於頻繁，請稍後再試",
                headers={"Retry-After": str(max(retry_after, 1))},
            )
        dq.append(now)


_limiter = _Limiter()


def _client_identity(request: Request) -> str:
    """
    識別呼叫者：優先用 Authorization token 尾段（已登入者以身分計數），
    否則退回來源 IP（匿名者以 IP 計數）。
    """
    auth = request.headers.get("authorization", "")
    if auth:
        return f"tok:{auth[-24:]}"
    client = request.client.host if request.client else "unknown"
    # 尊重反向代理的 X-Forwarded-For（取第一個）
    fwd = request.headers.get("x-forwarded-for")
    if fwd:
        client = fwd.split(",")[0].strip()
    return f"ip:{client}"


def rate_limit(times: int, seconds: int, scope: str = "default"):
    """回傳一個 FastAPI 依賴：在 `seconds` 秒內每識別身分最多 `times` 次，超過回 429。"""

    async def _dep(request: Request) -> None:
        key = f"{scope}:{_client_identity(request)}"
        _limiter.check(key, times, seconds)

    return _dep
