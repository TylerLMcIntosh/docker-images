# setup_monitor.ps1
# Run this once (as your normal user, NOT as admin) to install dependencies
# and register the Task Scheduler job.
#
# Usage:
#   Right-click this file -> "Run with PowerShell"
#   OR open PowerShell and run:  .\setup_monitor.ps1

$ErrorActionPreference = "Stop"

$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$monitorPy  = Join-Path $scriptDir "js2_monitor.py"
$configFile = Join-Path $scriptDir "js2_config.json"
$taskName   = "Jetstream2-r3xl-Monitor"

Write-Host ""
Write-Host "=== Jetstream2 r3.xl Monitor Setup ===" -ForegroundColor Cyan
Write-Host ""

# ── 1. Verify Python ──────────────────────────────────────────────────────────
Write-Host "Checking Python..." -ForegroundColor Yellow
$pyCmd = $null
foreach ($candidate in @("py", "python", "python3")) {
    try {
        $ver = & $candidate --version 2>&1
        if ($ver -match "Python 3") {
            $pyCmd = $candidate
            Write-Host "  Found: $ver (using '$pyCmd')" -ForegroundColor Green
            break
        }
    } catch { }
}
if (-not $pyCmd) {
    Write-Host "  ERROR: Python 3 not found. Install from https://python.org and re-run." -ForegroundColor Red
    exit 1
}

# Resolve the full path to the python executable (Task Scheduler needs it)
$pyExe = (& $pyCmd -c "import sys; print(sys.executable)").Trim()
Write-Host "  Executable: $pyExe"

# ── 2. Install pip dependencies ───────────────────────────────────────────────
Write-Host ""
Write-Host "Installing Python packages..." -ForegroundColor Yellow
& $pyCmd -m pip install --quiet --upgrade playwright
Write-Host "  playwright installed" -ForegroundColor Green

# ── 3. Install Playwright's Chromium browser ──────────────────────────────────
Write-Host ""
Write-Host "Installing Playwright Chromium (one-time, ~150 MB)..." -ForegroundColor Yellow
& $pyCmd -m playwright install chromium
Write-Host "  Chromium installed" -ForegroundColor Green

# ── 4. Create config file if missing ─────────────────────────────────────────
Write-Host ""
if (-not (Test-Path $configFile)) {
    $template = @{
        ntfy_topic         = "js2-monitor-CHANGEME"
        gmail_app_password = ""
    } | ConvertTo-Json
    Set-Content -Path $configFile -Value $template
    Write-Host "Created config file: $configFile" -ForegroundColor Green
    Write-Host ""
    Write-Host "ACTION REQUIRED: Edit js2_config.json:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  ntfy_topic (recommended — free, no account needed):" -ForegroundColor Cyan
    Write-Host "    1. Pick any unique topic name, e.g. 'js2-tyler-r3xl-abc123'"
    Write-Host "    2. Subscribe at https://ntfy.sh/<your-topic> in a browser,"
    Write-Host "       or install the ntfy app on your phone and subscribe there."
    Write-Host "    3. Paste your topic name into js2_config.json."
    Write-Host ""
    Write-Host "  gmail_app_password (optional — Gmail email alerts):" -ForegroundColor Cyan
    Write-Host "    Get one at https://myaccount.google.com/apppasswords"
    Write-Host "    (requires Google 2-Step Verification to be enabled)"
} else {
    Write-Host "Config file already exists: $configFile" -ForegroundColor Green
}

# ── 5. Register Task Scheduler task ──────────────────────────────────────────
Write-Host ""
Write-Host "Registering Windows Task Scheduler task..." -ForegroundColor Yellow

# Remove existing task if present
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "  Removed previous task registration."
}

$action  = New-ScheduledTaskAction `
    -Execute $pyExe `
    -Argument "`"$monitorPy`"" `
    -WorkingDirectory $scriptDir

# Trigger: repeat every 5 minutes, indefinitely, starting now
$trigger = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 5) `
    -RepetitionDuration ([TimeSpan]::MaxValue)

$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 3) `
    -MultipleInstances IgnoreNew `
    -StartWhenAvailable `
    -WakeToRun:$false

# Run as current user (no admin required, toast notifications work)
$principal = New-ScheduledTaskPrincipal `
    -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) `
    -LogonType Interactive `
    -RunLevel Limited

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description "Monitor Jetstream2 r3.xl large memory node availability and notify when it increases." `
    | Out-Null

Write-Host "  Task '$taskName' registered." -ForegroundColor Green

# ── 6. Test run ───────────────────────────────────────────────────────────────
Write-Host ""
$doTest = Read-Host "Run a test check now? (y/n)"
if ($doTest -eq "y") {
    Write-Host ""
    Write-Host "Step 1: Testing notifications (toast + ntfy/email if configured)..." -ForegroundColor Yellow
    & $pyCmd $monitorPy --test
    Write-Host ""
    Write-Host "Step 2: Testing page read — fetching live Grafana dashboard (~15s)..." -ForegroundColor Yellow
    & $pyCmd $monitorPy --debug
    Write-Host ""
    Write-Host "Check js2_monitor.log for the parsed r3.xl count." -ForegroundColor Cyan
    Write-Host "Check js2_debug_page_text.txt to verify the raw page content." -ForegroundColor Cyan
}

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Setup complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "The monitor will check every 5 minutes while your PC is on."
Write-Host "Logs: $scriptDir\js2_monitor.log"
Write-Host ""
Write-Host "To stop monitoring:"
Write-Host "  Unregister-ScheduledTask -TaskName '$taskName' -Confirm:`$false"
Write-Host ""
