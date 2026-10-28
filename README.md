# MC-SERVER

Windows-first local Minecraft network starter for Java Edition. Velocity is the entry point; Paper backends are configured for Lobby, flagship Enhanced SMP Survival, Lifesteal, Skyblock, BedWars and Duels.

## Quick start (Windows)

1. Install Git, Python 3.11+, and a Java runtime supported by the current stable Paper build.
2. Download/clone this repository and open its folder.
3. Double-click **`start.bat`**.
4. On first run, it prepares the network and downloads the server files. Read the Minecraft EULA at https://www.minecraft.net/eula. If you agree, change `eula=false` to `eula=true` in each file the launcher lists under `runtime\<mode>\eula.txt`.
5. Double-click **`start.bat`** again. It starts enabled Paper backends in order, waits for them to report ready, then starts Velocity. Join Java Edition using **`localhost:25565`**.

After the one-time setup and EULA step, `start.bat` is the normal launcher. It also opens the local manager dashboard at http://127.0.0.1:8765. The default profile starts only Lobby and Survival (plus Velocity) to conserve RAM. Do not close the minimized manager window while the network is running. Use the dashboard to stop instances cleanly.

To enable every configured mode, edit `config\network.json` or run `scripts\Prepare-TestNetwork.ps1 -EnableAllModes` in PowerShell before starting. This uses more RAM and is not recommended for a low-memory PC.

## What the launcher does

The preparation script downloads stable Paper and recommended Velocity builds through PaperMC Fill v3 and verifies SHA-256 checksums. It downloads Geyser-Velocity and Floodgate from GeyserMC's official download API, generates a random forwarding secret, and binds Paper backends to loopback. It does not accept Minecraft EULAs on your behalf. If Gradle is installed, setup also builds and installs the starter custom plugin. Keep the manager bound to `127.0.0.1`; it has no authentication.

## Development and checks
- Launcher: `start.bat` → `scripts/Start-Network.ps1`.
- Manager: FastAPI + local web dashboard.
- Custom plugin: Java/Paper Gradle project under `custom-plugins/network-core`.
- Tests: `python -m pip install -r manager/requirements.txt -r requirements-dev.txt`, then `python -m pytest -q`.
- GitHub Actions checks Python tests and builds the plugin.
- See [local test runbook](docs/LOCAL-TESTING.md), [operations](docs/OPERATIONS.md), and [roadmap](docs/ROADMAP.md).

## Scope

This is a local Java smoke-test foundation, not a finished public network. Full Bedrock/Geyser setup, production gameplay for every mode, shared persistence, backups, performance profiling and production security review remain roadmap items. Server jars, worlds, player data, EULAs, secrets and local config are not committed.
