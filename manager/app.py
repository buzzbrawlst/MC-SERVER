"""Local-only manager. Bind to 127.0.0.1; never expose this unauthenticated API."""
import json, subprocess, threading, time
from pathlib import Path
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

ROOT=Path(__file__).resolve().parents[1]
CONFIG=ROOT/"config"/"network.json"
EXAMPLE=ROOT/"config"/"network.example.json"
WEB=Path(__file__).resolve().parent/"static"
LOCK=threading.RLock()
PROCESSES={}
LOGS={}
STARTED={}
app=FastAPI(title="MC-SERVER Manager",version="0.1.0",docs_url=None,redoc_url=None)
app.mount("/static",StaticFiles(directory=WEB),name="static")

class Action(BaseModel):
    action: str

def config():
    try: data=json.loads((CONFIG if CONFIG.exists() else EXAMPLE).read_text(encoding="utf-8"))
    except (OSError,json.JSONDecodeError) as exc: raise HTTPException(500,"Invalid network config: "+str(exc))
    if not isinstance(data.get("servers"),list): raise HTTPException(500,"Configuration needs a servers array.")
    return data

def get_server(sid):
    for s in config()["servers"]:
        if s.get("id")==sid: return s
    raise HTTPException(404,"Unknown server id.")

def directory(s):
    path=(ROOT/s["directory"]).resolve()
    allowed=(ROOT/"runtime").resolve()
    if path!=allowed and allowed not in path.parents: raise HTTPException(400,"Server directory must be inside repository runtime.")
    return path

def status(s):
    sid=s["id"]
    with LOCK:
        p=PROCESSES.get(sid); running=p is not None and p.poll() is None
        if p is not None and not running:
            PROCESSES.pop(sid,None); h=LOGS.pop(sid,None)
            if h: h.close()
        return {"id":sid,"display_name":s.get("display_name",sid),"kind":s.get("kind","paper"),"port":s.get("port"),
        "enabled":bool(s.get("enabled",False)),"public":bool(s.get("public",False)),"running":running,"pid":p.pid if running else None,
        "uptime_seconds":int(time.time()-STARTED[sid]) if running and sid in STARTED else 0}

@app.get("/")
def index(): return FileResponse(WEB/"index.html")

@app.get("/api/health")
def health(): return {"ok":True,"network":config().get("network_name","MC-SERVER"),"manager":"local"}

@app.get("/api/servers")
def servers(): return {"servers":[status(s) for s in config()["servers"]]}

@app.get("/api/config")
def config_summary():
    c=config()
    return {"network_name":c.get("network_name","MC-SERVER"),"manager":c.get("manager",{}),"runtime_root":c.get("runtime_root"),
    "config_file":str((CONFIG if CONFIG.exists() else EXAMPLE).relative_to(ROOT)),"configured_servers":len(c["servers"]),
    "note":"Secrets and process arguments are omitted."}

@app.get("/api/servers/{sid}/logs")
def logs(sid: str, lines: int=100):
    s=get_server(sid); p=directory(s)/"manager-console.log"
    if not p.exists(): return {"server_id":sid,"lines":[],"note":"No log yet. Install the jar and start this instance."}
    try: return {"server_id":sid,"lines":p.read_text(encoding="utf-8",errors="replace").splitlines()[-max(1,min(lines,500)):]}
    except OSError as exc: raise HTTPException(500,"Unable to read log: "+str(exc))

@app.post("/api/servers/{sid}/action")
def server_action(sid: str, request: Action):
    if request.action not in {"start","stop","restart"}: raise HTTPException(400,"Action must be start, stop, or restart.")
    s=get_server(sid)
    if not s.get("enabled",False): raise HTTPException(409,"Instance disabled. Review network.json before enabling.")
    if request.action=="stop": return stop(s)
    if request.action=="restart": stop(s); time.sleep(1)
    return start(s)

def start(s):
    sid=s["id"]
    with LOCK:
        old=PROCESSES.get(sid)
        if old is not None and old.poll() is None: return {"ok":True,"message":"Already running.","server":status(s)}
        folder=directory(s); name=s.get("jar","")
        if not name or Path(name).name!=name or not name.lower().endswith(".jar"): raise HTTPException(400,"Jar must be a simple .jar filename.")
        jar=folder/name
        if not jar.is_file(): raise HTTPException(409,"Missing jar: "+str(jar)+". Download it from the official project website.")
        folder.mkdir(parents=True,exist_ok=True); c=config()
        minimum,maximum=str(s.get("memory_min","512M")),str(s.get("memory_max","1G"))
        for v in (minimum,maximum):
            if len(v)<2 or v[-1] not in "MG" or not v[:-1].isdigit(): raise HTTPException(400,"Memory values must look like 512M or 2G.")
        h=(folder/"manager-console.log").open("a",encoding="utf-8",buffering=1)
        cmd=[c.get("java_command","java"),"-Xms"+minimum,"-Xmx"+maximum,"-jar",jar.name,"nogui"]
        try: p=subprocess.Popen(cmd,cwd=str(folder),stdin=subprocess.PIPE,stdout=h,stderr=subprocess.STDOUT,shell=False,creationflags=getattr(subprocess,"CREATE_NEW_PROCESS_GROUP",0))
        except OSError as exc: h.close(); raise HTTPException(500,"Could not launch Java: "+str(exc))
        PROCESSES[sid],LOGS[sid],STARTED[sid]=p,h,time.time()
        return {"ok":True,"message":"Process launched; check logs for readiness.","server":status(s)}

def stop(s):
    sid=s["id"]
    with LOCK:
        p=PROCESSES.get(sid)
        if p is None or p.poll() is not None:
            PROCESSES.pop(sid,None); return {"ok":True,"message":"Not running.","server":status(s)}
        try:
            if p.stdin: p.stdin.write(b"stop\n"); p.stdin.flush()
            p.wait(timeout=25)
        except (subprocess.TimeoutExpired,BrokenPipeError,OSError):
            p.terminate()
            try: p.wait(timeout=8)
            except subprocess.TimeoutExpired: p.kill(); p.wait(timeout=5)
        PROCESSES.pop(sid,None); STARTED.pop(sid,None); h=LOGS.pop(sid,None)
        if h: h.close()
        return {"ok":True,"message":"Stopped.","server":status(s)}

@app.on_event("shutdown")
def shutdown():
    for s in config()["servers"]:
        try: stop(s)
        except Exception: pass
