$ErrorActionPreference = "Continue"
Write-Host "MC-SERVER prerequisite check" -ForegroundColor Cyan
$checks = @(@{Name="Java";Command="java";Args=@("-version")},@{Name="Python";Command="py";Args=@("-3.11","--version")},@{Name="Git";Command="git";Args=@("--version")})
foreach ($c in $checks) { $found=Get-Command $c.Command -ErrorAction SilentlyContinue; if (-not $found) { Write-Host "[MISSING] $($c.Name)" -ForegroundColor Yellow; continue }; Write-Host "[FOUND] $($c.Name): $($found.Source)" -ForegroundColor Green; try { & $c.Command @($c.Args) 2>&1 | Select-Object -First 2 } catch { Write-Host $_ -ForegroundColor Yellow } }
if (-not (Test-Path ".\\config\\network.json")) { Write-Host "Copy config\\network.example.json to config\\network.json and review it." -ForegroundColor Cyan }
