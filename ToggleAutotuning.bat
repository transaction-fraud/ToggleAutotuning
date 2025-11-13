@echo off
setlocal EnableDelayedExpansion

net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList 'am_admin' -Verb RunAs"
    exit /b
)

set "TMPDIR=%TEMP%\ToggleAutotuning"
set "MAIN_PS=%TMPDIR%\ToggleAutotuning.ps1"
set "LAUNCH_PS=%TMPDIR%\launch.ps1"

if not exist "%TMPDIR%" mkdir "%TMPDIR%"

powershell -NoProfile -Command "Set-Content -LiteralPath '%MAIN_PS%' -Value @'
# ToggleAutotuning by @transaction-fraud

# Check for admin
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] \"Administrator\")) {
    Start-Process powershell \"-ExecutionPolicy Bypass -File `\"$PSCommandPath`\"\" -Verb RunAs
    exit
}

# Background item
if (-not (Get-ScheduledTask -TaskName \"ToggleAutotuning\" -ErrorAction SilentlyContinue)) {
    Register-ScheduledTask -TaskName \"ToggleAutotuning\" `
        -Action (New-ScheduledTaskAction -Execute \"powershell.exe\" -Argument \"-WindowStyle Hidden -ExecutionPolicy Bypass -File `\"$PSScriptRoot\\launch.ps1`\"\") `
        -Trigger (New-ScheduledTaskTrigger -AtLogOn) `
        -Principal (New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest)
}

Add-Type -AssemblyName System.Windows.Forms

function Get-AutotuningState {
    $line = netsh interface tcp show global | Select-String \"Receive Window Auto-Tuning Level\"
    if ($line -match \"normal\") { return \"normal\" }
    elseif ($line -match \"disabled\") { return \"disabled\" }
    else { return \"unknown\" }
}

$state = Get-AutotuningState

# Tray icon
$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = [System.Drawing.SystemIcons]::Information
$notify.Visible = $true
$notify.Text = \"Autotuning: $state\"

# Toggle on click
$notify.add_MouseClick({
    $state = Get-AutotuningState
    if ($state -eq \"normal\") {
        Start-Process \"netsh.exe\" -ArgumentList \"interface tcp set global autotuninglevel=disabled\" -Verb RunAs -WindowStyle Hidden
        $notify.Text = \"Autotuning: disabled\"
        Write-Host \"Autotuning: disabled\"
    } elseif ($state -eq \"disabled\") {
        Start-Process \"netsh.exe\" -ArgumentList \"interface tcp set global autotuninglevel=normal\" -Verb RunAs -WindowStyle Hidden
        $notify.Text = \"Autotuning: normal\"
        Write-Host \"Autotuning: normal\"
    }
})

# Right-click menu
$menu = New-Object System.Windows.Forms.ContextMenu
$menuItem = New-Object System.Windows.Forms.MenuItem(\"Exit\", { $notify.Dispose(); exit })
$menu.MenuItems.Add($menuItem)
$notify.ContextMenu = $menu

# Keep alive
[System.Windows.Forms.Application]::Run()
'@ -Encoding UTF8"

powershell -NoProfile -Command "Set-Content -LiteralPath '%LAUNCH_PS%' -Value @'
# launch.ps1 - starts ToggleAutotuning.ps1 hidden
$script = Join-Path $PSScriptRoot 'ToggleAutotuning.ps1'
Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `\"' + $script + '`\"' -WindowStyle Hidden
'@ -Encoding UTF8"

powershell -NoProfile -Command "Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `\"%LAUNCH_PS%`\"' -Verb RunAs -WindowStyle Hidden"

endlocal
exit /b
