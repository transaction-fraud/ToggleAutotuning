# ToggleAutotuning by @transaction-fraud

# Check for admin
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Background item
if (-not (Get-ScheduledTask -TaskName "ToggleAutotuning" -ErrorAction SilentlyContinue)) {
    Register-ScheduledTask -TaskName "ToggleAutotuning" `
        -Action (New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSScriptRoot\launch.ps1`"") `
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
