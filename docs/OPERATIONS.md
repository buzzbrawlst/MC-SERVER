# Operations and safety

Download server jars and plugins only from official sources; check compatibility. Accept each EULA only if you agree to it. Expose only Velocity's player-facing port; bind Paper backends to 127.0.0.1. Configure modern forwarding and matching backend settings with a strong random secret stored outside Git. Do not launch publicly with forwarding partly configured. Verify keys against current official documentation.

Back up worlds and plugin/player data using a consistent method, keep dated copies on another disk, and periodically restore into a separate test folder. In an incident, stop the instance, preserve logs and backups, record recent changes, restore a verified recovery point, and rotate exposed secrets.

Manager limitations: it supervises processes started during its lifetime only; it does not yet reattach after restart, download jars, stream live console, edit configs, or create backups. Process status is not readiness. Manager has no authentication: keep it on loopback.
