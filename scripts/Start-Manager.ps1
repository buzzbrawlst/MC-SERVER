$ErrorActionPreference = "Stop"
if (-not (Test-Path ".\\.venv\\Scripts\\python.exe")) { py -3.11 -m venv .venv }
& .\\.venv\\Scripts\\python.exe -m pip install -r .\\manager\\requirements.txt
if ($LASTEXITCODE -ne 0) { throw "Dependency installation failed." }
Write-Host "Starting manager at http://127.0.0.1:8765" -ForegroundColor Cyan
& .\\.venv\\Scripts\\python.exe -m uvicorn manager.app:app --host 127.0.0.1 --port 8765
