# Replicant Space GUI

A desktop GUI client for [Replicant Space](https://replicant.space/) — an API-first space exploration, resource management, and sandbox game.

Built with Python + PySide6 (Qt6/QML). Dark terminal aesthetic.

---

## Features

- **Status & actions panel** — travel, scan, mine, print devices, teleport, transfer consciousness
- **System scan** — asteroid belts with resource levels, planets, moons, system map, detected other players' devices
- **Survey tab** — deploy and direct survey drones, view resource sites per planet/belt
- **Inventory** — live resource totals with auto-refresh countdown
- **Blueprints** — print devices, pin a blueprint to the sidebar for quick cost reference
- **Trade** — browse nearby traders, open shops, execute trades
- **Locations overview** — all locations where you have devices, resources, or replicants
- **AMI controllers** — manage drone fleets: adopt/release, set survey or belt-search directives
- **FTL relay / BobNet** — view relay network, read and send BobNet messages
- **FTL beacon audit** — filterable arrival/departure log with pagination
- **Messages** — inbox with per-message read marking
- **Standing** — achievements and reputation
- **Galaxy directory** — search and browse all known replicants
- **Megastructure** — view construction progress and requirements at your current location, contribute devices, global leaderboard
- **Profile editor** — update your replicant's public name, pronouns, description, plan, and project
- **Feedback** — submit bug reports and ideas directly from the app
- **Multi-replicant** — switch between all replicants on your account
- Auto-refresh every 30 seconds with inventory refresh countdown

---

## Requirements

- Python 3.10 or newer
- A [Replicant Space](https://replicant.space/) account with an API key

---

## Installation

```bash
git clone https://github.com/storeystory/ReplicantSpaceGUI.git
cd ReplicantSpaceGUI
pip install -r requirements.txt
```

### Configure

Copy the example config and fill in your details:

```bash
cp config.json.example config.json
```

Edit `config.json`:

```json
{
  "api_key": "your_api_key_here",
  "replicant_code": "XXXXXXXX",
  "webhook_url": "",
  "api_base": "https://api.replicant.space/v1"
}
```

- `api_key` — found in your [account settings](https://replicant.space/account)
- `replicant_code` — the 8-character code for your primary replicant (you can switch between replicants inside the app)
- `webhook_url` — optional; only needed if you want to register a webhook for notifications
- `api_base` — leave as-is unless you know otherwise

> **`config.json` is in `.gitignore` and will never be committed.** Never share your API key.

### Run

```bash
python main.py
```

---

## Virtual environment (recommended)

```bash
python -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
python main.py
```

---

## Project structure

```
ReplicantSpaceGUI/
├── main.py                  # Entry point — loads config, wires QML engine
├── backend.py               # QObject bridge: properties, slots, async workers
├── api_client.py            # Thin REST wrapper around the Replicant Space API
├── requirements.txt
├── config.json.example      # Copy to config.json and fill in your credentials
└── ReplicantSpaceGUI/
    ├── Main.qml             # Entire UI (single-file QML)
    └── qmldir
```

---

## Notes

- Built in Qt Creator with AI assistance. All code is reviewed and understood before committing.
- Binary releases are not currently provided — the source is the release. Two `pip install` packages and a Python interpreter are all you need.
