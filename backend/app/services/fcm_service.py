"""
Firebase Cloud Messaging (FCM) 推送通知服務
用於向司機和乘客發送即時推送通知
"""
import logging
import httpx
from typing import Optional, Dict, Any
from app.config import settings

logger = logging.getLogger(__name__)


class FCMService:
    """Firebase Cloud Messaging 推送通知服務"""

    def __init__(self):
        """初始化 FCM 服務"""
        self.fcm_url = "https://fcm.googleapis.com/fcm/send"
        self.server_key = getattr(settings, 'FCM_SERVER_KEY', None)

        if not self.server_key:
            logger.warning("⚠️ FCM_SERVER_KEY 未配置，推送通知功能將無法使用")

    async def send_notification(
        self,
        fcm_token: str,
        title: str,
        body: str,
        data: Optional[Dict[str, Any]] = None,
        priority: str = "high"
    ) -> bool:
        """
        發送推送通知到指定設備

        Args:
            fcm_token: 目標設備的 FCM Token
            title: 通知標題
            body: 通知內容
            data: 自定義數據（可選）
            priority: 優先級（"high" 或 "normal"）

        Returns:
            bool: 是否發送成功
        """
        if not self.server_key:
            logger.error("❌ FCM_SERVER_KEY 未配置，無法發送推送通知")
            return False

        if not fcm_token:
            logger.error("❌ FCM Token 為空")
            return False

        headers = {
            "Authorization": f"key={self.server_key}",
            "Content-Type": "application/json"
        }

        payload = {
            "to": fcm_token,
            "notification": {
                "title": title,
                "body": body,
                "sound": "default",
                "badge": "1"
            },
            "data": data or {},
            "priority": priority,
            # Android 特定配置
            "android": {
                "priority": priority,
                "notification": {
                    "sound": "default",
                    "channel_id": "autodrive_orders"
                }
            },
            # iOS 特定配置
            "apns": {
                "payload": {
                    "aps": {
                        "sound": "default",
                        "badge": 1,
                        "alert": {
                            "title": title,
                            "body": body
                        }
                    }
                }
            }
        }

        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    self.fcm_url,
                    json=payload,
                    headers=headers,
                    timeout=10.0
                )

                if response.status_code == 200:
                    result = response.json()
                    if result.get("success") == 1:
                        logger.info(f"✅ 推送通知發送成功: {title}")
                        return True
                    else:
                        logger.error(f"❌ 推送通知發送失敗: {result}")
                        return False
                else:
                    logger.error(f"❌ FCM API 請求失敗: {response.status_code} - {response.text}")
                    return False

        except Exception as e:
            logger.error(f"❌ 發送推送通知時發生錯誤: {e}")
            return False

    async def send_new_trip_notification(
        self,
        fcm_token: str,
        trip_id: int,
        pickup_address: str,
        dropoff_address: str,
        estimated_earnings: float
    ) -> bool:
        """
        發送新訂單通知給司機

        Args:
            fcm_token: 司機的 FCM Token
            trip_id: 行程 ID
            pickup_address: 上車地點
            dropoff_address: 下車地點
            estimated_earnings: 預估收益（SUI）

        Returns:
            bool: 是否發送成功
        """
        title = "🚗 新訂單"
        body = f"從 {pickup_address[:20]}... 到 {dropoff_address[:20]}..."

        data = {
            "type": "new_trip",
            "trip_id": str(trip_id),
            "pickup_address": pickup_address,
            "dropoff_address": dropoff_address,
            "estimated_earnings": str(estimated_earnings)
        }

        return await self.send_notification(fcm_token, title, body, data)

    async def send_trip_status_notification(
        self,
        fcm_token: str,
        trip_id: int,
        status: str,
        message: str
    ) -> bool:
        """
        發送行程狀態更新通知

        Args:
            fcm_token: 用戶的 FCM Token
            trip_id: 行程 ID
            status: 行程狀態
            message: 通知訊息

        Returns:
            bool: 是否發送成功
        """
        status_titles = {
            "accepted": "✅ 司機已接單",
            "started": "🚗 行程已開始",
            "arrived": "📍 司機已到達",
            "completed": "🎉 行程已完成",
            "cancelled": "❌ 行程已取消"
        }

        title = status_titles.get(status, "📱 行程更新")

        data = {
            "type": "trip_status",
            "trip_id": str(trip_id),
            "status": status
        }

        return await self.send_notification(fcm_token, title, message, data)

    async def send_driver_arrived_notification(
        self,
        fcm_token: str,
        trip_id: int,
        driver_name: str
    ) -> bool:
        """
        通知乘客司機已到達

        Args:
            fcm_token: 乘客的 FCM Token
            trip_id: 行程 ID
            driver_name: 司機姓名

        Returns:
            bool: 是否發送成功
        """
        title = "📍 司機已到達"
        body = f"{driver_name} 已到達您的上車地點，請準備上車"

        data = {
            "type": "driver_arrived",
            "trip_id": str(trip_id),
            "driver_name": driver_name
        }

        return await self.send_notification(fcm_token, title, body, data)


# 全局單例
fcm_service = FCMService()
