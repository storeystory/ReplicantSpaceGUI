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
    asteroidsChanged = Signal()
    systemMapChanged = Signal()
    beaconAuditChanged = Signal()
    relayNetworkChanged = Signal()
    bobnetMessagesChanged = Signal()
    accountReplicantsChanged = Signal()
    locationsOverviewChanged = Signal()
    moonsByPlanetChanged = Signal()
    achievementsChanged = Signal()
    reputationChanged = Signal()
    scannedDevicesChanged = Signal()
    directoryChanged = Signal()
    megastructureChanged = Signal()
    megastructureLeaderboardChanged = Signal()
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

        # account-level state (persists across replicant switches)
        self._blueprints: list = []
        self._account_replicants: list = []
        self._locations_overview: list = []
        self._achievements: list = []
        self._reputation: list = []
        self._directory: list = []
        self._directory_cursor = None
        self._megastructure_leaderboard: list = []

        self._live_workers: list = []

        self._poll_timer = QTimer(self)
        self._poll_timer.timeout.connect(self.refresh)
        self._poll_timer.start(30_000)

        self._reset_state(emit=False)

        self._dispatch("blueprints", self._client.get_blueprints)
        self._dispatch("account", self._client.get_account)
        self._dispatch("achievements", self._client.get_achievements)
        self._dispatch("reputation", self._client.get_reputation)
        if self._code:
            self.refresh()

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

    @Property(str, notify=replicantChanged)
    def replicantPronouns(self) -> str:
        return self._replicant.get("pronouns", "")

    @Property(str, notify=replicantChanged)
    def replicantDescription(self) -> str:
        return self._replicant.get("description", "")

    @Property(str, notify=replicantChanged)
    def replicantPlan(self) -> str:
        return self._replicant.get("plan", "")

    @Property(str, notify=replicantChanged)
    def replicantProject(self) -> str:
        return self._replicant.get("project", "")

    @Property(bool, notify=replicantChanged)
    def replicantIsNpc(self) -> bool:
        return bool(self._replicant.get("is_npc", False))

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

    @Property('QVariantList', notify=asteroidsChanged)
    def asteroids(self) -> list:
        return self._asteroids

    @Property('QVariantList', notify=systemMapChanged)
    def systemMap(self) -> list:
        return self._system_map

    @Property('QVariantList', notify=bobnetMessagesChanged)
    def bobnetMessages(self) -> list:
        return self._bobnet_messages

    @Property('QVariantList', notify=beaconAuditChanged)
    def beaconAudit(self) -> list:
        return self._beacon_audit

    @Property(bool, notify=beaconAuditChanged)
    def beaconAuditHasMore(self) -> bool:
        return self._beacon_audit_cursor is not None and len(self._beacon_audit) > 0

    @Property('QVariantList', notify=relayNetworkChanged)
    def relayNetworks(self) -> list:
        return [
            {"relay_code": k,
             "connections": v.get("connections", []),
             "range_ly": v.get("range_ly"),
             "status": v.get("status", "")}
            for k, v in self._relay_networks.items()
        ]

    @Property('QVariantList', notify=accountReplicantsChanged)
    def accountReplicants(self) -> list:
        return self._account_replicants

    @Property('QVariantList', notify=locationsOverviewChanged)
    def locationsOverview(self) -> list:
        return self._locations_overview

    @Property('QVariantList', notify=moonsByPlanetChanged)
    def moonsByPlanet(self) -> list:
        return [{"planet": k, "moons": v} for k, v in self._moons_by_planet.items()]

    @Property('QVariantList', notify=achievementsChanged)
    def achievements(self) -> list:
        return self._achievements

    @Property('QVariantList', notify=reputationChanged)
    def reputation(self) -> list:
        return self._reputation

    @Property('QVariantList', notify=scannedDevicesChanged)
    def scannedDevices(self) -> list:
        return self._scanned_devices

    @Property('QVariantList', notify=directoryChanged)
    def directory(self) -> list:
        return self._directory

    @Property(bool, notify=directoryChanged)
    def directoryHasMore(self) -> bool:
        return self._directory_cursor is not None and len(self._directory) > 0

    @Property('QVariantList', notify=megastructureChanged)
    def megastructureData(self) -> list:
        return [self._megastructure] if self._megastructure else []

    @Property('QVariantList', notify=megastructureLeaderboardChanged)
    def megastructureLeaderboard(self) -> list:
        return self._megastructure_leaderboard

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
        self._dispatch("messages",  self._client.get_messages, 50)
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
    def travelDryRun(self, destination: str):
        self._dispatch("dry_run:travel", self._client.travel, self._code, destination, True)

    @Slot(str)
    def mine(self, resource: str):
        self._set_status(f"MINING {resource}…")
        self._dispatch("action:mine", self._client.mine, self._code, resource)

    @Slot(str)
    def printDevice(self, blueprint: str):
        self._set_status(f"PRINTING {blueprint}…")
        self._dispatch("action:print", self._client.print_device, self._code, blueprint)

    @Slot(str, str, str, str)
    def printToAutofactory(self, autofactory_code: str, device_type: str,
                           controller: str, travel_dest: str):
        self._set_status(f"QUEUING {device_type} IN AUTOFACTORY…")
        body: dict = {"device_type": device_type}
        if controller.strip():
            body["controller"] = controller.strip().upper()
        if travel_dest.strip():
            body["oncomplete"] = {"command": "travel", "destination": travel_dest.strip().upper()}
        self._dispatch("action:print_autofactory", self._client.device_command,
                       autofactory_code, "enqueue_print", body)

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

    @Slot()
    def fetchAsteroids(self):
        loc = self._replicant.get("location", "")
        if not loc:
            self.toastMessage.emit("warn", "Location unknown — sync first")
            return
        star = loc.split("-")[0]
        self._dispatch("asteroids", self._client.get_location_asteroids, star)

    @Slot()
    def fetchSystemMap(self):
        loc = self._replicant.get("location", "")
        if not loc:
            return
        star = loc.split("-")[0]
        self._dispatch("system_map", self._client.get_system_map, star)

    @Slot(str)
    def activateDevice(self, device_code: str):
        self._set_status(f"ACTIVATING {device_code}…")
        self._dispatch("action:activate", self._client.device_command, device_code, "activate")

    @Slot(str)
    def searchWithDevice(self, device_code: str):
        self._set_status(f"DRONE {device_code} SEARCHING…")
        self._dispatch("action:search_device", self._client.device_command,
                       device_code, "search")

    @Slot(str, str)
    def retarget(self, device_code: str, resource: str):
        self._set_status(f"RETARGETING {device_code} → {resource}…")
        self._dispatch("action:retarget", self._client.device_command,
                       device_code, "retarget", {"resource_type": resource})

    @Slot(str, str)
    def configureSurgePlate(self, device_code: str, mode: str):
        self._set_status(f"CONFIGURING {device_code}…")
        self._dispatch("action:configure", self._client.device_command,
                       device_code, "configure", {"mode": mode})

    @Slot(str, str)
    def vesselLoad(self, device_code: str, target_device: str):
        self._set_status(f"LOADING {target_device}…")
        self._dispatch("action:vessel_load", self._client.device_command,
                       device_code, "attach", {"device": target_device})

    @Slot(str)
    def vesselUnload(self, device_code: str):
        self._set_status("UNLOADING…")
        self._dispatch("action:vessel_unload", self._client.device_command,
                       device_code, "detach")

    @Slot(str, str, int)
    def collectResources(self, device_code: str, resource: str, qty: int):
        self._set_status(f"COLLECTING {resource}…")
        self._dispatch("action:collect", self._client.device_command,
                       device_code, "collect_resources", {"resources": {resource: qty}})

    @Slot(str)
    def depositResources(self, device_code: str):
        self._set_status("DEPOSITING…")
        self._dispatch("action:deposit", self._client.device_command,
                       device_code, "deposit_resources")

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
    def setPatrol(self, device_code: str):
        self._set_status(f"DISPATCHING {device_code}…")
        self._dispatch("action:patrol", self._client.device_command,
                       device_code, "set_directive", {"directive": "patrol"})

    @Slot()
    def stopMining(self):
        self._set_status("STOPPING MINE…")
        self._dispatch("action:stop_mining", self._client.stop_mine, self._code)

    @Slot(str)
    def cancelPrint(self, device_code: str):
        self._set_status("CANCELLING PRINT…")
        self._dispatch("action:cancel_print", self._client.device_command, device_code, "deactivate")

    # ── AMI Controller slots ────────────────────────────────────────────── #

    @Slot(str, str)
    def amiAdopt(self, controller_code: str, device_code: str):
        self._set_status(f"ADOPTING {device_code}…")
        self._dispatch("action:ami_adopt", self._client.device_command,
                       controller_code, "adopt", {"device": device_code})

    @Slot(str, str)
    def amiRelease(self, controller_code: str, device_code: str):
        self._set_status(f"RELEASING {device_code}…")
        self._dispatch("action:ami_release", self._client.device_command,
                       controller_code, "release", {"device": device_code})

    @Slot(str)
    def amiLaunch(self, controller_code: str):
        self._set_status(f"LAUNCHING {controller_code}…")
        self._dispatch("action:ami_launch", self._client.device_command, controller_code, "launch")

    @Slot(str)
    def amiWithdraw(self, controller_code: str):
        self._set_status(f"WITHDRAWING {controller_code}…")
        self._dispatch("action:ami_withdraw", self._client.device_command, controller_code, "withdraw")

    @Slot(str)
    def amiAssemble(self, controller_code: str):
        self._set_status(f"ASSEMBLING {controller_code}…")
        self._dispatch("action:ami_assemble", self._client.device_command, controller_code, "assemble")

    @Slot(str)
    def amiResume(self, controller_code: str):
        self._set_status(f"RESUMING {controller_code}…")
        self._dispatch("action:ami_resume", self._client.device_command, controller_code, "resume_directive")

    @Slot(str)
    def amiClearDirective(self, controller_code: str):
        self._set_status("CLEARING DIRECTIVE…")
        self._dispatch("action:ami_clear", self._client.device_command, controller_code, "clear_directive")

    @Slot(str, str, bool)
    def amiSurveySystem(self, controller_code: str, moons: str, recall: bool):
        self._set_status("SETTING SURVEY DIRECTIVE…")
        self._dispatch("action:ami_directive", self._client.device_command,
                       controller_code, "set_directive",
                       {"directive": "survey_system",
                        "configuration": {"planets": "all", "moons": moons, "recall": recall}})

    @Slot(str)
    def amiBeltSearch(self, controller_code: str):
        self._set_status("SETTING BELT SEARCH…")
        self._dispatch("action:ami_directive", self._client.device_command,
                       controller_code, "set_directive",
                       {"directive": "belt_search"})

    @Slot(str, str, str, str, str, str)
    def amiGatherResources(self, controller_code: str, carbon: str, conductive: str,
                           rares: str, silicates: str, structural: str):
        config = {}
        for name, val in [("carbon", carbon), ("conductive", conductive), ("rares", rares),
                           ("silicates", silicates), ("structural", structural)]:
            if val.strip():
                try:
                    config[name] = int(val.strip())
                except ValueError:
                    pass
        self._set_status("SETTING GATHER RESOURCES DIRECTIVE…")
        self._dispatch("action:ami_directive", self._client.device_command,
                       controller_code, "set_directive",
                       {"directive": "gather_resources", "configuration": config})

    @Slot(str)
    def amiGatherEvenly(self, controller_code: str):
        self._set_status("SETTING GATHER EVENLY DIRECTIVE…")
        self._dispatch("action:ami_directive", self._client.device_command,
                       controller_code, "set_directive",
                       {"directive": "gather_evenly"})

    @Slot(str, str, str, str, str, str)
    def amiMaintainRatios(self, controller_code: str, carbon: str, conductive: str,
                          rares: str, silicates: str, structural: str):
        config = {}
        for name, val in [("carbon", carbon), ("conductive", conductive), ("rares", rares),
                           ("silicates", silicates), ("structural", structural)]:
            if val.strip():
                try:
                    config[name] = float(val.strip())
                except ValueError:
                    pass
        self._set_status("SETTING MAINTAIN RATIOS DIRECTIVE…")
        self._dispatch("action:ami_directive", self._client.device_command,
                       controller_code, "set_directive",
                       {"directive": "maintain_ratios", "configuration": config})

    @Slot(str)
    def amiDepleteSmallest(self, controller_code: str):
        self._set_status("SETTING DEPLETE SMALLEST DIRECTIVE…")
        self._dispatch("action:ami_directive", self._client.device_command,
                       controller_code, "set_directive",
                       {"directive": "deplete_smallest"})

    @Slot(str, str, bool)
    def amiGatherSalvage(self, controller_code: str, location: str, recall: bool):
        self._set_status("SETTING GATHER SALVAGE DIRECTIVE…")
        self._dispatch("action:ami_directive", self._client.device_command,
                       controller_code, "set_directive",
                       {"directive": "gather_salvage",
                        "configuration": {"location": location.strip(), "recall": recall}})

    @Slot(str, str, str, str)
    def amiShuttle(self, controller_code: str, collect: str, deliver: str, priority: str):
        pri = [p.strip() for p in priority.split(",") if p.strip()]
        self._set_status("SETTING SHUTTLE DIRECTIVE…")
        self._dispatch("action:ami_directive", self._client.device_command,
                       controller_code, "set_directive",
                       {"directive": "shuttle",
                        "configuration": {"collect": collect.strip(), "deliver": deliver.strip(), "priority": pri}})

    @Slot(str, str, str, str)
    def amiFerry(self, controller_code: str, collect: str, deliver: str, priority: str):
        pri = [p.strip() for p in priority.split(",") if p.strip()]
        self._set_status("SETTING FERRY DIRECTIVE…")
        self._dispatch("action:ami_directive", self._client.device_command,
                       controller_code, "set_directive",
                       {"directive": "ferry",
                        "configuration": {"collect": collect.strip(), "deliver": deliver.strip(), "priority": pri}})

    @Slot(str, str, str)
    def amiConsolidate(self, controller_code: str, deliver: str, priority: str):
        pri = [p.strip() for p in priority.split(",") if p.strip()]
        self._set_status("SETTING CONSOLIDATE DIRECTIVE…")
        self._dispatch("action:ami_directive", self._client.device_command,
                       controller_code, "set_directive",
                       {"directive": "consolidate",
                        "configuration": {"deliver": deliver.strip(), "priority": pri}})

    @Slot(str, str, str, str, str)
    def amiDelivery(self, controller_code: str, collect: str, deliver: str, resource: str, amount: str):
        try:
            amt = int(amount.strip())
        except (ValueError, AttributeError):
            self.toastMessage.emit("warn", "Amount must be a whole number")
            return
        self._set_status("SETTING DELIVERY DIRECTIVE…")
        self._dispatch("action:ami_directive", self._client.device_command,
                       controller_code, "set_directive",
                       {"directive": "delivery",
                        "configuration": {
                            "route": {"collect": collect.strip(), "deliver": deliver.strip()},
                            "requirement": {resource.strip(): amt}
                        }})

    # ── BobNet slots ─────────────────────────────────────────────────────── #

    @Slot(str)
    def fetchBobnetMessages(self, relay_code: str):
        if not relay_code:
            return
        self._bobnet_relay_code = relay_code
        self._dispatch("bobnet_messages", self._client.get_bobnet_messages, relay_code)

    @Slot(str, str)
    def sendBobnetMessage(self, channel: str, text: str):
        if not text.strip():
            return
        self._dispatch("action:bobnet_send", self._client.send_bobnet_message,
                       self._code, channel, text.strip())

    # ── FTL Beacon slots ────────────────────────────────────────────────── #

    @Slot(str, str, str)
    def fetchBeaconAudit(self, beacon_code: str, device_type_filter: str, replicant_filter: str):
        self._beacon_audit = []
        self._beacon_audit_cursor = None
        self._beacon_code_last = beacon_code
        self.beaconAuditChanged.emit()
        self._dispatch("beacon_audit", self._client.get_beacon_audit,
                       beacon_code, None, 30, True,
                       device_type_filter or None, replicant_filter or None)

    @Slot()
    def fetchBeaconAuditMore(self):
        if not self._beacon_code_last or self._beacon_audit_cursor is None:
            return
        self._dispatch("beacon_audit_more", self._client.get_beacon_audit,
                       self._beacon_code_last, self._beacon_audit_cursor, 30)

    # ── FTL Relay slots ─────────────────────────────────────────────────── #

    @Slot(str)
    def fetchRelayNetwork(self, relay_code: str):
        self._dispatch(f"relay_network:{relay_code}", self._client.get_relay_network, relay_code)

    @Slot(str)
    def activateRelay(self, relay_code: str):
        self._set_status(f"ACTIVATING RELAY {relay_code}…")
        self._dispatch("action:activate_relay", self._client.device_command, relay_code, "activate")

    # ── System Hub slots ─────────────────────────────────────────────────── #

    @Slot(str)
    def activateHub(self, hub_code: str):
        self._set_status(f"ACTIVATING HUB {hub_code}…")
        self._dispatch("action:activate_hub", self._client.device_command, hub_code, "activate")

    @Slot(str, str)
    def setHubWelcomeMessage(self, hub_code: str, message: str):
        self._set_status("SETTING WELCOME MESSAGE…")
        self._dispatch("action:hub_message", self._client.device_command,
                       hub_code, "set_welcome_message", {"message": message})

    @Slot(str, str)
    def deviceCommand(self, device_code: str, command: str):
        self._dispatch(f"action:cmd:{device_code}", self._client.device_command, device_code, command)

    @Slot(str, str, str)
    def deviceCommandWithTarget(self, device_code: str, command: str, target: str):
        self._dispatch(f"action:cmd:{device_code}", self._client.device_command,
                       device_code, command, {"target": target} if target else None)

    @Slot(str, str, str, str, str, bool)
    def configureReplicant(self, name: str, pronouns: str, description: str,
                           plan: str, project: str, is_npc: bool):
        body: dict = {
            "name": name,
            "pronouns": pronouns,
            "description": description,
            "plan": plan,
            "project": project,
            "is_npc": is_npc,
        }
        self._set_status("SAVING PROFILE…")
        self._dispatch("action:configure_replicant", self._client.configure_replicant,
                       self._code, body)

    @Slot(str)
    def decommissionDevice(self, device_code: str):
        self._set_status("DECOMMISSIONING…")
        self._dispatch("action:decommission", self._client.device_command,
                       device_code, "decommission")

    @Slot()
    def fetchLocationsOverview(self):
        self._dispatch("locations_overview", self._client.get_locations)

    @Slot()
    def fetchAchievements(self):
        self._dispatch("achievements", self._client.get_achievements)

    @Slot()
    def fetchReputation(self):
        self._dispatch("reputation", self._client.get_reputation)

    @Slot(str)
    def searchDirectory(self, name: str):
        self._directory = []
        self._directory_cursor = None
        self.directoryChanged.emit()
        self._dispatch("directory", self._client.get_replicant_directory,
                       None, 30, name.strip() or None)

    @Slot()
    def fetchDirectoryMore(self):
        if self._directory_cursor is None:
            return
        self._dispatch("directory_more", self._client.get_replicant_directory,
                       self._directory_cursor, 30)

    @Slot(str, str)
    def submitFeedback(self, feedback_type: str, body: str):
        if not body.strip():
            return
        self._dispatch("action:feedback", self._client.submit_feedback,
                       feedback_type, body.strip())

    @Slot()
    def fetchMegastructure(self):
        loc = self._replicant.get("location", "")
        if not loc:
            self.toastMessage.emit("warn", "Location unknown — sync first")
            return
        self._dispatch("megastructure", self._client.get_location_megastructures, loc)

    @Slot('QVariantList')
    def contributeToMegastructure(self, devices: list):
        loc = self._replicant.get("location", "")
        if not loc or not devices:
            return
        self._dispatch("action:megastructure_contribute",
                       self._client.contribute_megastructure, loc, list(devices))

    @Slot()
    def fetchMegastructureLeaderboard(self):
        self._dispatch("megastructure_leaderboard",
                       self._client.get_megastructure_leaderboard)

    @Slot()
    def fetchPlanetMoons(self):
        for planet in self._planets:
            if not isinstance(planet, dict):
                continue
            if (planet.get("moon_count") or 0) < 1:
                continue
            desig = planet.get("designation", "")
            if desig:
                self._dispatch(f"planet_moons:{desig}",
                               self._client.get_location, desig)

    @Slot()
    def fetchAccountReplicants(self):
        self._dispatch("account", self._client.get_account)

    @Slot(str)
    def switchReplicant(self, code: str):
        if not code or code == self._code:
            return
        self._code = code
        self._reset_state()
        self.refresh()

    @Slot(str, str)
    def changeDeviceOwner(self, device_code: str, target_code: str):
        self._set_status("TRANSFERRING…")
        self._dispatch("action:change_owner", self._client.device_command,
                       device_code, "change_owner", {"target": target_code})

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
        self._dispatch("messages", self._client.get_messages, 50)

    @Slot()
    def markAllRead(self):
        self._dispatch("action:mark_read", self._client.mark_messages_read, mark_all=True)

    @Slot(int)
    def markMessageRead(self, message_id: int):
        # Optimistic removal — message disappears immediately without waiting for re-fetch
        self._messages = [m for m in self._messages if m.get("id") != message_id]
        self._unread_count = max(0, self._unread_count - 1)
        self.messagesChanged.emit()
        self.unreadCountChanged.emit()
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

    def _reset_state(self, emit: bool = True):
        self._replicant = {}
        self._events = []
        self._devices = []
        self._stars = []
        self._asteroid_belts = []
        self._planets = []
        self._inventory = []
        self._messages = []
        self._unread_count = 0
        self._traders = []
        self._shop_trades = []
        self._asteroids = []
        self._system_map = []
        self._beacon_audit = []
        self._beacon_code_last = ""
        self._beacon_audit_cursor = None
        self._relay_networks = {}
        self._bobnet_messages = []
        self._bobnet_relay_code = ""
        self._moons_by_planet: dict = {}
        self._scanned_devices: list = []
        self._megastructure: dict = {}
        self._status = "IDLE"
        if emit:
            for sig in (self.replicantChanged, self.eventsChanged, self.devicesChanged,
                        self.starsChanged, self.asteroidBeltsChanged, self.planetsChanged,
                        self.inventoryChanged, self.messagesChanged, self.unreadCountChanged,
                        self.asteroidsChanged, self.systemMapChanged, self.beaconAuditChanged,
                        self.relayNetworkChanged, self.bobnetMessagesChanged, self.statusChanged):
                sig.emit()

    def _set_status(self, text: str):
        self._status = text
        self.statusChanged.emit()

    def _on_success(self, key: str, data):
        if key == "replicant":
            self._replicant = data if isinstance(data, dict) else {}
            self.replicantChanged.emit()
            # After a switch, refresh() runs before the location is known, so inventory
            # is skipped. Fetch it now that we have the location.
            loc = self._replicant.get("location", "")
            if loc and not self._inventory:
                self._dispatch("inventory", self._client.get_location_inventory, loc)
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
            self.inventoryChanged.emit()
        elif key == "dry_run:travel":
            if isinstance(data, dict):
                parts = []
                dest = data.get("destination", "")
                if dest:
                    parts.append(f"→ {dest}")
                for field in ("travel_time", "estimated_travel_time", "duration"):
                    t = data.get(field)
                    if t is not None:
                        t = int(t)
                        if t >= 3600:
                            parts.append(f"{t // 3600}h {(t % 3600) // 60}m")
                        elif t >= 60:
                            parts.append(f"{t // 60}m {t % 60}s")
                        else:
                            parts.append(f"{t}s")
                        break
                for field in ("surge_cost", "cost", "fuel"):
                    c = data.get(field)
                    if c is not None:
                        parts.append(f"cost:{c}")
                        break
                if not parts:
                    parts = [f"{k}:{v}" for k, v in list(data.items())[:4]]
                self.toastMessage.emit("info", "DRY RUN  " + "  ".join(parts))
            else:
                self.toastMessage.emit("info", f"DRY RUN: {str(data)[:80]}")
        elif key == "asteroids":
            self._asteroids = data if isinstance(data, list) else self._to_list(data)
            self.asteroidsChanged.emit()
        elif key == "system_map":
            if isinstance(data, list):
                self._system_map = data
            elif isinstance(data, dict):
                for k in ("locations", "items", "results", "data"):
                    if k in data and isinstance(data[k], list):
                        self._system_map = data[k]
                        break
                else:
                    self._system_map = [data]
            self.systemMapChanged.emit()
        elif key in ("beacon_audit", "beacon_audit_more"):
            entries: list = data if isinstance(data, list) else []
            if isinstance(data, dict):
                for k in ("entries", "items", "results", "data", "logs"):
                    if k in data and isinstance(data[k], list):
                        entries = data[k]
                        break
                if not entries:
                    for v in data.values():
                        if isinstance(v, list):
                            entries = v
                            break
            if entries:
                last_id = entries[-1].get("id")
                self._beacon_audit_cursor = last_id if isinstance(last_id, int) else None
            if key == "beacon_audit":
                self._beacon_audit = entries
            else:
                self._beacon_audit = self._beacon_audit + entries
            self.beaconAuditChanged.emit()
        elif key == "bobnet_messages":
            msgs: list = data if isinstance(data, list) else []
            if isinstance(data, dict):
                for k in ("messages", "items", "results", "data"):
                    if k in data and isinstance(data[k], list):
                        msgs = data[k]
                        break
            self._bobnet_messages = msgs
            self.bobnetMessagesChanged.emit()
        elif key.startswith("planet_moons:"):
            desig = key.split(":", 1)[1]
            moons = []
            if isinstance(data, dict):
                moons = data.get("moons") or []
                if not isinstance(moons, list):
                    moons = []
            self._moons_by_planet[desig] = moons
            self.moonsByPlanetChanged.emit()
        elif key == "achievements":
            rows: list = []
            if isinstance(data, list):
                rows = data
            elif isinstance(data, dict):
                for k in ("achievements", "items", "results", "data"):
                    if k in data and isinstance(data[k], list):
                        rows = data[k]
                        break
            self._achievements = rows
            self.achievementsChanged.emit()
        elif key == "reputation":
            rows2: list = []
            if isinstance(data, list):
                rows2 = data
            elif isinstance(data, dict):
                for k in ("reputation", "reputations", "items", "results", "data"):
                    if k in data and isinstance(data[k], list):
                        rows2 = data[k]
                        break
                if not rows2:
                    # Flat dict {species: level} → list of {name, value}
                    rows2 = [{"name": k, "value": v} for k, v in data.items()
                              if not isinstance(v, (dict, list))]
            self._reputation = rows2
            self.reputationChanged.emit()
        elif key == "locations_overview":
            raw = data.get("locations", {}) if isinstance(data, dict) else {}
            rows = [
                {"code": code, **counts}
                for code, counts in raw.items()
                if isinstance(counts, dict)
            ]
            rows.sort(key=lambda r: r.get("devices", 0), reverse=True)
            self._locations_overview = rows
            self.locationsOverviewChanged.emit()
        elif key == "account":
            reps = []
            if isinstance(data, dict):
                raw = data.get("replicants", [])
                for r in (raw if isinstance(raw, list) else []):
                    if isinstance(r, dict):
                        reps.append({"code": r.get("code", ""), "name": r.get("name", r.get("code", ""))})
                    elif isinstance(r, str):
                        reps.append({"code": r, "name": r})
            # When no replicant is selected yet, show all (startup picker).
            # When one is active, filter it out (switcher only shows others).
            self._account_replicants = reps if not self._code else [r for r in reps if r["code"] != self._code]
            self.accountReplicantsChanged.emit()
        elif key == "action:bobnet_send":
            self._set_status("IDLE")
            if self._bobnet_relay_code:
                self._dispatch("bobnet_messages", self._client.get_bobnet_messages,
                               self._bobnet_relay_code)
        elif key.startswith("relay_network:"):
            relay_code = key.split(":", 1)[1]
            if isinstance(data, dict):
                self._relay_networks[relay_code] = data
                self.relayNetworkChanged.emit()
        elif key == "action:scan":
            belts = data.get("asteroid_belt", {}).get("belts", []) if isinstance(data, dict) else []
            self._asteroid_belts = belts
            self.asteroidBeltsChanged.emit()
            self._planets = data.get("planets", []) if isinstance(data, dict) else []
            self._moons_by_planet = {}
            self.planetsChanged.emit()
            self.moonsByPlanetChanged.emit()
            self.scanComplete.emit()
            self._set_status("IDLE")
            n = len(belts)
            self.toastMessage.emit("info", f"SCAN complete — {n} belt{'s' if n != 1 else ''} found")
            self.refresh()
            self.fetchAsteroids()
            self.fetchSystemMap()
            self.fetchPlanetMoons()
        elif key == "traders":
            self._traders = self._to_list(data)
            self.tradersChanged.emit()
        elif key == "shop_trades":
            self._shop_trades = self._to_list(data)
            self.shopTradesChanged.emit()
        elif key == "messages":
            msg_data, unread = data if isinstance(data, tuple) else (data, 0)
            msgs = self._to_list(msg_data)
            # _to_list only checks known envelope keys; if the API uses an
            # unknown key we'd get [] while the unread header is non-zero.
            # Fall back to the first list value found in the dict.
            if not msgs and isinstance(msg_data, dict):
                for v in msg_data.values():
                    if isinstance(v, list):
                        msgs = v
                        break
            self._messages = msgs
            self._unread_count = int(unread)
            self.messagesChanged.emit()
            self.unreadCountChanged.emit()
        elif key == "action:mark_read":
            self._dispatch("messages", self._client.get_messages, 200, True)
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
        elif key == "action:scan_devices":
            devices = []
            if isinstance(data, dict):
                devices = data.get("devices", [])
            elif isinstance(data, list):
                devices = data
            self._scanned_devices = devices
            self.scannedDevicesChanged.emit()
            self._set_status("IDLE")
            n = len(devices)
            self.toastMessage.emit("info", f"SCAN DEVICES — {n} device{'s' if n != 1 else ''} detected")
        elif key in ("directory", "directory_more"):
            replicants: list = []
            cursor = None
            if isinstance(data, dict):
                replicants = data.get("replicants", [])
                cursor = data.get("next_cursor")
            elif isinstance(data, list):
                replicants = data
            self._directory_cursor = cursor if isinstance(cursor, int) else None
            if key == "directory":
                self._directory = replicants
            else:
                self._directory = self._directory + replicants
            self.directoryChanged.emit()
        elif key == "megastructure":
            if isinstance(data, list):
                self._megastructure = data[0] if data else {}
            elif isinstance(data, dict):
                for k in ("megastructure",):
                    if k in data and isinstance(data[k], dict):
                        self._megastructure = data[k]
                        break
                else:
                    self._megastructure = data if data else {}
            else:
                self._megastructure = {}
            self.megastructureChanged.emit()
        elif key == "megastructure_leaderboard":
            rows3: list = []
            if isinstance(data, list):
                rows3 = data
            elif isinstance(data, dict):
                for k in ("replicants", "entries", "items", "results", "data"):
                    if k in data and isinstance(data[k], list):
                        rows3 = data[k]
                        break
            self._megastructure_leaderboard = rows3
            self.megastructureLeaderboardChanged.emit()
        elif key == "action:megastructure_contribute":
            self._set_status("IDLE")
            accepted = data.get("accepted", []) if isinstance(data, dict) else []
            rejected = data.get("rejected", []) if isinstance(data, dict) else []
            progress = data.get("progress") if isinstance(data, dict) else None
            msg = f"CONTRIBUTED {len(accepted)}"
            if rejected:
                msg += f" ({len(rejected)} REJECTED)"
            if progress is not None:
                msg += f" — {int(progress * 100)}% COMPLETE"
            self.toastMessage.emit("info", msg)
            self.fetchMegastructure()
        elif key == "action:feedback":
            self._set_status("IDLE")
            self.toastMessage.emit("info", "FEEDBACK RECEIVED — thank you")
        elif key.startswith("action:"):
            action = key.split(":", 1)[1]
            self._set_status("IDLE")
            self.toastMessage.emit("info", f"{action.upper()} complete")
            self.refresh()

    def _on_error(self, key: str, error: str):
        # Asteroid lookup fails silently — many systems have none
        if key == "asteroids":
            self._asteroids = []
            self.asteroidsChanged.emit()
            return
        # Moon lookups fail silently — not all planets expose moon detail
        if key.startswith("planet_moons:"):
            desig = key.split(":", 1)[1]
            self._moons_by_planet.setdefault(desig, [])
            self.moonsByPlanetChanged.emit()
            return
        # Megastructure lookup fails silently — not all locations have one
        if key == "megastructure":
            self._megastructure = {}
            self.megastructureChanged.emit()
            return
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
