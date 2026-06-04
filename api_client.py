import requests


class ApiError(Exception):
    def __init__(self, status: int, message: str):
        super().__init__(message)
        self.status = status


class ApiClient:
    def __init__(self, api_key: str, base_url: str = "https://api.replicant.space/v1"):
        self.base_url = base_url.rstrip("/")
        self._session = requests.Session()
        self._session.headers.update({
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        })

    # --- Account ---

    def get_account(self) -> dict:
        return self._get("/accounts/me")

    # --- Replicant ---

    def get_replicant(self, code: str) -> dict:
        return self._get(f"/replicants/{code}")

    def get_replicant_events(self, code: str) -> list:
        return self._get(f"/replicants/{code}/events")

    def get_replicant_devices(self, code: str) -> list:
        return self._get(f"/replicants/{code}/devices")

    def get_replicant_stars(self, code: str) -> list:
        return self._get(f"/replicants/{code}/stars")

    def scan(self, code: str) -> dict:
        return self._post(f"/replicants/{code}/scan")

    def scan_devices(self, code: str) -> list:
        return self._get(f"/replicants/{code}/scan/devices")

    def travel(self, code: str, destination: str, dry_run: bool = False) -> dict:
        body: dict = {"destination": destination}
        if dry_run:
            body["dry_run"] = True
        return self._post(f"/replicants/{code}/travel", body)

    def mine(self, code: str, resource: str) -> dict:
        return self._post(f"/replicants/{code}/mine", {"resource_type": resource})

    def print_device(self, code: str, device_type: str) -> dict:
        return self._post(f"/replicants/{code}/print", {"device_type": device_type})

    def replicate(self, code: str) -> dict:
        return self._post(f"/replicants/{code}/replicate")

    def configure_replicant(self, code: str, body: dict) -> dict:
        return self._patch(f"/replicants/{code}", body)

    def stop_mine(self, code: str) -> dict:
        return self._delete(f"/replicants/{code}/mine")

    # --- Devices ---

    def get_device(self, code: str) -> dict:
        return self._get(f"/devices/{code}")

    def device_command(self, device_code: str, command: str, extra: dict | None = None) -> dict:
        body = {"command": command}
        if extra:
            body.update(extra)
        return self._post(f"/devices/{device_code}", body)

    # --- Blueprints ---

    def get_blueprints(self) -> list:
        return self._get("/blueprints")

    # --- Account actions ---

    def register_webhook(self, url: str) -> dict:
        return self._post("/accounts/webhook", {"url": url})

    # --- Locations ---

    def get_location(self, location_code: str) -> dict:
        return self._get(f"/locations/{location_code}")

    def get_location_inventory(self, location_code: str) -> dict:
        return self._get(f"/locations/{location_code}/inventory")

    def get_inventory(self, star: str | None = None, location: str | None = None) -> dict:
        params: dict = {}
        if star:
            params["star"] = star
        if location:
            params["location"] = location
        return self._get("/inventory", params or None)

    def get_location_asteroids(self, location_code: str) -> list:
        return self._get(f"/locations/{location_code}/asteroids")

    def get_system_map(self, location_code: str) -> dict:
        return self._get(f"/locations/{location_code}/system-map")

    # --- FTL Beacons ---

    def get_beacon_audit(self, beacon_code: str, cursor: int | None = None,
                         limit: int = 20, latest: bool = True,
                         device_type: str | None = None,
                         replicant_code: str | None = None) -> dict:
        params: dict = {"limit": limit}
        if cursor is not None:
            params["cursor"] = cursor
        elif latest:
            params["latest"] = "true"
        if device_type:
            params["device_type"] = device_type
        if replicant_code:
            params["replicant_code"] = replicant_code
        return self._get(f"/devices/{beacon_code}/audit", params)

    # --- FTL Relays / BobNet ---

    def get_relay_network(self, relay_code: str) -> dict:
        return self._get(f"/devices/{relay_code}/network")

    def get_bobnet_messages(self, relay_code: str, limit: int = 50,
                            latest: bool = True, include_npcs: bool = True) -> dict:
        return self._get(f"/devices/{relay_code}/messages", {
            "limit": limit,
            "latest": "true" if latest else "false",
            "include_npcs": "true" if include_npcs else "false",
        })

    def send_bobnet_message(self, replicant_code: str, channel: str, text: str) -> dict:
        return self._post(f"/replicants/{replicant_code}/message",
                          {"channel": channel, "text": text})

    # --- Messages ---

    def get_messages(self, limit: int = 20, unread_only: bool = False) -> tuple:
        params: dict = {"limit": limit}
        if unread_only:
            params["unread_only"] = "true"
        resp = self._session.get(f"{self.base_url}/messages", params=params, timeout=15)
        self._raise_for_status(resp)
        unread = int(resp.headers.get("X-Replicant-Space-Unread-Count", 0))
        return resp.json(), unread

    def mark_messages_read(self, ids: list | None = None, mark_all: bool = False) -> dict:
        body = {"mark_all": True} if mark_all else {"ids": ids or []}
        return self._post("/messages/read", body)

    # --- Trading ---

    def get_traders(self, code: str) -> dict:
        return self._get(f"/replicants/{code}/traders")

    def get_shop_trades(self, controller_code: str) -> dict:
        return self._get(f"/devices/{controller_code}/trades")

    def execute_trade(self, controller_code: str, trade_code: str) -> dict:
        return self._post(f"/devices/{controller_code}/trades/{trade_code}")

    # --- Consciousness transfer ---

    def teleport(self, code: str, target: str) -> dict:
        return self._post(f"/replicants/{code}/teleport", {"target": target})

    def transfer(self, code: str, target: str) -> dict:
        return self._post(f"/replicants/{code}/transfer", {"target": target})

    # --- Internal ---

    def _get(self, path: str, params: dict | None = None):
        resp = self._session.get(f"{self.base_url}{path}", params=params, timeout=15)
        self._raise_for_status(resp)
        return resp.json()

    def _post(self, path: str, data: dict | None = None):
        resp = self._session.post(f"{self.base_url}{path}", json=data or {}, timeout=15)
        self._raise_for_status(resp)
        return resp.json()

    def _patch(self, path: str, data: dict | None = None):
        resp = self._session.patch(f"{self.base_url}{path}", json=data or {}, timeout=15)
        self._raise_for_status(resp)
        return resp.json()

    def _delete(self, path: str):
        resp = self._session.delete(f"{self.base_url}{path}", timeout=15)
        self._raise_for_status(resp)
        return resp.json()

    @staticmethod
    def _raise_for_status(resp: requests.Response):
        if not resp.ok:
            try:
                msg = resp.json().get("message", resp.text)
            except Exception:
                msg = resp.text
            raise ApiError(resp.status_code, msg)
