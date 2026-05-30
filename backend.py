import json
from pathlib import Path

from PySide6.QtCore import QObject, Property, Signal, Slot, QThread, QTimer

from api_client import ApiClient


class _Worker(QThread):
    """Runs a single API call on a background thread, emits result or error."""
    succeeded = Signal(str, object)
    failed = Signal(str, str)

    def __init__(self, key: str, fn, *args, **kwargs):
        super().__init__()
        self._key = key
        self._fn = fn
        self._args = args
        self._kwargs = kwargs

    def run(self):
        try:
            result = self._fn(*self._args, **self._kwargs)
            self.succeeded.emit(self._key, result)
        except Exception as exc:
            self.failed.emit(self._key, str(exc))


class Backend(QObject):
    replicantChanged = Signal()
    eventsChanged = Signal()
    devicesChanged = Signal()
    starsChanged = Signal()
    asteroidBeltsChanged = Signal()
    planetsChanged = Signal()
    blueprintsChanged = Signal()
    inventoryChanged = Signal()
    messagesChanged = Signal()
    unreadCountChanged = Signal()
    tradersChanged = Signal()
    shopTradesChanged = Signal()
    scanComplete = Signal()
    statusChanged = Signal()
    errorOccurred = Signal(str)
    toastMessage = Signal(str, str)   # (level: "info"|"warn"|"error", text)

    def __init__(self, config: dict, parent=None):
        super().__init__(parent)
        self._config = config
        self._client = ApiClient(
            api_key=config.get("api_key", ""),
            base_url=config.get("api_base", "https://api.replicant.space/v1"),
        )
        self._code = config.get("replicant_code", "")

        self._replicant: dict = {}
        self._events: list = []
        self._devices: list = []
        self._stars: list = []
        self._asteroid_belts: list = []
        self._planets: list = []
        self._blueprints: list = []
        self._inventory: list = []
        self._messages: list = []
        self._unread_count: int = 0
        self._traders: list = []
        self._shop_trades: list = []
        self._status: str = "IDLE"

        self._live_workers: list = []

        self._poll_timer = QTimer(self)
        self._poll_timer.timeout.connect(self.refresh)
        self._poll_timer.start(30_000)

        if self._code:
            self.refresh()
        self._dispatch("blueprints", self._client.get_blueprints)

    # ------------------------------------------------------------------ #
    # QML-facing properties
    # ------------------------------------------------------------------ #

    @Property(str, notify=replicantChanged)
    def replicantName(self) -> str:
        return self._replicant.get("name", "—")

    @Property(str, notify=replicantChanged)
    def location(self) -> str:
        return self._replicant.get("location", "—")

    @Property(int, notify=replicantChanged)
    def xp(self) -> int:
        return int(self._replicant.get("experience_points", 0))

    @Property(str, notify=replicantChanged)
    def replicantCode(self) -> str:
        return self._code

    @Property(str, notify=replicantChanged)
    def hostDevice(self) -> str:
        return self._replicant.get("hosted_device_code", "—")

    @Property('QVariantList', notify=eventsChanged)
    def events(self) -> list:
        return self._events

    @Property('QVariantList', notify=devicesChanged)
    def devices(self) -> list:
        return self._devices

    @Property('QVariantList', notify=starsChanged)
    def stars(self) -> list:
        return self._stars

    @Property('QVariantList', notify=asteroidBeltsChanged)
    def asteroidBelts(self) -> list:
        return self._asteroid_belts

    @Property('QVariantList', notify=planetsChanged)
    def planets(self) -> list:
        return self._planets

    @Property('QVariantList', notify=blueprintsChanged)
    def blueprints(self) -> list:
        return self._blueprints

    @Property('QVariantList', notify=inventoryChanged)
    def inventory(self) -> list:
        return self._inventory

    @Property('QVariantList', notify=messagesChanged)
    def messages(self) -> list:
        return self._messages

    @Property(int, notify=unreadCountChanged)
    def unreadCount(self) -> int:
        return self._unread_count

    @Property('QVariantList', notify=tradersChanged)
    def traders(self) -> list:
        return self._traders

    @Property('QVariantList', notify=shopTradesChanged)
    def shopTrades(self) -> list:
        return self._shop_trades

    @Property(str, notify=statusChanged)
    def status(self) -> str:
        return self._status

    # ------------------------------------------------------------------ #
    # QML-callable slots
    # ------------------------------------------------------------------ #

    @Slot()
    def refresh(self):
        if not self._code:
            return
        self._dispatch("replicant", self._client.get_replicant, self._code)
        self._dispatch("events",    self._client.get_replicant_events, self._code)
        self._dispatch("devices",   self._client.get_replicant_devices, self._code)
        self._dispatch("stars",     self._client.get_replicant_stars, self._code)
        self._dispatch("messages",  self._client.get_messages, 20)
        loc = self._replicant.get("location", "")
        if loc:
            self._dispatch("inventory", self._client.get_location_inventory, loc)

    @Slot()
    def fetchInventory(self):
        loc = self._replicant.get("location", "")
        if loc:
            self._dispatch("inventory", self._client.get_location_inventory, loc)
        else:
            self.toastMessage.emit("warn", "Location unknown — sync first")

    @Slot()
    def scan(self):
        self._set_status("SCANNING…")
        self._dispatch("action:scan", self._client.scan, self._code)

    @Slot()
    def scanDevices(self):
        self._set_status("SCANNING DEVICES…")
        self._dispatch("action:scan_devices", self._client.scan_devices, self._code)

    @Slot(str)
    def travelTo(self, destination: str):
        self._set_status(f"TRAVELLING → {destination}")
        self._dispatch("action:travel", self._client.travel, self._code, destination)

    @Slot(str)
    def mine(self, resource: str):
        self._set_status(f"MINING {resource}…")
        self._dispatch("action:mine", self._client.mine, self._code, resource)

    @Slot(str)
    def printDevice(self, blueprint: str):
        self._set_status(f"PRINTING {blueprint}…")
        self._dispatch("action:print", self._client.print_device, self._code, blueprint)

    @Slot(str, str)
    def travelDevice(self, device_code: str, destination: str):
        self._set_status(f"DRONE {device_code} → {destination}…")
        self._dispatch("action:travel_device", self._client.device_command,
                       device_code, "travel", {"destination": destination})

    @Slot(str)
    def scanWithDevice(self, device_code: str):
        self._set_status(f"DRONE {device_code} SCANNING…")
        self._dispatch("action:scan_device", self._client.device_command,
                       device_code, "scan")

    @Slot(str, str)
    def retarget(self, device_code: str, resource: str):
        self._set_status(f"RETARGETING {device_code} → {resource}…")
        self._dispatch("action:retarget", self._client.device_command,
                       device_code, "retarget", {"resource_type": resource})

    @Slot(str, str)
    def mineWithDevice(self, device_code: str, resource: str):
        self._set_status(f"DRONE {device_code} MINING {resource}…")
        self._dispatch("action:mine", self._client.device_command, device_code, "start_mining", {"resource_type": resource})

    @Slot(str, str, str)
    def mineWithDeviceAtTarget(self, device_code: str, resource: str, target: str):
        self._set_status(f"DRONE {device_code} MINING {target}…")
        self._dispatch("action:mine", self._client.device_command, device_code, "start_mining",
                       {"resource_type": resource, "target": target})

    @Slot(str)
    def cancelPrint(self, device_code: str):
        self._set_status("CANCELLING PRINT…")
        self._dispatch("action:cancel_print", self._client.device_command, device_code, "deactivate")

    @Slot(str, str)
    def deviceCommand(self, device_code: str, command: str):
        self._dispatch(f"action:cmd:{device_code}", self._client.device_command, device_code, command)

    @Slot(str, str, str)
    def deviceCommandWithTarget(self, device_code: str, command: str, target: str):
        self._dispatch(f"action:cmd:{device_code}", self._client.device_command,
                       device_code, command, {"target": target} if target else None)

    @Slot()
    def fetchTraders(self):
        self._dispatch("traders", self._client.get_traders, self._code)

    @Slot(str)
    def browseShop(self, controller_code: str):
        self._shop_trades = []
        self.shopTradesChanged.emit()
        self._dispatch("shop_trades", self._client.get_shop_trades, controller_code)

    @Slot(str, str)
    def executeTrade(self, controller_code: str, trade_code: str):
        self._dispatch("action:trade", self._client.execute_trade, controller_code, trade_code)

    @Slot()
    def fetchMessages(self):
        self._dispatch("messages", self._client.get_messages, 20)

    @Slot()
    def markAllRead(self):
        self._dispatch("action:mark_read", self._client.mark_messages_read, mark_all=True)

    @Slot(int)
    def markMessageRead(self, message_id: int):
        self._dispatch("action:mark_read", self._client.mark_messages_read, [message_id])

    @Slot(str)
    def teleport(self, target: str):
        self._set_status(f"TELEPORTING → {target}…")
        self._dispatch("action:teleport", self._client.teleport, self._code, target)

    @Slot(str)
    def transfer(self, target: str):
        self._set_status(f"TRANSFERRING → {target}…")
        self._dispatch("action:transfer", self._client.transfer, self._code, target)

    @Slot()
    def registerWebhook(self):
        url = self._config.get("webhook_url", "")
        if not url:
            self.toastMessage.emit("error", "No webhook_url in config")
            return
        self._dispatch("action:webhook", self._client.register_webhook, url)

    @Slot(str)
    def setReplicantCode(self, code: str):
        self._code = code
        self.replicantChanged.emit()
        self.refresh()

    # ------------------------------------------------------------------ #
    # Internal helpers
    # ------------------------------------------------------------------ #

    def _dispatch(self, key: str, fn, *args, **kwargs):
        worker = _Worker(key, fn, *args, **kwargs)
        worker.succeeded.connect(self._on_success)
        worker.failed.connect(self._on_error)
        self._live_workers.append(worker)
        worker.finished.connect(lambda w=worker: self._live_workers.remove(w) if w in self._live_workers else None)
        worker.start()

    def _set_status(self, text: str):
        self._status = text
        self.statusChanged.emit()

    def _on_success(self, key: str, data):
        if key == "replicant":
            self._replicant = data if isinstance(data, dict) else {}
            self.replicantChanged.emit()
        elif key == "events":
            self._events = self._to_list(data)
            self.eventsChanged.emit()
        elif key == "devices":
            self._devices = self._to_list(data)
            self.devicesChanged.emit()
        elif key == "stars":
            self._stars = self._to_list(data)
            self.starsChanged.emit()
        elif key == "blueprints":
            self._blueprints = self._to_list(data)
            self.blueprintsChanged.emit()
        elif key == "inventory":
            combined: dict = {}
            if isinstance(data, dict):
                items_val = data.get("items")
                if isinstance(items_val, dict):
                    # {"items": {"carbon": 348, ...}}
                    for k, v in items_val.items():
                        if isinstance(v, (int, float)) and v > 0:
                            combined[k] = combined.get(k, 0) + v
                elif isinstance(items_val, list):
                    # {"items": [{"resource"/"name"/"type": "carbon", "qty"/"quantity": 348}, ...]}
                    for i in items_val:
                        if not isinstance(i, dict):
                            continue
                        name = (i.get("name") or i.get("resource") or
                                i.get("resource_type") or i.get("type") or "?")
                        qty = i.get("qty") or i.get("quantity") or i.get("amount") or 0
                        if isinstance(qty, (int, float)) and qty > 0:
                            combined[name] = combined.get(name, 0) + qty
                elif isinstance(data.get("locations"), list):
                    # {"locations": [{"location": "...", "items": {...}}, ...]}
                    for loc in data["locations"]:
                        for k, v in (loc.get("items") or {}).items():
                            if isinstance(v, (int, float)) and v > 0:
                                combined[k] = combined.get(k, 0) + v
            elif isinstance(data, list):
                # Bare list: [{"resource": "carbon", "qty": 348}, ...]
                for i in data:
                    if not isinstance(i, dict):
                        continue
                    name = (i.get("name") or i.get("resource") or
                            i.get("resource_type") or i.get("type") or "?")
                    qty = i.get("qty") or i.get("quantity") or i.get("amount") or 0
                    if isinstance(qty, (int, float)) and qty > 0:
                        combined[name] = combined.get(name, 0) + qty
            self._inventory = sorted(
                [{"name": k, "qty": v} for k, v in combined.items()],
                key=lambda x: x["name"]
            )
            if not combined:
                # Debug: show what the API actually returned so we can fix parsing
                shape = repr(data)[:120] if data is not None else "None"
                self.toastMessage.emit("warn", f"INV EMPTY — raw: {shape}")
            self.inventoryChanged.emit()
        elif key == "action:scan":
            belts = data.get("asteroid_belt", {}).get("belts", []) if isinstance(data, dict) else []
            self._asteroid_belts = belts
            self.asteroidBeltsChanged.emit()
            self._planets = data.get("planets", []) if isinstance(data, dict) else []
            self.planetsChanged.emit()
            self.scanComplete.emit()
            self._set_status("IDLE")
            n = len(belts)
            self.toastMessage.emit("info", f"SCAN complete — {n} belt{'s' if n != 1 else ''} found")
            self.refresh()
        elif key == "traders":
            self._traders = self._to_list(data)
            self.tradersChanged.emit()
        elif key == "shop_trades":
            self._shop_trades = self._to_list(data)
            self.shopTradesChanged.emit()
        elif key == "messages":
            msg_data, unread = data if isinstance(data, tuple) else (data, 0)
            self._messages = self._to_list(msg_data)
            self._unread_count = int(unread)
            self.messagesChanged.emit()
            self.unreadCountChanged.emit()
        elif key == "action:mark_read":
            self._dispatch("messages", self._client.get_messages, 20)
        elif key == "action:cancel_print":
            self._set_status("IDLE")
            self.toastMessage.emit("info", "PRINT CANCELLED")
            self.refresh()
        elif key == "action:mine":
            self._set_status("IDLE")
            self.toastMessage.emit("info", "MINE complete")
            self.fetchInventory()
            QTimer.singleShot(5000, self.fetchInventory)
            self.refresh()
        elif key.startswith("action:"):
            action = key.split(":", 1)[1]
            self._set_status("IDLE")
            self.toastMessage.emit("info", f"{action.upper()} complete")
            self.refresh()

    def _on_error(self, key: str, error: str):
        self._set_status("ERROR")
        short_key = key.split(":")[-1]
        self.toastMessage.emit("error", f"[{short_key.upper()}] {error}")
        self.errorOccurred.emit(f"[{key}] {error}")

    @staticmethod
    def _to_list(data) -> list:
        if isinstance(data, list):
            return data
        if isinstance(data, dict):
            for k in ("items", "events", "devices", "stars", "blueprints", "messages", "traders", "trades", "results", "data"):
                if k in data and isinstance(data[k], list):
                    return data[k]
        return []
