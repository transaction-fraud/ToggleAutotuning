@echo off
setlocal EnableDelayedExpansion

powershell -NoProfile -Command "Set-Content -LiteralPath '%~dp0toggle.ps1' -Value @'
# ToggleAutotuning by @transaction-fraud

# Check instances
$running = Get-Process -Name powershell | Where-Object {
    $_.CommandLine -match [regex]::Escape($PSCommandPath) -and $_.Id -ne $PID
}

if ($running) { exit }

$mutex = New-Object System.Threading.Mutex($false, "Global\ToggleAutotuningMutex")
if (-not $mutex.WaitOne(0, $false)) {
    exit
}

# Check admin
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Background item
$existingTask = Get-ScheduledTask -TaskName "ToggleAutotuning" -ErrorAction SilentlyContinue
if ($existingTask) {
    # Check the action path
    if ($existingTask.Actions.Execute -notmatch "toggle.ps1") {
        Unregister-ScheduledTask -TaskName "ToggleAutotuning" -Confirm:$false
        $existingTask = $null
    }
}

if (-not $existingTask) {
    Register-ScheduledTask -TaskName "ToggleAutotuning" `
    -Action (New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\toggle.ps1`"") `
    -Trigger (New-ScheduledTaskTrigger -AtLogOn) `
    -Principal (New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest)
}


Add-Type -AssemblyName System.Windows.Forms

function Get-AutotuningState {
    $line = netsh interface tcp show global | Select-String "Receive Window Auto-Tuning Level"
    if ($line -match "normal") { return "normal" }
    elseif ($line -match "disabled") { return "disabled" }
    else { return "unknown" }
}

$state = Get-AutotuningState

# Tray icon
$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = [System.Drawing.SystemIcons]::Information
$notify.Visible = $true
$notify.Text = "Autotuning: $state"

# Toggle on click
$notify.add_MouseClick({
    $state = Get-AutotuningState
    if ($state -eq "normal") {
        Start-Process "netsh.exe" -ArgumentList "interface tcp set global autotuninglevel=disabled" -Verb RunAs -WindowStyle Hidden
        $notify.Text = "Autotuning: disabled"
        Write-Host "Autotuning: disabled"
    } elseif ($state -eq "disabled") {
        Start-Process "netsh.exe" -ArgumentList "interface tcp set global autotuninglevel=normal" -Verb RunAs -WindowStyle Hidden
        $notify.Text = "Autotuning: normal"
        Write-Host "Autotuning: normal"
    }
})

# Right-click menu
$menu = New-Object System.Windows.Forms.ContextMenu
$menuItem = New-Object System.Windows.Forms.MenuItem("Exit", { $notify.Dispose(); exit })
$menu.MenuItems.Add($menuItem)
$notify.ContextMenu = $menu

# Keep alive
[System.Windows.Forms.Application]::Run()

'@ -Encoding UTF8"

powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File "%~dp0toggle.ps1"