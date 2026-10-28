# Local test runbook

## Before starting
- Use Windows PowerShell from the repository root.
- Install a Java runtime supported by the current stable Paper build, Python 3.11+, and Git.
- Run \`scripts/Check-Prerequisites.ps1\`.
- Run \`powershell -ExecutionPolicy Bypass -File .\scripts\Prepare-TestNetwork.ps1\`. It downloads latest stable Paper and Velocity builds from PaperMC's official API.
- The script generates a strong forwarding secret and configures Paper backends to bind to \`127.0.0.1\`. It does not expose backend ports or accept any EULA.
- Read each server's \`runtime\<mode>\eula.txt\`. Change \`eula=false\` to \`eula=true\` only if you agree to the Minecraft EULA.
- If you want the starter plugin's \`/network\` and \`/spawn\` commands, install Gradle and rerun preparation so it builds and copies the plugin.

## Start and join
1. Run \`powershell -ExecutionPolicy Bypass -File .\scripts\Start-Manager.ps1\`.
2. In the dashboard, start Lobby, then Survival, then Velocity. Wait for each backend's log to report startup complete before starting Velocity.
3. Join from Minecraft Java Edition using \`localhost:25565\`.
4. If a backend refuses a connection, inspect its \`manager-console.log\` and confirm the forwarding secret in \`runtime\proxy\forwarding.secret\` matches each backend's \`config\paper-global.yml\`.
5. Use \`Prepare-TestNetwork.ps1 -EnableAllModes\` only when the PC has enough free RAM; this enables all configured instances in the ignored local config.

## Current test scope
This is a local Java smoke-test network. Bedrock/Geyser, production moderation/economy/claims, full Lifesteal/Skyblock/BedWars/Duels gameplay, backups, and production load/security tests are not implemented yet. Do not expose it publicly.

## Troubleshooting
- Missing JAR: rerun Prepare-TestNetwork.ps1.
- EULA error: review and manually accept in each instance folder, if you agree.
- Port already in use: close the process using that port or change the port consistently in network.json, server.properties and velocity.toml.
- Unsupported Java: install the runtime required by the downloaded Paper version and rerun java -version.
- Gradle unavailable: the base network can still run, but custom commands won't exist until the plugin is built and copied into each backend's plugins folder.
