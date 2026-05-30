import sys
import json
from pathlib import Path

from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

from backend import Backend

CONFIG_PATH = Path(__file__).parent / "config.json"


def load_config() -> dict:
    if CONFIG_PATH.exists():
        with open(CONFIG_PATH) as f:
            return json.load(f)
    return {}


if __name__ == "__main__":
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Replicant Space")
    app.setOrganizationName("ReplicantSpace")

    config = load_config()
    backend = Backend(config)

    engine = QQmlApplicationEngine()
    engine.addImportPath(Path(__file__).parent)
    engine.rootContext().setContextProperty("backend", backend)
    engine.loadFromModule("ReplicantSpaceGUI", "Main")

    if not engine.rootObjects():
        sys.exit(-1)

    sys.exit(app.exec())
