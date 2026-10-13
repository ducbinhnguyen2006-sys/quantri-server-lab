#Requires -Version 5.1
<#
.SYNOPSIS
    Tat Hyper-V / VBS de VMware chay native (chong lag). CAN REBOOT.
.DESCRIPTION
    - Tu dong yeu cau quyen Admin (UAC).
    - Tat cac tinh nang Hyper-V, VirtualMachinePlatform, HypervisorPlatform.
    - bcdedit hypervisorlaunchtype off.
    - Tat VBS / HVCI trong registry.
    - HOI truoc khi reboot.
.NOTES
    Tac dong phu: WSL2, Docker Desktop, Windows Sandbox se KHONG chay duoc.
#>
[CmdletBinding()]
param(
    [switch]$NoRestart
)

$ErrorActionPreference = "Stop"

# --- Tu nang quyen ---
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Can quyen Admin. Dang mo lai voi UAC (bam Yes)..." -ForegroundColor Yellow
    $psArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
    if ($NoRestart) { $psArgs += "-NoRestart" }
    Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $psArgs
    exit
}

Write-Host "=== 03 - Tat Hyper-V / VBS (chong lag) ===" -ForegroundColor Cyan
Write-Host "LUU Y: WSL2 / Docker Desktop / Windows Sandbox se bi tat." -ForegroundColor Yellow

# --- 1. Tat tinh nang Hyper-V ---
$features = @(
    "Microsoft-Hyper-V-All",
    "VirtualMachinePlatform",
    "HypervisorPlatform",
    "Containers-DisposableClientVM"
)
foreach ($f in $features) {
    Write-Host "dism /disable-feature $f ..." -ForegroundColor Yellow
    & dism.exe /online /disable-feature /featurename:$f /norestart | Out-Null
}

# --- 2. bcdedit ---
Write-Host "bcdedit /set hypervisorlaunchtype off" -ForegroundColor Yellow
& bcdedit.exe /set hypervisorlaunchtype off | Out-Null

# --- 3. Registry VBS / HVCI ---
Write-Host "Tat VBS / HVCI trong registry..." -ForegroundColor Yellow

$hvci = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
New-Item -Path $hvci -Force | Out-Null
Set-ItemProperty -Path $hvci -Name Enabled -Value 0 -Type DWord -Force

$dg = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
New-Item -Path $dg -Force | Out-Null
Set-ItemProperty -Path $dg -Name EnableVirtualizationBasedSecurity -Value 0 -Type DWord -Force

Write-Host "=== Da tat xong. ===" -ForegroundColor Green
Write-Host "Sau khi REBOOT, chay 99-verify.ps1 de kiem tra (ky vong HyperVisorPresent=False)." -ForegroundColor Green

if (-not $NoRestart) {
    $ans = Read-Host "Reboot ngay bay gio? (Y/N)"
    if ($ans -match "^[Yy]") {
        Write-Host "Dang khoi dong lai..." -ForegroundColor Yellow
        Restart-Computer -Force
    } else {
        Write-Host "Nho TU KHOI DONG LAI may de thay doi co hieu luc!" -ForegroundColor Red
    }
}

exit 0
