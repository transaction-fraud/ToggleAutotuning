@echo off
title ToggleAutotuning by @transaction-fraud
setlocal

set "appDir=%ProgramData%\ToggleAutotuning"
set "ps1File=%appDir%\toggle.ps1"

:: Create folder if missing
if not exist "%appDir%" mkdir "%appDir%"

:: Create 
(
echo # ToggleAutotuning by @transaction-fraud
echo
echo
echo $scriptPath = $MyInvocation.MyCommand.Definition
echo
echo
echo if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
echo ^    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
echo ^    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
echo ^    exit
echo }
echo
echo
echo if (-not (Get-ScheduledTask -TaskName "ToggleAutotuning" -ErrorAction SilentlyContinue)) {
echo ^    Register-ScheduledTask -TaskName "ToggleAutotuning" ^
        -Action (New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`"") ^
        -Trigger (New-ScheduledTaskTrigger -AtLogOn) ^
        -Principal (New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest)
echo }
echo
echo
echo Add-Type -AssemblyName System.Windows.Forms
echo
echo function Get-AutotuningState {
echo ^    $line = netsh interface tcp show global ^| Select-String "Receive Window Auto-Tuning Level"
echo ^    if ($line -match "normal") { return "normal" }
echo ^    elseif ($line -match "disabled") { return "disabled" }
echo ^    else { return "unknown" }
echo }
echo
echo $state = Get-AutotuningState
echo $notify = New-Object System.Windows.Forms.NotifyIcon
echo $notify.Icon = [System.Drawing.SystemIcons]::Information
echo $notify.Visible = $true
echo $notify.Text = "Autotuning: $state"
echo
echo
echo $notify.add_MouseClick({
echo ^    $state = Get-AutotuningState
echo ^    if ($state -eq "normal") {
echo ^        Start-Process "netsh.exe" -ArgumentList "interface tcp set global autotuninglevel=disabled" -Verb RunAs -WindowStyle Hidden
echo ^        $notify.Text = "Autotuning: disabled"
echo ^        Write-Host "Autotuning: disabled"
echo ^    } elseif ($state -eq "disabled") {
echo ^        Start-Process "netsh.exe" -ArgumentList "interface tcp set global autotuninglevel=normal" -Verb RunAs -WindowStyle Hidden
echo ^        $notify.Text = "Autotuning: normal"
echo ^        Write-Host "Autotuning: normal"
echo ^    }
echo })
echo
echo
echo $menu = New-Object System.Windows.Forms.ContextMenu
echo $menuItem = New-Object System.Windows.Forms.MenuItem("Exit", { $notify.Dispose(); exit })
echo $menu.MenuItems.Add($menuItem)
echo $notify.ContextMenu = $menu
echo
echo [System.Windows.Forms.Application]::Run()
) > "%ps1File%"

:: Run 
powershell -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "%ps1File%"
exit /b
