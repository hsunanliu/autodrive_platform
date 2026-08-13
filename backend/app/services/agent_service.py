"""
Agent Service — Agentic Web 的鏈上代理層

平台的自動化 Agent 以自己的金鑰（OPERATOR_PRIVATE_KEY）簽章，但**只能在用戶簽發的
OperatorCap 授權範圍內**代表用戶動用資金（見合約 `autodrive::agent_registry`）。
相較於舊做法「單一平台金鑰全權代理」，這裡的每一筆代發都受鏈上額度/時效/動作白名單約束，
金鑰外洩的爆炸半徑因此大幅縮小，也符合 Agentic Web 的自主代理精神。

決策層（報價/搓合）目前是規則式（`pricing_service`/`surge_pricing_service`/
`trip_service`），本服務只負責把「決策後的鏈上動作」以 OperatorCap + PTB 安全送出；
未來要換成 LLM 決策時，合約介面不需改動。

注意：鏈上呼叫失敗一律明確回報，**絕不**退回假交易 hash。
"""

import logging
from typing import Any, Dict, Optional

from app.config import settings

logger = logging.getLogger(__name__)

# Sui 系統時鐘的固定共享物件 ID
SUI_CLOCK_OBJECT_ID = "0x6"


class AgentService:
    def __init__(self):
        self.node_url = settings.SUI_NODE_URL
        self.package_id = settings.CONTRACT_PACKAGE_ID

    def _require_agent_key(self) -> Optional[str]:
        key = getattr(settings, "OPERATOR_PRIVATE_KEY", None)
        if not key:
            logger.error("❌ 缺少 OPERATOR_PRIVATE_KEY，Agent 無法簽章代發交易")
        return key

    def _build_client(self, agent_key: str):
        """建立以 Agent 金鑰簽章的 pysui 客戶端（與 sui_service 相同模式）。"""
        from pysui import SuiConfig, SyncClient

        cfg = SuiConfig.user_config(rpc_url=self.node_url, prv_keys=[agent_key])
        return SyncClient(cfg)

    async def release_escrow_via_agent(
        self,
        escrow_object_id: str,
        operator_cap_id: str,
        trip_id: int,
    ) -> Dict[str, Any]:
        """
        Agent 代表乘客釋放託管：呼叫 payment_escrow::release_payment_by_agent。
        需傳入該乘客簽發、允許 RELEASE_ESCROW 動作的 OperatorCap（operator_cap_id）。
        授權/額度/時效由合約端 authorize_action 檢查，任一不符即整筆 abort。
        """
        return self._call_escrow_agent_fn(
            "release_payment_by_agent",
            escrow_object_id,
            operator_cap_id,
            trip_id=trip_id,
        )

    async def refund_escrow_via_agent(
        self,
        escrow_object_id: str,
        operator_cap_id: str,
    ) -> Dict[str, Any]:
        """
        Agent 代表乘客退款：呼叫 payment_escrow::refund_payment_by_agent。
        需傳入該乘客簽發、允許 REFUND 動作的 OperatorCap。
        """
        return self._call_escrow_agent_fn(
            "refund_payment_by_agent",
            escrow_object_id,
            operator_cap_id,
        )

    def _call_escrow_agent_fn(
        self,
        function: str,
        escrow_object_id: str,
        operator_cap_id: str,
        trip_id: Optional[int] = None,
    ) -> Dict[str, Any]:
        """
        建構並送出 payment_escrow 的 agent 版函式呼叫。

        引數順序須對齊 Move 簽名：
          release_payment_by_agent(escrow, cap, trip_id, clock)
          refund_payment_by_agent(escrow, cap, clock)
        """
        agent_key = self._require_agent_key()
        if not agent_key:
            return {"success": False, "error": "缺少 OPERATOR_PRIVATE_KEY"}
        if not self.package_id:
            return {"success": False, "error": "缺少 CONTRACT_PACKAGE_ID"}

        # 送鏈前的護欄：object id 必須良構（擋自由文字/注入的髒參數，威脅 T8）
        from app.core.agent_guardrails import is_valid_object_id
        if not is_valid_object_id(escrow_object_id) or not is_valid_object_id(operator_cap_id):
            return {"success": False, "error": "非法 object id，拒絕代發交易"}

        try:
            from pysui.sui.sui_types.scalars import ObjectID, SuiU64
            from pysui.sui.sui_txn import SyncTransaction

            client = self._build_client(agent_key)
            txn = SyncTransaction(client=client)

            arguments = [ObjectID(escrow_object_id), ObjectID(operator_cap_id)]
            if trip_id is not None:
                arguments.append(SuiU64(trip_id))
            arguments.append(ObjectID(SUI_CLOCK_OBJECT_ID))

            txn.move_call(
                target=f"{self.package_id}::payment_escrow::{function}",
                arguments=arguments,
            )

            logger.info("🤖 Agent 送出 %s: escrow=%s cap=%s", function, escrow_object_id, operator_cap_id)
            result = txn.execute(gas_budget="10000000")

            if result.is_ok():
                digest = result.result_data.digest
                logger.info("✅ Agent 交易成功: %s", digest)
                return {"success": True, "transaction_hash": digest, "status": "confirmed"}

            error_msg = str(result.result_data)
            logger.error("❌ Agent 交易失敗: %s", error_msg)
            return {"success": False, "error": f"Agent 交易失敗: {error_msg}"}

        except ImportError as e:
            logger.error("❌ pysui 未安裝: %s", e)
            return {"success": False, "error": "pysui SDK 未安裝"}
        except Exception as e:  # noqa: BLE001
            # 不退回假 hash：鏈上失敗就明確回報
            logger.error("❌ Agent %s 失敗: %s", function, e)
            return {"success": False, "error": str(e)}


# 全局單例
agent_service = AgentService()
