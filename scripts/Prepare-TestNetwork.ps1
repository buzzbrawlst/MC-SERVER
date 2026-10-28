param([switch]$EnableAllModes)
$ErrorActionPreference = "Stop"
$repo = (Get-Location).Path
if (-not (Test-Path (Join-Path $repo "config\network.example.json"))) { throw "Run this script from the MC-SERVER repository root." }
$runtime = Join-Path $repo "runtime"
$headers = @{ "User-Agent" = "MC-SERVER-Local-Test-Setup/0.1 (https://github.com/buzzbrawlst/MC-SERVER)" }

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    $encoding = New-Object System.Text.UTF8Encoding -ArgumentList $false
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Get-LatestPaperJar([string]$Project) {
    $channel = if ($Project -eq "velocity") { "RECOMMENDED" } else { "STABLE" }
    $projectInfo = Invoke-RestMethod -Uri "https://fill.papermc.io/v3/projects/$Project" -Headers $headers
    foreach ($group in $projectInfo.versions.PSObject.Properties) {
        foreach ($version in $group.Value) {
            $versionInfo = Invoke-RestMethod -Uri "https://fill.papermc.io/v3/projects/$Project/versions/$version" -Headers $headers
            $javaMinimum = $versionInfo.java.version.minimum
            $builds = Invoke-RestMethod -Uri "https://fill.papermc.io/v3/projects/$Project/versions/$version/builds" -Headers $headers
            $build = $builds | Where-Object { $_.channel -eq $channel } | Select-Object -First 1
            if (-not $build) { continue }
            $download = $build.downloads.PSObject.Properties["server:default"].Value
            if (-not $download -or -not $download.url -or -not $download.checksums.sha256) { continue }
            return @{ Version = $version; Build = $build.id; Url = $download.url; Sha256 = $download.checksums.sha256; JavaMinimum = $javaMinimum }
        }
    }
    throw "No $channel build found for $Project in the PaperMC Fill v3 API."
}

Write-Host "MC-SERVER local test-network preparation" -ForegroundColor Cyan
Write-Host "This downloads official PaperMC builds. It does NOT accept the Minecraft EULA or expose the network publicly." -ForegroundColor Yellow
if (-not (Get-Command java -ErrorAction SilentlyContinue)) { throw "Java is missing. Install a runtime supported by the selected Paper version, then rerun." }
java -version
New-Item -ItemType Directory -Force -Path $runtime | Out-Null

$paper = Get-LatestPaperJar "paper"
$velocity = Get-LatestPaperJar "velocity"
Write-Host "Paper: $($paper.Version) build $($paper.Build), Java $($paper.JavaMinimum)+" -ForegroundColor Green
Write-Host "Velocity: $($velocity.Version) build $($velocity.Build), Java $($velocity.JavaMinimum)+" -ForegroundColor Green
$javaOutput = (& java -version 2>&1 | Out-String)
if ($javaOutput -match 'version "(d+)') {
    $installedJava = [int]$Matches[1]
    $minimumJava = [Math]::Max([int]$paper.JavaMinimum, [int]$velocity.JavaMinimum)
    if ($installedJava -lt $minimumJava) {
        throw "Java $minimumJava or newer is required by these builds; detected Java $installedJava. Install the required runtime and rerun."
    }
} else {
    Write-Warning "Could not parse java -version output. Verify manually that Java meets both minimum versions."
}
$downloadDir = Join-Path $runtime "downloads"
New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null
$paperDownload = Join-Path $downloadDir "paper.jar"
$velocityDownload = Join-Path $downloadDir "velocity.jar"
Invoke-WebRequest -Uri $paper.Url -OutFile $paperDownload -Headers $headers
Invoke-WebRequest -Uri $velocity.Url -OutFile $velocityDownload -Headers $headers
$paperHash = (Get-FileHash -Path $paperDownload -Algorithm SHA256).Hash.ToLowerInvariant()
$velocityHash = (Get-FileHash -Path $velocityDownload -Algorithm SHA256).Hash.ToLowerInvariant()
if ($paperHash -ne $paper.Sha256) { Remove-Item $paperDownload -Force; throw "Paper SHA-256 verification failed; deleted the downloaded file." }
if ($velocityHash -ne $velocity.Sha256) { Remove-Item $velocityDownload -Force; throw "Velocity SHA-256 verification failed; deleted the downloaded file." }
Write-Host "Verified Paper and Velocity SHA-256 checksums." -ForegroundColor Green

$proxyDir = Join-Path $runtime "proxy"
New-Item -ItemType Directory -Force -Path $proxyDir | Out-Null
Copy-Item $velocityDownload (Join-Path $proxyDir "velocity.jar") -Force
$proxyPlugins = Join-Path $proxyDir "plugins"
New-Item -ItemType Directory -Force -Path $proxyPlugins | Out-Null
# Official GeyserMC downloads: Bedrock-to-Java bridge plus Floodgate authentication.
Invoke-WebRequest -Uri "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/velocity" -OutFile (Join-Path $proxyPlugins "Geyser-Velocity.jar") -Headers $headers
Invoke-WebRequest -Uri "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/velocity" -OutFile (Join-Path $proxyPlugins "floodgate-velocity.jar") -Headers $headers

$configPath = Join-Path $repo "config\network.json"
if (-not (Test-Path $configPath)) { Copy-Item (Join-Path $repo "config\network.example.json") $configPath }
$config = Get-Content $configPath -Raw | ConvertFrom-Json
$secretBytes = New-Object byte[] 32
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($secretBytes)
$rng.Dispose()
$secret = [Convert]::ToBase64String($secretBytes).TrimEnd('=').Replace('+','-').Replace('/','_')
Set-Content -Path (Join-Path $proxyDir "forwarding.secret") -Value $secret -NoNewline -Encoding ascii

$velocityConfig = @"
config-version = "2.7"
bind = "0.0.0.0:25565"
motd = "<#72e6b1>MC-SERVER <gray>Local Test Network"
show-max-players = 100
online-mode = true
force-key-authentication = true
player-info-forwarding-mode = "modern"
forwarding-secret-file = "forwarding.secret"
announce-forge = false
kick-existing-players = false
ping-passthrough = "DISABLED"
enable-player-address-logging = false
[servers]
lobby = "127.0.0.1:25566"
survival = "127.0.0.1:25567"
lifesteal = "127.0.0.1:25568"
skyblock = "127.0.0.1:25569"
bedwars = "127.0.0.1:25570"
duels = "127.0.0.1:25571"
try = ["lobby"]
"@
Write-Utf8NoBom -Path (Join-Path $proxyDir "velocity.toml") -Content $velocityConfig

foreach ($server in $config.servers) {
    if ($server.kind -ne "paper") { continue }
    $folder = Join-Path $repo $server.directory
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
    Copy-Item $paperDownload (Join-Path $folder "paper.jar") -Force
    $properties = @"
server-ip=127.0.0.1
server-port=$($server.port)
motd=MC-SERVER $($server.display_name)
max-players=100
online-mode=false
enforce-secure-profile=true
enable-rcon=false
enable-query=false
"@
    Write-Utf8NoBom -Path (Join-Path $folder "server.properties") -Content $properties
    $configFolder = Join-Path $folder "config"
    New-Item -ItemType Directory -Force -Path $configFolder | Out-Null
    $globalConfig = @"
proxies:
  velocity:
    enabled: true
    online-mode: true
    secret: "$secret"
"@
    Write-Utf8NoBom -Path (Join-Path $configFolder "paper-global.yml") -Content $globalConfig
    if (-not (Test-Path (Join-Path $folder "eula.txt"))) {
        Set-Content -Path (Join-Path $folder "eula.txt") -Value "eula=false" -Encoding ascii
    }
    $server.enabled = [bool]($EnableAllModes -or $server.id -in @("proxy","lobby","survival"))
}

# Build and install the starter plugin when Gradle is available; the network still runs without it.
$gradle = Get-Command gradle -ErrorAction SilentlyContinue
if ($gradle) {
    Push-Location (Join-Path $repo "custom-plugins")
    try {
        & gradle build
        if ($LASTEXITCODE -ne 0) { throw "Custom plugin build failed. Check the Gradle output above." }
    } finally { Pop-Location }
    $pluginJar = Join-Path $repo "custom-plugins\network-core\build\libs\network-core-0.1.0.jar"
    if (Test-Path $pluginJar) {
        foreach ($server in $config.servers | Where-Object { $_.kind -eq "paper" }) {
            $pluginsDir = Join-Path (Join-Path $repo $server.directory) "plugins"
            New-Item -ItemType Directory -Force -Path $pluginsDir | Out-Null
            Copy-Item $pluginJar $pluginsDir -Force
        }
        Write-Host "Built and installed MC-SERVER Network Core." -ForegroundColor Green
    }
} else {
    Write-Host "Gradle not installed; skipping custom plugin build. Install Gradle and rerun to include /network and /spawn." -ForegroundColor Yellow
}

$jsonConfig = $config | ConvertTo-Json -Depth 20
Write-Utf8NoBom -Path $configPath -Content $jsonConfig
Write-Host ""
Write-Host "Prepared server jars and local-only forwarding configuration." -ForegroundColor Green
Write-Host "Review each runtime\<mode>\eula.txt and change eula=false to eula=true ONLY if you agree to the Minecraft EULA." -ForegroundColor Yellow
Write-Host "Default enabled instances: proxy, lobby, survival. Use -EnableAllModes only if your PC has enough RAM." -ForegroundColor Yellow
Write-Host "Run scripts\Start-Manager.ps1 after reviewing EULAs. Join Java at localhost:25565." -ForegroundColor Cyan
