#Requires -Version 5.1
<#
.SYNOPSIS
    Kiem tra tinh trang san sang cua lab.
.DESCRIPTION
    - Hypervisor/VBS da tat chua?
    - VMware da cai chua?
    - Tai lieu + ISO da tai chua?
    - .vmx da toi uu chua?
#>
[CmdletBinding()]
param(
    [string]$Lab = "E:\QuanTriServer"
)

Write-Host "=== 99 - Kiem tra tong the ===" -ForegroundColor Cyan
$ok = $true

# 1) Hypervisor / VBS
Write-Host "`n[1] Hypervisor / VBS" -ForegroundColor Yellow
try {
    $ci = Get-ComputerInfo -Property HyperVisorPresent
    if ($ci.HyperVisorPresent) {
        Write-Host "  HyperVisorPresent = True  -> CHUA TAT (VM se lag!)" -ForegroundColor Red
        Write-Host "  -> Chay scripts\03-disable-hyperv-vbs.ps1 roi REBOOT." -ForegroundColor Red
        $ok = $false
    } else {
        Write-Host "  HyperVisorPresent = False  -> OK" -ForegroundColor Green
    }
} catch { Write-Host "  Khong doc duoc (bo qua)." -ForegroundColor DarkGray }

try {
    $dg = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction Stop
    if ($dg.VirtualizationBasedSecurityStatus -eq 0) {
        Write-Host "  VirtualizationBasedSecurity = 0 (Off)  -> OK" -ForegroundColor Green
    } else {
        Write-Host "  VirtualizationBasedSecurity = $($dg.VirtualizationBasedSecurityStatus)  -> nen tat" -ForegroundColor Yellow
        $ok = $false
    }
} catch { Write-Host "  Khong doc duoc DeviceGuard (bo qua)." -ForegroundColor DarkGray }

# 2) VMware
Write-Host "`n[2] VMware Workstation" -ForegroundColor Yellow
$vmrun = "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe"
if (Test-Path -LiteralPath $vmrun) {
    $ver = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
                             "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
            Where-Object DisplayName -like "*VMware Workstation*" | Select-Object -First 1).DisplayVersion
    Write-Host "  Da cai VMware Workstation $ver  -> OK" -ForegroundColor Green
} else {
    Write-Host "  CHUA cai VMware (thieu vmrun.exe) -> chay script 02." -ForegroundColor Red
    $ok = $false
}

# 3) Tai lieu
Write-Host "`n[3] Bo tai lieu ($Lab)" -ForegroundColor Yellow
$need = @(
    (Join-Path $Lab "Windows10_full.iso"),
    (Join-Path $Lab "Win SV 2019\Win SV 2019.iso"),
    (Join-Path $Lab "vmware")
)
foreach ($p in $need) {
    if (Test-Path -LiteralPath $p) {
        Write-Host "  OK: $p" -ForegroundColor Green
    } else {
        Write-Host "  THIEU: $p" -ForegroundColor Red
        $ok = $false
    }
}

# 4) VM + toi uu
Write-Host "`n[4] May ao (.vmx)" -ForegroundColor Yellow
foreach ($n in @("Win10","WinSV2019")) {
    $vmx = Join-Path $Lab "VMs\$n\$n.vmx"
    if (Test-Path -LiteralPath $vmx) {
        $c = Get-Content -LiteralPath $vmx -Raw
        $has3d = $c -match 'mks\.enable3d\s*=\s*"TRUE"'
        $hasIso = $c -match 'ide1:0\.fileName\s*=\s*"(.+?)"'
        Write-Host ("  {0}: ton tai | 3D={1}" -f $n, $has3d) -ForegroundColor Green
    } else {
        Write-Host "  ${n}: chua co .vmx (chay script 04)" -ForegroundColor Yellow
    }
}

Write-Host ""
if ($ok) {
    Write-Host "=== TAT CA OK - san sang lam lab ===" -ForegroundColor Green
} else {
    Write-Host "=== Con muc CHUA dat (xem dong do o tren) ===" -ForegroundColor Yellow
}
