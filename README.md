# MC-SERVER

Windows-first local Minecraft network starter for Java Edition. Velocity is the entry point; Paper backends are configured for Lobby, flagship Enhanced SMP Survival, Lifesteal, Skyblock, BedWars and Duels.

## Prepare a local test network
1. Install Git, Python 3.11+, and a Java runtime supported by the current stable Paper build.
2. From the repository root, run `powershell -ExecutionPolicy Bypass -File .\scripts\Check-Prerequisites.ps1`.
3. Run `powershell -ExecutionPolicy Bypass -File .\scripts\Prepare-TestNetwork.ps1`. Add `-EnableAllModes` only if your PC has enough free RAM.
4. Read each generated `runtime\<mode>\eula.txt`; change `eula=false` to `eula=true` only if you agree to the Minecraft EULA.
5. Run `powershell -ExecutionPolicy Bypass -File .\scripts\Start-Manager.ps1`.
6. In the dashboard, start Lobby and Survival, wait until their logs say startup is complete, then start Velocity. Join Java Edition at `localhost:25565`.

The preparation script downloads stable Paper and recommended Velocity builds through PaperMC Fill v3 and verifies SHA-256 checksums. It also downloads Geyser-Velocity and Floodgate from GeyserMC's official download API, generates a random forwarding secret, and binds Paper backends to loopback. The default local test profile uses conservative memory caps and enables only Proxy, Lobby and Survival. It does not accept EULAs. If Gradle is installed, it also builds and installs the starter custom plugin. Keep the manager bound to `127.0.0.1`; it has no authentication.

## Development and checks
- Manager: FastAPI + local web dashboard.
- Custom plugin: Java/Paper Gradle project under `custom-plugins/network-core`.
- Tests: `python -m pip install -r manager/requirements.txt -r requirements-dev.txt`, then `python -m pytest -q`.
- GitHub Actions checks Python tests and builds the plugin.
- See [local test runbook](docs/LOCAL-TESTING.md), [operations](docs/OPERATIONS.md), and [roadmap](docs/ROADMAP.md).

## Scope
This is a local Java smoke-test foundation, not a finished public network. Full Bedrock/Geyser setup, production gameplay for every mode, shared persistence, backups, performance profiling and production security review remain roadmap items. Server jars, worlds, player data, EULAs, secrets and local config are not committed.
