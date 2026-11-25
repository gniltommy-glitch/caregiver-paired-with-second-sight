"""SecondSight Caregiver Relay & Reference Bridge Server (Protocol v1).

Kết nối 3 thành phần trong hệ sinh thái The Second Sight:
  1. Kính thông minh (smart_glass_v2 trên Raspberry Pi 5)
  2. Ứng dụng người khiếm thị (the_second_sight_mobile_app)
  3. Ứng dụng người thân (SecondSight Caregiver)

Nguyên tắc thiết kế:
  - Không truyền video liên tục (giữ nhẹ băng thông và tránh quá nhiệt Pi 5).
  - Chỉ truyền ảnh tĩnh JPEG theo yêu cầu ("Ask My Person" / SOS), trạng thái
    phần cứng (device_status), hành trình đang đi (privacy-first: chỉ chia sẻ khi
    state == 'navigating' hoặc có SOS), cảnh báo bất thường và gợi ý điểm đến.
  - Xác thực Bearer token trong HTTP header (Authorization: Bearer <token>).
"""
from __future__ import annotations

import argparse
import asyncio
import json
import logging
import os
import secrets
from datetime import datetime, timezone
from typing import Any

from aiohttp import WSMsgType, web


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


class CaregiverRelayHub:
    def __init__(self, token: str, demo_mode: bool = False) -> None:
        self.token = token
        self.demo_mode = demo_mode
        self.caregiver_peers: set[web.WebSocketResponse] = set()
        self.wearer_peers: set[web.WebSocketResponse] = set()

        self.nav_state: dict[str, Any] = {
            "protocol": 1,
            "session_id": None,
            "revision": 0,
            "state": "idle",
            "route": None,
            "position": None,
            "gps_valid": False,
            "accuracy_m": None,
            "step_index": 0,
            "updated_at": utc_now_iso(),
        }
        self.device_status: dict[str, Any] = {
            "type": "device_status",
            "demo": demo_mode,
            "yolo_fps": 18.2 if demo_mode else 0.0,
            "cpu_temp": 61.5 if demo_mode else None,
            "battery_percent": 82 if demo_mode else None,
            "camera_ok": True,
            "lidar_ok": True,
            "stm32_ok": True,
            "stm32_calibrated": True,
            "stm32_heading": 92.0,
            "stm32_pitch": 1.2,
            "stm32_roll": -0.6,
            "updated_at": utc_now_iso(),
        }
        self.assist_requests: list[dict[str, Any]] = []
        self.active_sos: dict[str, Any] | None = None
        self.pending_destinations: list[dict[str, Any]] = []
        self.anomalies: list[dict[str, Any]] = []

    def snapshot_for_caregiver(self) -> dict[str, Any]:
        """Trả về snapshot tôn trọng quyền riêng tư: ẩn vị trí nếu không navigating/SOS."""
        sharing_active = (
            self.nav_state.get("state") == "navigating"
            or self.active_sos is not None
        )
        sanitized_nav = dict(self.nav_state)
        if not sharing_active:
            sanitized_nav["position"] = None
            sanitized_nav["route"] = None

        return {
            "type": "caregiver_snapshot",
            "protocol": 1,
            "demo": self.demo_mode,
            "sharing_active": sharing_active,
            "wearer_online": len(self.wearer_peers) > 0 or self.demo_mode,
            "caregivers_online": len(self.caregiver_peers),
            "navigation": sanitized_nav,
            "device_status": self.device_status,
            "active_sos": self.active_sos,
            "assist_requests": self.assist_requests[-20:],
            "pending_destinations": self.pending_destinations[-10:],
            "anomalies": self.anomalies[-20:],
            "server_time": utc_now_iso(),
        }

    async def broadcast(
        self,
        payload: dict[str, Any],
        *,
        to_caregivers: bool = True,
        to_wearers: bool = False,
    ) -> None:
        targets: list[tuple[set[web.WebSocketResponse], web.WebSocketResponse]] = []
        if to_caregivers:
            targets.extend((self.caregiver_peers, ws) for ws in list(self.caregiver_peers))
        if to_wearers:
            targets.extend((self.wearer_peers, ws) for ws in list(self.wearer_peers))

        for pool, ws in targets:
            try:
                await ws.send_json(payload)
            except Exception:
                pool.discard(ws)

    async def ws_handler(self, request: web.Request) -> web.WebSocketResponse:
        role = request.query.get("role", "caregiver").strip().lower()
        if role not in {"caregiver", "wearer", "glass"}:
            raise web.HTTPBadRequest(text="Tham số role phải là caregiver, wearer hoặc glass")

        ws = web.WebSocketResponse(max_msg_size=4 * 1024 * 1024, heartbeat=15)
        await ws.prepare(request)

        pool = self.caregiver_peers if role == "caregiver" else self.wearer_peers
        pool.add(ws)
        logging.info("Client WebSocket đã kết nối: role=%s", role)

        try:
            if role == "caregiver":
                await ws.send_json(self.snapshot_for_caregiver())
            await self.broadcast(
                {
                    "type": "presence_update",
                    "wearer_online": len(self.wearer_peers) > 0 or self.demo_mode,
                    "caregivers_online": len(self.caregiver_peers),
                    "timestamp": utc_now_iso(),
                },
                to_caregivers=True,
                to_wearers=True,
            )

            async for frame in ws:
                if frame.type != WSMsgType.TEXT:
                    continue
                try:
                    msg = json.loads(frame.data)
                except ValueError:
                    continue
                if not isinstance(msg, dict):
                    continue
                await self._handle_ws_message(ws, role, msg)
        finally:
            pool.discard(ws)
            await self.broadcast(
                {
                    "type": "presence_update",
                    "wearer_online": len(self.wearer_peers) > 0 or self.demo_mode,
                    "caregivers_online": len(self.caregiver_peers),
                    "timestamp": utc_now_iso(),
                },
                to_caregivers=True,
                to_wearers=True,
            )
        return ws

    async def _handle_ws_message(
        self,
        ws: web.WebSocketResponse,
        role: str,
        msg: dict[str, Any],
    ) -> None:
        mtype = msg.get("type")
        if mtype == "ping":
            await ws.send_json({"type": "pong", "server_time": utc_now_iso()})
            return

        if mtype == "device_status" and role in {"wearer", "glass"}:
            self.device_status.update(msg)
            self.device_status["updated_at"] = utc_now_iso()
            await self.broadcast(self.device_status, to_caregivers=True)
            return

        if mtype == "navigation_instruction" and role in {"wearer", "glass"}:
            self.nav_state["position"] = msg.get("position")
            self.nav_state["gps_valid"] = bool(msg.get("gps_valid", False))
            self.nav_state["accuracy_m"] = msg.get("accuracy_m")
            self.nav_state["step_index"] = msg.get("step_index", 0)
            self.nav_state["updated_at"] = utc_now_iso()
            if self.nav_state.get("state") == "navigating" or self.active_sos is not None:
                await self.broadcast(
                    {
                        "type": "position_update",
                        "position": msg.get("position"),
                        "accuracy_m": msg.get("accuracy_m"),
                        "step_index": msg.get("step_index", 0),
                        "distance_m": msg.get("distance_m"),
                        "street": msg.get("street", ""),
                        "text": msg.get("text", ""),
                        "updated_at": self.nav_state["updated_at"],
                    },
                    to_caregivers=True,
                )
            return

        if mtype in {"hazard", "obstacle_avoid", "path_blocked", "anomaly_alert"}:
            record = {**msg, "received_at": utc_now_iso()}
            self.anomalies.append(record)
            await self.broadcast(record, to_caregivers=True)
            return

        if mtype == "caregiver_reply" and role == "caregiver":
            await self._record_assist_reply(msg)
            return

        if mtype == "destination_suggestion" and role == "caregiver":
            await self._record_destination_suggestion(msg)
            return

    async def _record_assist_reply(self, data: dict[str, Any]) -> dict[str, Any]:
        req_id = str(data.get("request_id", "")).strip()
        text = str(data.get("reply_text", "")).strip()
        if not req_id or not text:
            raise web.HTTPBadRequest(text="Thiếu request_id hoặc reply_text")

        reply_event = {
            "type": "caregiver_reply",
            "request_id": req_id,
            "reply_text": text[:500],
            "sender_name": str(data.get("sender_name", "Người thân"))[:80],
            "speak_immediately": bool(data.get("speak_immediately", True)),
            "replied_at": utc_now_iso(),
        }
        for item in self.assist_requests:
            if item.get("request_id") == req_id:
                item["status"] = "replied"
                item["reply"] = reply_event
                break

        await self.broadcast(reply_event, to_caregivers=True, to_wearers=True)
        return reply_event

    async def _record_destination_suggestion(self, data: dict[str, Any]) -> dict[str, Any]:
        name = str(data.get("name", "")).strip()
        point = data.get("point")
        if (
            not name
            or not isinstance(point, list)
            or len(point) != 2
            or not all(isinstance(v, (int, float)) for v in point)
        ):
            raise web.HTTPBadRequest(text="Điểm đến phải có name và tọa độ [lon, lat]")

        suggestion = {
            "type": "destination_suggestion",
            "suggestion_id": str(data.get("suggestion_id") or secrets.token_hex(8)),
            "name": name[:140],
            "address": str(data.get("address", ""))[:240],
            "point": [float(point[0]), float(point[1])],
            "note": str(data.get("note", ""))[:240],
            "sender_name": str(data.get("sender_name", "Người thân"))[:80],
            "requires_wearer_confirmation": True,
            "status": "pending_confirmation",
            "created_at": utc_now_iso(),
        }
        self.pending_destinations.append(suggestion)
        await self.broadcast(suggestion, to_caregivers=True, to_wearers=True)
        return suggestion

    # ─── HTTP Endpoints ───────────────────────────────────────────────

    async def get_status(self, _: web.Request) -> web.Response:
        return web.json_response(self.snapshot_for_caregiver())

    async def post_navigation_state(self, request: web.Request) -> web.Response:
        try:
            data = await request.json()
            assert isinstance(data, dict)
            assert data.get("state") in {"idle", "ready", "navigating", "paused", "arrived"}
        except Exception as exc:
            raise web.HTTPBadRequest(text="Snapshot trạng thái dẫn đường không hợp lệ") from exc

        self.nav_state.update(data)
        self.nav_state["updated_at"] = utc_now_iso()
        await self.broadcast(self.snapshot_for_caregiver(), to_caregivers=True)
        return web.json_response({"ok": True, "revision": self.nav_state.get("revision", 0)})

    async def post_assist_request(self, request: web.Request) -> web.Response:
        try:
            data = await request.json()
            assert isinstance(data, dict)
        except Exception as exc:
            raise web.HTTPBadRequest(text="Yêu cầu hỗ trợ không hợp lệ") from exc

        item = {
            "type": "assist_request",
            "request_id": str(data.get("request_id") or secrets.token_hex(8)),
            "question": str(data.get("question") or "Người dùng gửi ảnh nhờ kiểm tra phía trước.")[:300],
            "context_note": str(data.get("context_note") or "")[:300],
            "position": data.get("position") or self.nav_state.get("position"),
            "accuracy_m": data.get("accuracy_m") or self.nav_state.get("accuracy_m"),
            "image_base64": data.get("image_base64"),
            "scene_kind": str(data.get("scene_kind") or "crosswalk"),
            "detections": data.get("detections") or [],
            "tof_min_m": data.get("tof_min_m"),
            "status": "pending",
            "created_at": utc_now_iso(),
        }
        self.assist_requests.append(item)
        await self.broadcast(item, to_caregivers=True)
        return web.json_response({"ok": True, "request_id": item["request_id"]})

    async def post_assist_reply(self, request: web.Request) -> web.Response:
        try:
            data = await request.json()
            assert isinstance(data, dict)
        except Exception as exc:
            raise web.HTTPBadRequest(text="Dữ liệu phản hồi không hợp lệ") from exc
        reply = await self._record_assist_reply(data)
        return web.json_response({"ok": True, "reply": reply})

    async def post_sos_trigger(self, request: web.Request) -> web.Response:
        try:
            data = await request.json()
            assert isinstance(data, dict)
        except Exception:
            data = {}

        sos = {
            "type": "sos_alert",
            "sos_id": str(data.get("sos_id") or secrets.token_hex(8)),
            "trigger": str(data.get("trigger") or "voice_or_button"),
            "message": str(data.get("message") or "Người dùng kích hoạt tín hiệu khẩn cấp SOS!"),
            "position": data.get("position") or self.nav_state.get("position") or [106.6662, 10.7553],
            "accuracy_m": data.get("accuracy_m") or 4.5,
            "image_base64": data.get("image_base64"),
            "scene_kind": str(data.get("scene_kind") or "sos_street"),
            "battery_percent": self.device_status.get("battery_percent"),
            "active": True,
            "created_at": utc_now_iso(),
        }
        self.active_sos = sos
        await self.broadcast(sos, to_caregivers=True, to_wearers=True)
        return web.json_response({"ok": True, "sos": sos})

    async def post_sos_resolve(self, request: web.Request) -> web.Response:
        try:
            data = await request.json()
            assert isinstance(data, dict)
        except Exception:
            data = {}

        resolved_by = str(data.get("resolved_by") or "Người thân")[:80]
        sos_id = self.active_sos.get("sos_id") if self.active_sos else data.get("sos_id")
        self.active_sos = None
        payload = {
            "type": "sos_resolved",
            "sos_id": sos_id,
            "resolved_by": resolved_by,
            "resolved_at": utc_now_iso(),
        }
        await self.broadcast(payload, to_caregivers=True, to_wearers=True)
        return web.json_response({"ok": True, **payload})

    async def post_destination_suggest(self, request: web.Request) -> web.Response:
        try:
            data = await request.json()
            assert isinstance(data, dict)
        except Exception as exc:
            raise web.HTTPBadRequest(text="Dữ liệu điểm đến không hợp lệ") from exc
        suggestion = await self._record_destination_suggestion(data)
        return web.json_response({"ok": True, "suggestion": suggestion})


def create_relay_app(hub: CaregiverRelayHub, token: str) -> web.Application:
    @web.middleware
    async def auth_middleware(request: web.Request, handler: Any) -> web.StreamResponse:
        auth = request.headers.get("Authorization", "")
        if not secrets.compare_digest(auth, f"Bearer {token}"):
            raise web.HTTPUnauthorized(text="Yêu cầu Bearer token hợp lệ của SecondSight")
        return await handler(request)

    app = web.Application(middlewares=[auth_middleware], client_max_size=6 * 1024 * 1024)
    app.router.add_get("/ws", hub.ws_handler)
    app.router.add_get("/status", hub.get_status)
    app.router.add_get("/device/status", hub.get_status)
    app.router.add_post("/navigation/state", hub.post_navigation_state)
    app.router.add_post("/assist/request", hub.post_assist_request)
    app.router.add_post("/assist/reply", hub.post_assist_reply)
    app.router.add_post("/sos/trigger", hub.post_sos_trigger)
    app.router.add_post("/sos/resolve", hub.post_sos_resolve)
    app.router.add_post("/destination/suggest", hub.post_destination_suggest)
    return app


def main() -> None:
    parser = argparse.ArgumentParser(description="SecondSight Caregiver Relay Server")
    parser.add_argument("--host", default="0.0.0.0", help="Địa chỉ lắng nghe (mặc định: 0.0.0.0)")
    parser.add_argument("--port", type=int, default=8787, help="Cổng lắng nghe (mặc định: 8787)")
    parser.add_argument("--demo", action="store_true", help="Bật cờ dữ liệu mô phỏng")
    args = parser.parse_args()

    token = os.environ.get("SECONDSIGHT_TOKEN", "").strip()
    if len(token) < 24:
        raise SystemExit(
            "Thiếu biến môi trường SECONDSIGHT_TOKEN (tối thiểu 24 ký tự). "
            "Tạo nhanh bằng: export SECONDSIGHT_TOKEN=$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')"
        )

    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
    hub = CaregiverRelayHub(token=token, demo_mode=args.demo)
    app = create_relay_app(hub, token=token)
    logging.info("Khởi chạy SecondSight Caregiver Relay trên %s:%d", args.host, args.port)
    web.run_app(app, host=args.host, port=args.port)


if __name__ == "__main__":
    main()
