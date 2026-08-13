"""
行車軌跡服務

即時 GPS 目前只透過 Socket.IO 廣播、不落地。本服務在記憶體累積每趟的 GPS breadcrumb，
行程結束時序列化上傳 Walrus，回傳 blob_id 與 content_hash 供 TripReceipt 上鏈錨定。
鏈上只存 blob_id + hash，完整軌跡留在 Walrus，讀取時比對 hash 確保完整性。

注意：記憶體緩衝適合單機/開發。多實例部署時應改用 Redis 之類的共享緩衝
（介面不變，替換 _buffers 的實作即可）。
"""

import json
import logging
from typing import Any, Dict, List, Optional

from app.services.walrus_service import walrus_service, WalrusError

logger = logging.getLogger(__name__)

# 軌跡屬 PII，一律加密後才上 Walrus（威脅 T4）。缺加密金鑰時**不明文上傳**（fail-safe）。


class TrajectoryService:
    def __init__(self):
        # trip_id -> list[{lat, lng, ts}]
        self._buffers: Dict[int, List[Dict[str, Any]]] = {}

    def record(self, trip_id: int, lat: float, lng: float, timestamp: Any = None) -> None:
        """記錄一個 GPS 點（由 websocket update_location 呼叫）。"""
        if trip_id is None:
            return
        self._buffers.setdefault(int(trip_id), []).append(
            {"lat": lat, "lng": lng, "ts": timestamp}
        )

    def point_count(self, trip_id: int) -> int:
        return len(self._buffers.get(int(trip_id), []))

    def discard(self, trip_id: int) -> None:
        """丟棄緩衝（例如行程取消，不需保存軌跡）。"""
        self._buffers.pop(int(trip_id), None)

    async def flush_to_walrus(
        self, trip_id: int, recipient_pubs: Optional[List[bytes]] = None
    ) -> Optional[Dict[str, Any]]:
        """
        將該趟軌跡**加密後**上傳 Walrus 並清空緩衝。

        Args:
            recipient_pubs: 授權解密者的 X25519 公鑰（乘客/司機[/稽核]）。
                            缺此參數則**不上傳**（fail-safe，拒絕明文 PII 上公網）。

        Returns:
            None：無軌跡點，或缺加密金鑰而略過。
            {"blob_id","content_hash","content_hash_hex","nonce","wrapped_deks","point_count"}：成功。

        Raises:
            WalrusError: 上傳失敗（呼叫端決定重試或延後）。
        """
        points = self._buffers.get(int(trip_id), [])
        if not points:
            self._buffers.pop(int(trip_id), None)
            return None

        if not recipient_pubs:
            # 沒有收件者公鑰就不上傳——絕不把 GPS 軌跡明文送上公開 Walrus。
            # （金鑰派送：為每位用戶配發 X25519 加密公鑰，屬後續工作。）
            logger.warning(
                "行程 %s 軌跡略過上傳：缺收件者加密金鑰，拒絕明文 PII 上傳", trip_id
            )
            return None

        payload = json.dumps(
            {"trip_id": int(trip_id), "points": points},
            separators=(",", ":"),
            ensure_ascii=False,
        ).encode("utf-8")

        try:
            result = await walrus_service.store_encrypted(
                payload, recipient_pubs, aad=f"trip:{int(trip_id)}".encode()
            )
        except WalrusError:
            raise  # 資料仍在緩衝，未 pop

        # 成功才清緩衝
        self._buffers.pop(int(trip_id), None)
        logger.info(
            "🛰️ 行程 %s 軌跡已加密上傳 Walrus blob=%s 點數=%d",
            trip_id, result["blob_id"], len(points),
        )
        return {
            "blob_id": result["blob_id"],
            "content_hash": result["content_hash"],
            "content_hash_hex": result["content_hash_hex"],
            "nonce": result["nonce"],
            "wrapped_deks": result["wrapped_deks"],
            "point_count": len(points),
        }


# 全局單例
trajectory_service = TrajectoryService()
