"""Local-only process manager for the MC-SERVER development network."""
import json
import re
import subprocess
import threading
import time
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "config" / "network.json"
EXAMPLE = ROOT / "config" / "network.example.json"
WEB = Path(__file__).resolve().parent / "static"
RUNTIME = (ROOT / "runtime").resolve()
LOCK = threading.RLock()
PROCESSES = {}
LOGS = {}
STARTED = {}
app = FastAPI(title="MC-SERVER Manager", version="0.2.0", docs_url=None, redoc_url=None)
app.mount("/static", StaticFiles(directory=WEB), name="static")


class Action(BaseModel):
    action: str


def config():
    try:
        data = json.loads((CONFIG if CONFIG.exists() else EXAMPLE).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise HTTPException(500, "Invalid network config: " + str(exc))
    if not isinstance(data.get("servers"), list):
        raise HTTPException(500, "Configuration needs a servers array.")
    ids = [s.get("id") for s in data["servers"]]
    if any(not isinstance(i, str) or not re.fullmatch(r"[a-z0-9_-]+", i) for i in ids) or len(ids) != len(set(ids)):
        raise HTTPException(500, "Server IDs must be unique lowercase letters, numbers, _ or -.")
    return data


def get_server(sid):
    for server in config()["servers"]:
        if server.get("id") == sid:
            return server
    raise HTTPException(404, "Unknown server id.")


def directory(server):
    raw = server.get("directory")
    if not isinstance(raw, str) or not raw:
        raise HTTPException(400, "Server directory is missing.")
    path = (ROOT / raw).resolve()
    if path != RUNTIME and RUNTIME not in path.parents:
        raise HTTPException(400, "Server directory must be inside repository runtime.")
    return path


def status(server):
    sid = server["id"]
    with LOCK:
        process = PROCESSES.get(sid)
        running = process is not None and process.poll() is None
        if process is not None and not running:
            PROCESSES.pop(sid, None)
            STARTED.pop(sid, None)
            handle = LOGS.pop(sid, None)
            if handle:
                handle.close()
        return {
            "id": sid,
            "display_name": server.get("display_name", sid),
            "kind": server.get("kind", "paper"),
            "port": server.get("port"),
            "enabled": bool(server.get("enabled", False)),
            "public": bool(server.get("public", False)),
            "running": running,
            "pid": process.pid if running else None,
            "uptime_seconds": int(time.time() - STARTED[sid]) if running and sid in STARTED else 0,
        }


@app.get("/")
def index():
    return FileResponse(WEB / "index.html")


@app.get("/api/health")
def health():
    return {"ok": True, "network": config().get("network_name", "MC-SERVER"), "manager": "local"}


@app.get("/api/servers")
def servers():
    return {"servers": [status(server) for server in config()["servers"]]}


@app.get("/api/config")
def config_summary():
    data = config()
    return {
        "network_name": data.get("network_name", "MC-SERVER"),
        "manager": data.get("manager", {}),
        "runtime_root": data.get("runtime_root"),
        "config_file": str((CONFIG if CONFIG.exists() else EXAMPLE).relative_to(ROOT)),
        "configured_servers": len(data["servers"]),
        "note": "Secrets and process arguments are omitted.",
    }


@app.get("/api/servers/{sid}/logs")
def logs(sid: str, lines: int = 100):
    server = get_server(sid)
    path = directory(server) / "manager-console.log"
    if not path.exists():
        return {"server_id": sid, "lines": [], "note": "No log yet. Prepare and start this instance first."}
    try:
        selected = path.read_text(encoding="utf-8", errors="replace").splitlines()
        return {"server_id": sid, "lines": selected[-max(1, min(lines, 500)):]}
    except OSError as exc:
        raise HTTPException(500, "Unable to read log: " + str(exc))


@app.post("/api/servers/{sid}/action")
def server_action(sid: str, request: Action):
    if request.action not in {"start", "stop", "restart"}:
        raise HTTPException(400, "Action must be start, stop, or restart.")
    server = get_server(sid)
    if not server.get("enabled", False):
        raise HTTPException(409, "Instance disabled. Review config/network.json before enabling.")
    if request.action == "stop":
        return stop(server)
    if request.action == "restart":
        stop(server)
        time.sleep(1)
    return start(server)


def start(server):
    sid = server["id"]
    with LOCK:
        old = PROCESSES.get(sid)
        if old is not None and old.poll() is None:
            return {"ok": True, "message": "Already running.", "server": status(server)}
        folder = directory(server)
        name = server.get("jar", "")
        if not name or Path(name).name != name or not name.lower().endswith(".jar"):
            raise HTTPException(400, "Jar must be a simple .jar filename.")
        jar = folder / name
        if not jar.is_file():
            raise HTTPException(409, "Missing jar: " + str(jar) + ". Run scripts/Prepare-TestNetwork.ps1.")
        minimum, maximum = str(server.get("memory_min", "512M")), str(server.get("memory_max", "1G"))
        for value in (minimum, maximum):
            if not re.fullmatch(r"[1-9][0-9]*[MG]", value):
                raise HTTPException(400, "Memory values must look like 512M or 2G.")
        folder.mkdir(parents=True, exist_ok=True)
        data = config()
        command = [str(data.get("java_command", "java")), "-Xms" + minimum, "-Xmx" + maximum, "-jar", jar.name]
        if server.get("kind", "paper") == "paper":
            command.append("nogui")
        handle = (folder / "manager-console.log").open("a", encoding="utf-8", buffering=1)
        try:
            process = subprocess.Popen(
                command, cwd=str(folder), stdin=subprocess.PIPE,
                stdout=handle, stderr=subprocess.STDOUT, shell=False,
                creationflags=getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0),
            )
        except OSError as exc:
            handle.close()
            raise HTTPException(500, "Could not launch Java: " + str(exc))
        PROCESSES[sid], LOGS[sid], STARTED[sid] = process, handle, time.time()
        return {"ok": True, "message": "Process launched; check logs for EULA, startup and readiness.", "server": status(server)}


def stop(server):
    sid = server["id"]
    with LOCK:
        process = PROCESSES.get(sid)
        if process is None or process.poll() is not None:
            PROCESSES.pop(sid, None)
            STARTED.pop(sid, None)
            handle = LOGS.pop(sid, None)
            if handle:
                handle.close()
            return {"ok": True, "message": "Not running.", "server": status(server)}
        try:
            if process.stdin:
                shutdown_command = "shutdown" if server.get("kind") == "velocity" else "stop"
                process.stdin.write((shutdown_command + "\n").encode("utf-8"))
                process.stdin.flush()
            process.wait(timeout=25)
        except (subprocess.TimeoutExpired, BrokenPipeError, OSError):
            process.terminate()
            try:
                process.wait(timeout=8)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
        PROCESSES.pop(sid, None)
        STARTED.pop(sid, None)
        handle = LOGS.pop(sid, None)
        if handle:
            handle.close()
        return {"ok": True, "message": "Stopped.", "server": status(server)}


@app.on_event("shutdown")
def shutdown():
    for server in config()["servers"]:
        try:
            stop(server)
        except Exception:
            pass
