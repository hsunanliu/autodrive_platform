"""
WebSocket 依賴注入
提供全局訪問 WebSocket 通知器的方式
"""
from typing import Optional
from app.websocket.notifier import WebSocketNotifier

# 全局變數，將在 main.py 中初始化
_notifier: Optional[WebSocketNotifier] = None


def set_notifier(notifier: WebSocketNotifier):
    """
    設置全局通知器實例

    Args:
        notifier: WebSocketNotifier 實例
    """
    global _notifier
    _notifier = notifier


def get_notifier() -> Optional[WebSocketNotifier]:
    """
    獲取全局通知器實例

    Returns:
        WebSocketNotifier 實例，如果未初始化則返回 None
    """
    return _notifier
