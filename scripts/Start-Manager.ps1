Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

$venvPython = Join-Path $repo ".venv\Scripts\python.exe"
$requirements = Join-Path $repo "manager\requirements.txt"

function Test-PythonCandidate([string]$Command, [string[]]$PrefixArgs) {
    $found = Get-Command $Command -ErrorAction SilentlyContinue
    if (-not $found) { return $false }
    $oldPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $output = (& $found.Source @PrefixArgs -c "import sys; print('%d.%d.%d' % sys.version_info[:3]); raise SystemExit(0 if sys.version_info >= (3, 11) else 2)" 2>&1 | ForEach-Object { "$_" }) -join "`n"
        $exitCode = $LASTEXITCODE
    } catch {
        return $false
    } finally {
        $ErrorActionPreference = $oldPreference
    }
    if ($exitCode -eq 0) {
        Write-Host "Using Python $output via $Command" -ForegroundColor Green
        return $true
    }
    return $false
}

if (-not (Test-Path $venvPython)) {
    $pythonCommand = $null
    $pythonPrefix = @()
    if (Test-PythonCandidate "py" @("-3.11")) {
        $pythonCommand = (Get-Command py).Source
        $pythonPrefix = @("-3.11")
    } elseif (Test-PythonCandidate "python" @()) {
        $pythonCommand = (Get-Command python).Source
    } elseif (Test-PythonCandidate "python3" @()) {
        $pythonCommand = (Get-Command python3).Source
    } else {
        throw "Python 3.11 or newer was not found. Install Python 3.11+ from https://www.python.org/downloads/windows/ and enable 'Add python.exe to PATH', then rerun start.bat."
    }

    Write-Host "Creating the local Python virtual environment..." -ForegroundColor Cyan
    $oldPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & $pythonCommand @pythonPrefix -m venv (Join-Path $repo ".venv")
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $oldPreference
    }
    if ($exitCode -ne 0 -or -not (Test-Path $venvPython)) {
        throw "Python virtual environment creation failed. Check that Python 3.11+ is installed with the venv component."
    }
}

if (-not (Test-Path $requirements)) { throw "Missing dependency file: $requirements" }
Write-Host "Checking/installing manager dependencies..." -ForegroundColor Cyan
$oldPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = "Continue"
    & $venvPython -m pip install --disable-pip-version-check -r $requirements
    $exitCode = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $oldPreference
}
if ($exitCode -ne 0) {
    throw "Dependency installation failed. Check internet access and the manager startup error log."
}

Write-Host "Starting manager at http://127.0.0.1:8765" -ForegroundColor Cyan
& $venvPython -m uvicorn manager.app:app --host 127.0.0.1 --port 8765
if ($LASTEXITCODE -ne 0) {
    throw "The manager process exited with code $LASTEXITCODE. See manager-startup-error.log."
}
