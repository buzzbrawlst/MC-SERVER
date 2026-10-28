import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_unique_instance_ids_and_ports():
    data = json.loads((ROOT / "config/network.example.json").read_text(encoding="utf-8"))
    ids = [s["id"] for s in data["servers"]]
    ports = [s["port"] for s in data["servers"]]
    assert len(ids) == len(set(ids))
    assert len(ports) == len(set(ports))
    assert "survival" in ids and "proxy" in ids


def test_instances_disabled_by_default():
    data = json.loads((ROOT / "config/network.example.json").read_text(encoding="utf-8"))
    assert all(s["enabled"] is False for s in data["servers"])


def test_only_proxy_public_by_default():
    data = json.loads((ROOT / "config/network.example.json").read_text(encoding="utf-8"))
    assert [s["id"] for s in data["servers"] if s["public"]] == ["proxy"]
