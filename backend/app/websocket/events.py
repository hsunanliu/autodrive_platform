"""
WebSocket 事件處理器
定義所有 Socket.IO 事件的處理邏輯
"""
import socketio
from typing import Dict, Any
import logging
from app.websocket.manager import ConnectionManager
from app.core.database import async_session_maker
from app.models.user import User
from sqlalchemy import select

logger = logging.getLogger(__name__)


def register_socketio_events(sio: socketio.AsyncServer, manager: ConnectionManager):
    """
    註冊所有 Socket.IO 事件處理器

    Args:
        sio: Socket.IO 伺服器實例
        manager: 連接管理器實例
    """

    @sio.event
    async def connect(sid: str, environ: Dict, auth: Dict = None):
        """
        處理客戶端連接事件

        Args:
            sid: Socket ID
            environ: 環境變數
            auth: 認證資料（可選）
        """
        try:
            logger.info(f"🔌 客戶端嘗試連接: {sid}")
            logger.info(f"🔍 auth 參數: {auth}")
            logger.info(f"🔍 environ keys: {list(environ.keys())[:10]}")  # 只顯示前10個key

            # 嘗試從多個來源獲取 token
            token = None

            # 1. 從 auth 參數獲取（Socket.IO 標準方式）
            if auth and isinstance(auth, dict) and auth.get("token"):
                token = auth.get("token")
                logger.info(f"✅ 從 auth 參數獲取 token (長度: {len(token)})")

            # 2. 從查詢參數獲取
            if not token:
                query_string = environ.get('QUERY_STRING', '')
                logger.info(f"🔍 查詢字串: {query_string[:100]}")  # 只顯示前100字符
                from urllib.parse import parse_qs
                query_params = parse_qs(query_string)
                if 'token' in query_params:
                    token = query_params['token'][0]
                    logger.info(f"✅ 從查詢參數獲取 token (長度: {len(token)})")

            # 3. 從 HTTP headers 獲取
            if not token:
                headers = environ.get('HTTP_AUTHORIZATION', '')
                if headers.startswith('Bearer '):
                    token = headers[7:]
                    logger.info(f"✅ 從 Authorization header 獲取 token")

            if not token:
                logger.error(f"❌ 連接 {sid} 缺少 token")
                logger.error(f"❌ auth={auth}, query_string={environ.get('QUERY_STRING', '')[:100]}")
                raise ConnectionRefusedError("缺少認證 token")

            user_id = manager.verify_token(token)
            if not user_id:
                logger.error(f"❌ 連接 {sid} 的 token 無效")
                raise ConnectionRefusedError("無效的認證 token")

            # 註冊連接
            await manager.connect_user(sid, user_id)

            # 發送連接成功訊息
            await sio.emit("connected", {"user_id": user_id, "message": "連接成功"}, room=sid)
            logger.info(f"✅ 用戶 {user_id} 連接成功，Socket ID: {sid}")

        except ConnectionRefusedError as e:
            logger.error(f"❌ 拒絕連接 {sid}: {e}")
            raise
        except Exception as e:
            logger.error(f"❌ 連接處理異常 {sid}: {e}")
            logger.exception("詳細錯誤:")
            raise ConnectionRefusedError(f"連接處理失敗: {str(e)}")

    @sio.event
    async def disconnect(sid: str):
        """
        處理客戶端斷開連接事件

        Args:
            sid: Socket ID
        """
        user_id = manager.get_user_id(sid)
        logger.info(f"客戶端斷開連接: {sid}, 用戶 ID: {user_id}")
        await manager.disconnect_user(sid)

    @sio.event
    async def join_trip(sid: str, data: Dict[str, Any]):
        """
        加入行程房間

        Args:
            sid: Socket ID
            data: 包含 trip_id 的資料
        """
        logger.info(f"🔍 [DEBUG] join_trip 被調用！sid={sid}, data={data}")
        user_id = manager.get_user_id(sid)
        logger.info(f"🔍 [DEBUG] user_id={user_id}")
        trip_id = data.get("trip_id")

        if not trip_id:
            logger.error(f"用戶 {user_id} 嘗試加入房間但缺少 trip_id")
            await sio.emit("error", {"message": "缺少 trip_id"}, room=sid)
            return

        room_name = f"trip_{trip_id}"
        logger.info(f"🔍 [DEBUG] 準備加入房間: {room_name}")
        success = await manager.join_room(sid, room_name)
        logger.info(f"🔍 [DEBUG] 加入房間結果: {success}")

        if success:
            await sio.emit(
                "joined_trip",
                {"trip_id": trip_id, "message": f"成功加入行程 {trip_id}"},
                room=sid
            )
            logger.info(f"✅ 用戶 {user_id} 成功加入行程房間 {room_name}")
        else:
            await sio.emit("error", {"message": "加入房間失敗"}, room=sid)
            logger.error(f"❌ 用戶 {user_id} 加入房間 {room_name} 失敗")

    @sio.event
    async def leave_trip(sid: str, data: Dict[str, Any]):
        """
        離開行程房間

        Args:
            sid: Socket ID
            data: 包含 trip_id 的資料
        """
        user_id = manager.get_user_id(sid)
        trip_id = data.get("trip_id")

        if not trip_id:
            logger.error(f"用戶 {user_id} 嘗試離開房間但缺少 trip_id")
            return

        room_name = f"trip_{trip_id}"
        await manager.leave_room(sid, room_name)

        await sio.emit(
            "left_trip",
            {"trip_id": trip_id, "message": f"已離開行程 {trip_id}"},
            room=sid
        )
        logger.info(f"用戶 {user_id} 離開行程房間 {room_name}")

    @sio.event
    async def update_location(sid: str, data: Dict[str, Any]):
        """
        更新司機位置（司機端發送）

        Args:
            sid: Socket ID
            data: 包含 trip_id, lat, lng, timestamp 的資料
        """
        user_id = manager.get_user_id(sid)
        trip_id = data.get("trip_id")
        lat = data.get("lat")
        lng = data.get("lng")
        timestamp = data.get("timestamp")

        if not all([trip_id, lat, lng]):
            logger.error(f"用戶 {user_id} 位置更新資料不完整")
            await sio.emit("error", {"message": "位置資料不完整"}, room=sid)
            return

        # 累積軌跡 breadcrumb（行程結束時上傳 Walrus，見 trajectory_service）
        from app.services.trajectory_service import trajectory_service
        trajectory_service.record(trip_id, lat, lng, timestamp)

        # 廣播位置更新到行程房間（乘客會收到）
        room_name = f"trip_{trip_id}"
        await manager.emit_to_room(
            room_name,
            "driver_location_update",
            {
                "trip_id": trip_id,
                "driver_id": user_id,
                "lat": lat,
                "lng": lng,
                "timestamp": timestamp
            }
        )
        logger.debug(f"司機 {user_id} 更新位置: ({lat}, {lng}) 於行程 {trip_id}")

    @sio.event
    async def send_message(sid: str, data: Dict[str, Any]):
        """
        發送聊天訊息（未來功能）

        Args:
            sid: Socket ID
            data: 包含 trip_id, message 的資料
        """
        user_id = manager.get_user_id(sid)
        trip_id = data.get("trip_id")
        message = data.get("message")

        if not all([trip_id, message]):
            logger.error(f"用戶 {user_id} 訊息資料不完整")
            await sio.emit("error", {"message": "訊息資料不完整"}, room=sid)
            return

        room_name = f"trip_{trip_id}"
        await manager.emit_to_room(
            room_name,
            "new_message",
            {
                "trip_id": trip_id,
                "user_id": user_id,
                "message": message,
                "timestamp": data.get("timestamp")
            }
        )
        logger.info(f"用戶 {user_id} 在行程 {trip_id} 發送訊息")

    @sio.event
    async def join_drivers_room(sid: str, data: Dict[str, Any] = None):
        """
        司機加入在線司機房間（用於接收新訂單通知）

        Args:
            sid: Socket ID
            data: 可選資料
        """
        user_id = manager.get_user_id(sid)
        success = await manager.join_room(sid, "drivers_online")

        if success:
            await sio.emit(
                "joined_drivers_room",
                {"message": "已加入司機在線房間，可以接收新訂單通知"},
                room=sid
            )
            logger.info(f"司機 {user_id} 加入在線司機房間")
        else:
            await sio.emit("error", {"message": "加入司機房間失敗"}, room=sid)

    @sio.event
    async def leave_drivers_room(sid: str, data: Dict[str, Any] = None):
        """
        司機離開在線司機房間

        Args:
            sid: Socket ID
            data: 可選資料
        """
        user_id = manager.get_user_id(sid)
        await manager.leave_room(sid, "drivers_online")
        logger.info(f"司機 {user_id} 離開在線司機房間")

    @sio.event
    async def update_fcm_token(sid: str, data: Dict[str, Any]):
        """
        更新用戶的 FCM Token（用於推送通知）

        Args:
            sid: Socket ID
            data: 包含 fcm_token 的資料
        """
        user_id = manager.get_user_id(sid)
        fcm_token = data.get("fcm_token")

        if not fcm_token:
            logger.error(f"用戶 {user_id} 嘗試更新 FCM Token 但缺少 token")
            await sio.emit("error", {"message": "缺少 FCM Token"}, room=sid)
            return

        try:
            # 更新資料庫中的 FCM Token
            async with async_session_maker() as session:
                result = await session.execute(
                    select(User).where(User.id == user_id)
                )
                user = result.scalar_one_or_none()

                if user:
                    user.fcm_token = fcm_token
                    await session.commit()

                    await sio.emit(
                        "fcm_token_updated",
                        {"message": "FCM Token 更新成功"},
                        room=sid
                    )
                    logger.info(f"✅ 用戶 {user_id} FCM Token 更新成功: {fcm_token[:20]}...")
                else:
                    logger.error(f"❌ 找不到用戶 {user_id}")
                    await sio.emit("error", {"message": "用戶不存在"}, room=sid)

        except Exception as e:
            logger.error(f"❌ 更新 FCM Token 失敗: {e}")
            await sio.emit("error", {"message": f"更新失敗: {str(e)}"}, room=sid)

    @sio.event
    async def ping(sid: str, data: Dict[str, Any] = None):
        """
        心跳檢測

        Args:
            sid: Socket ID
            data: 可選資料
        """
        user_id = manager.get_user_id(sid)
        logger.info(f"💓 [DEBUG] ping 收到！sid={sid}, user_id={user_id}, data={data}")
        await sio.emit("pong", {"timestamp": data.get("timestamp") if data else None}, room=sid)
        logger.info(f"💓 [DEBUG] pong 已發送")

    logger.info("所有 Socket.IO 事件已註冊")
