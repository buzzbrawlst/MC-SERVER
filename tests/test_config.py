import json
from pathlib import Path

from fastapi.testclient import TestClient

from manager import app as manager


ROOT = Path(__file__).resolve().parents[1]


def test_example_config_has_unique_ids_ports_and_disabled_instances():
    data = json.loads((ROOT / "config/network.example.json").read_text(encoding="utf-8"))
    ids = [s["id"] for s in data["servers"]]
    ports = [s["port"] for s in data["servers"]]
    assert len(ids) == len(set(ids))
    assert len(ports) == len(set(ports))
    assert {"proxy", "lobby", "survival", "lifesteal", "skyblock", "bedwars", "duels"} == set(ids)
    assert all(s["enabled"] is False for s in data["servers"])
    assert [s["id"] for s in data["servers"] if s["public"]] == ["proxy"]


def test_health_and_server_list(monkeypatch):
    monkeypatch.setattr(manager, "CONFIG", ROOT / "missing-test-config.json")
    with TestClient(manager.app) as client:
        assert client.get("/api/health").json()["ok"] is True
        servers = client.get("/api/servers").json()["servers"]
        assert len(servers) == 7
        assert all(s["running"] is False for s in servers)


def test_unknown_server_returns_404(monkeypatch):
    monkeypatch.setattr(manager, "CONFIG", ROOT / "missing-test-config.json")
    with TestClient(manager.app) as client:
        assert client.get("/api/servers/not-a-server/logs").status_code == 404


def test_disabled_instance_cannot_be_started(monkeypatch):
    monkeypatch.setattr(manager, "CONFIG", ROOT / "missing-test-config.json")
    with TestClient(manager.app) as client:
        response = client.post("/api/servers/survival/action", json={"action": "start"})
        assert response.status_code == 409


def test_invalid_action_is_rejected(monkeypatch):
    monkeypatch.setattr(manager, "CONFIG", ROOT / "missing-test-config.json")
    with TestClient(manager.app) as client:
        response = client.post("/api/servers/survival/action", json={"action": "explode"})
        assert response.status_code == 400


def test_manager_rejects_runtime_path_escape():
    import pytest
    from fastapi import HTTPException

    with pytest.raises(HTTPException) as error:
        manager.directory({"directory": "../outside"})
    assert error.value.status_code == 400
