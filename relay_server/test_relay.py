"""Unit tests cho SecondSight Caregiver Relay Server."""
from __future__ import annotations

import unittest
from aiohttp.test_utils import AioHTTPTestCase

from relay_server.server import CaregiverRelayHub, create_relay_app

TEST_TOKEN = "secondsight-test-token-0123456789abcdef"


class RelayServerTest(AioHTTPTestCase):
    async def get_application(self):
        self.hub = CaregiverRelayHub(token=TEST_TOKEN, demo_mode=False)
        return create_relay_app(self.hub, token=TEST_TOKEN)

    def _headers(self) -> dict[str, str]:
        return {"Authorization": f"Bearer {TEST_TOKEN}"}

    async def test_rejects_unauthenticated_request(self) -> None:
        resp = await self.client.request("GET", "/status")
        self.assertEqual(resp.status, 401)

    async def test_privacy_curtain_hides_location_when_idle(self) -> None:
        resp = await self.client.post(
            "/navigation/state",
            headers=self._headers(),
            json={
                "protocol": 1,
                "session_id": "s1",
                "revision": 1,
                "state": "idle",
                "position": [106.6662, 10.7553],
            },
        )
        self.assertEqual(resp.status, 200)

        status_resp = await self.client.get("/status", headers=self._headers())
        data = await status_resp.json()
        self.assertFalse(data["sharing_active"])
        self.assertIsNone(data["navigation"]["position"])

    async def test_shares_location_during_navigation_and_sos(self) -> None:
        await self.client.post(
            "/navigation/state",
            headers=self._headers(),
            json={
                "protocol": 1,
                "session_id": "s2",
                "revision": 2,
                "state": "navigating",
                "position": [106.6662, 10.7553],
            },
        )
        status_resp = await self.client.get("/status", headers=self._headers())
        data = await status_resp.json()
        self.assertTrue(data["sharing_active"])
        self.assertEqual(data["navigation"]["position"], [106.6662, 10.7553])

        # Idle again, then trigger SOS -> location must be shared
        await self.client.post(
            "/navigation/state",
            headers=self._headers(),
            json={
                "protocol": 1,
                "session_id": "s2",
                "revision": 3,
                "state": "idle",
                "position": [106.6700, 10.7600],
            },
        )
        sos_resp = await self.client.post(
            "/sos/trigger",
            headers=self._headers(),
            json={"trigger": "voice", "message": "Cứu tôi với!"},
        )
        self.assertEqual(sos_resp.status, 200)
        status_after_sos = await (await self.client.get("/status", headers=self._headers())).json()
        self.assertTrue(status_after_sos["sharing_active"])
        self.assertIsNotNone(status_after_sos["active_sos"])

    async def test_assist_request_and_caregiver_reply_roundtrip(self) -> None:
        req_resp = await self.client.post(
            "/assist/request",
            headers=self._headers(),
            json={
                "request_id": "req-001",
                "question": "Biển trước mặt ghi xe buýt số mấy?",
                "position": [106.6662, 10.7553],
            },
        )
        self.assertEqual(req_resp.status, 200)

        reply_resp = await self.client.post(
            "/assist/reply",
            headers=self._headers(),
            json={
                "request_id": "req-001",
                "reply_text": "Trạm xe buýt tuyến số 08 ngay trước mặt 4 mét.",
                "sender_name": "Mẹ",
            },
        )
        self.assertEqual(reply_resp.status, 200)
        status = await (await self.client.get("/status", headers=self._headers())).json()
        self.assertEqual(status["assist_requests"][0]["status"], "replied")
        self.assertIn("số 08", status["assist_requests"][0]["reply"]["reply_text"])

    async def test_destination_suggestion_requires_wearer_confirmation(self) -> None:
        dest_resp = await self.client.post(
            "/destination/suggest",
            headers=self._headers(),
            json={
                "name": "Bệnh viện Chợ Rẫy",
                "address": "201B Nguyễn Chí Thanh, Quận 5",
                "point": [106.6596, 10.7578],
                "sender_name": "Ba",
            },
        )
        self.assertEqual(dest_resp.status, 200)
        payload = await dest_resp.json()
        self.assertTrue(payload["suggestion"]["requires_wearer_confirmation"])
        self.assertEqual(payload["suggestion"]["status"], "pending_confirmation")


if __name__ == "__main__":
    unittest.main()
