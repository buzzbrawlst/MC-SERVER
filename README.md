# MC-SERVER

Windows-first Minecraft network foundation: Velocity proxy, private Paper backends, local manager UI, PowerShell helpers, and a custom plugin scaffold. Server jars, worlds, paid plugins, and secrets are not included.

## Quick start
1. Install Java, Python 3.11+, and Git.
2. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\Check-Prerequisites.ps1`.
3. Run `py -3.11 -m venv .venv` then `.\\.venv\\Scripts\\python -m pip install -r manager\\requirements.txt`.
4. Copy `config\\network.example.json` to `config\\network.json`; review it before enabling instances.
5. Run `powershell -ExecutionPolicy Bypass -File .\\scripts\\Start-Manager.ps1`.
6. Open http://127.0.0.1:8765.

Download jars/plugins only from official sources. Expose only Velocity port 25565; keep Paper backends and the unauthenticated manager on localhost. Configure modern forwarding and matching backend settings before public launch. Never commit secrets, worlds, player data, logs, or EULAs.

Planned modes: Lobby, flagship Survival SMP, Lifesteal, Skyblock, BedWars, Duels. All instances are disabled by default. This is a starter foundation, not production-ready; see docs/ROADMAP.md and docs/OPERATIONS.md.