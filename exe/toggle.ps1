# ToggleAutotuning by @transaction-fraud

# Check for admin
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator")) 
{
    Start-Process powershell "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Task scheduler
if (-not (Get-ScheduledTask -TaskName "ToggleAutotuning" -ErrorAction SilentlyContinue)) {
    Register-ScheduledTask -TaskName "ToggleAutotuning" `
        -Action (New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSScriptRoot\launch.ps1`"") `
        -Trigger (New-ScheduledTaskTrigger -AtLogOn) `
        -Principal (New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest)
}


Add-Type -AssemblyName System.Windows.Forms


$toggle = $true
$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = [System.Drawing.SystemIcons]::Information
$notify.Visible = $true
$notify.Text = "Autotuning: Enabled"


$notify.add_MouseClick({
    $toggle = -not $toggle
    if ($toggle) {
        netsh interface tcp set global autotuninglevel=normal
        $notify.Text = "Auto-Tuning: Enabled"
        Write-Host "Auto-Tuning: Enabled"
    } else {
        netsh interface tcp set global autotuninglevel=disabled
        $notify.Text = "Autotuning: Disabled"
        Write-Host "Autotuning: Disabled"
    }
})

# Right click menu
$menu = New-Object System.Windows.Forms.ContextMenu
$menuItem = New-Object System.Windows.Forms.MenuItem("Exit", { $notify.Dispose(); exit })
$menu.MenuItems.Add($menuItem)
$notify.ContextMenu = $menu

# Alive
[System.Windows.Forms.Application]::Run()
