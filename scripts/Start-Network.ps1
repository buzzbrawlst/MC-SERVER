$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo
$runtime = Join-Path $repo "runtime"
$managerUrl = "http://127.0.0.1:8765"

function Stop-WithMessage([string]$Message) {
    Write-Host ""
    Write-Host $Message -ForegroundColor Yellow
    exit 1
}
function Test-Manager {
    try { $null = Invoke-RestMethod -Uri "$managerUrl/api/health" -TimeoutSec 2; return $true }
    catch { return $false }
}
function Wait-ForServerReady([string]$Id, [string]$Name, [int]$TimeoutSeconds = 180) {
    $config = Get-Content (Join-Path $repo "config\network.json") -Raw | ConvertFrom-Json
    $server = $config.servers | Where-Object { $_.id -eq $Id } | Select-Object -First 1
    $logPath = Join-Path (Join-Path $repo $server.directory) "manager-console.log"
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    Write-Host "Waiting for $Name to finish starting..." -ForegroundColor Cyan
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 2
        if (Test-Path $logPath) {
            $tail = Get-Content $logPath -Tail 100 -ErrorAction SilentlyContinue
            $joined = $tail -join "`n"
            if (($Id -eq "proxy" -and ($joined -match "Done \(" -or $joined -match "Listening on")) -or ($Id -ne "proxy" -and $joined -match "Done \(")) {
                Write-Host "$Name is ready." -ForegroundColor Green
                return
            }
            if ($joined -match "You need to agree to the EULA|eula\.txt") {
                Stop-WithMessage "$Name needs EULA acceptance. Read $logPath, then only if you agree, set eula=true in its eula.txt and rerun start.bat."
            }
        }
        try {
            $states = (Invoke-RestMethod -Uri "$managerUrl/api/servers" -TimeoutSec 2).servers
            $state = $states | Where-Object { $_.id -eq $Id } | Select-Object -First 1
            if (-not $state -or -not $state.running) {
                if (Test-Path $logPath) { Write-Host "Latest log for ${Name}:" -ForegroundColor Yellow; Get-Content $logPath -Tail 20 }
                Stop-WithMessage "$Name stopped before reporting ready. Check its log: $logPath"
            }
        } catch { }
    }
    if (Test-Path $logPath) { Get-Content $logPath -Tail 30 }
    Stop-WithMessage "$Name did not report ready within $TimeoutSeconds seconds. Check: $logPath"
}

Write-Host "Checking Java..." -ForegroundColor Cyan
if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
    Stop-WithMessage "Java was not found. Install a Java runtime supported by the latest PaperMC build, then run start.bat again."
}
java -version
if ($LASTEXITCODE -ne 0) { Stop-WithMessage "Java did not run successfully." }

$configPath = Join-Path $repo "config\network.json"
if (-not (Test-Path $configPath) -or -not (Test-Path (Join-Path $runtime "proxy\velocity.jar")) -or -not (Test-Path (Join-Path $runtime "survival\paper.jar"))) {
    Write-Host "First-time setup: preparing the local test network..." -ForegroundColor Cyan
    & (Join-Path $repo "scripts\Prepare-TestNetwork.ps1")
    if ($LASTEXITCODE -ne 0) { Stop-WithMessage "Network preparation failed. Fix the error above and run start.bat again." }
}
$config = Get-Content $configPath -Raw | ConvertFrom-Json
$enabledPaper = @($config.servers | Where-Object { $_.kind -eq "paper" -and $_.enabled })
if ($enabledPaper.Count -eq 0) { Stop-WithMessage "No Paper servers are enabled in config\network.json." }
$notAccepted = @()
foreach ($server in $enabledPaper) {
    $eulaPath = Join-Path (Join-Path $repo $server.directory) "eula.txt"
    if (-not (Test-Path $eulaPath) -or (Get-Content $eulaPath -Raw) -notmatch "(?m)^\s*eula=true\s*$") { $notAccepted += $eulaPath }
}
if ($notAccepted.Count -gt 0) {
    Write-Host "One-time setup is ready, but Minecraft EULA acceptance must be explicit." -ForegroundColor Yellow
    Write-Host "Read https://www.minecraft.net/eula. If you agree, change eula=false to eula=true in:"
    $notAccepted | ForEach-Object { Write-Host "  $_" }
    Stop-WithMessage "After accepting the EULA in each listed file, double-click start.bat again."
}

if (-not (Test-Manager)) {
    Write-Host "Starting local management service..." -ForegroundColor Cyan
    $managerScript = Join-Path $repo "scripts\Start-Manager.ps1"
    $managerArgs = "-NoLogo -NoProfile -ExecutionPolicy Bypass -File \`"$managerScript\`""
    Start-Process -FilePath "powershell.exe" -ArgumentList $managerArgs -WorkingDirectory $repo -WindowStyle Minimized
    $deadline = (Get-Date).AddSeconds(90)
    while ((Get-Date) -lt $deadline -and -not (Test-Manager)) { Start-Sleep -Seconds 2 }
    if (-not (Test-Manager)) { Stop-WithMessage "The manager did not start. Check Python 3.11+, pip, and the minimized manager window." }
} else { Write-Host "Using the already-running local manager." -ForegroundColor Green }

foreach ($id in @("lobby", "survival", "lifesteal", "skyblock", "bedwars", "duels")) {
    $server = $config.servers | Where-Object { $_.id -eq $id -and $_.enabled -and $_.kind -eq "paper" } | Select-Object -First 1
    if (-not $server) { continue }
    Write-Host "Starting $($server.display_name)..." -ForegroundColor Cyan
    try {
        $body = @{ action = "start" } | ConvertTo-Json -Compress
        $null = Invoke-RestMethod -Method Post -Uri "$managerUrl/api/servers/$id/action" -ContentType "application/json" -Body $body -TimeoutSec 10
    } catch { Stop-WithMessage "Could not start $($server.display_name): $($_.Exception.Message)" }
    Wait-ForServerReady -Id $id -Name $server.display_name
}
$proxy = $config.servers | Where-Object { $_.id -eq "proxy" -and $_.enabled } | Select-Object -First 1
if ($proxy) {
    Write-Host "Starting Velocity proxy..." -ForegroundColor Cyan
    try {
        $body = @{ action = "start" } | ConvertTo-Json -Compress
        $null = Invoke-RestMethod -Method Post -Uri "$managerUrl/api/servers/proxy/action" -ContentType "application/json" -Body $body -TimeoutSec 10
    } catch { Stop-WithMessage "Could not start Velocity: $($_.Exception.Message)" }
    Wait-ForServerReady -Id "proxy" -Name "Velocity proxy"
}
Write-Host ""
Write-Host "MC-SERVER is running!" -ForegroundColor Green
Write-Host "Java Edition address: localhost:25565"
Write-Host "Manager dashboard: $managerUrl"
Write-Host "Logs: runtime\<server>\manager-console.log"
Write-Host "Use the dashboard to stop instances cleanly."
try { Start-Process $managerUrl } catch { }
