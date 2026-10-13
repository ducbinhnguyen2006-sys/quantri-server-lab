#Requires -Version 5.1
<#
.SYNOPSIS
    Tao 2 may ao (WinSV2019 + Win10) theo HO SO trong lab.config.json.
.DESCRIPTION
    - Dia ao: VmDiskGB tu config (mac dinh 60/40 tuy ho so).
    - RAM/vCPU: VmRamWin10MB, VmRamServerMB, VmCpu tu config.
    - ISO: tim trong $Lab hoac SourceDir (offline).
    - -DryRun: chi in .vmx se tao, khong can VMware.
.PARAMETER Lab
    Thu muc goc chua tai lieu + ISO.
.PARAMETER DiskGB
    Ghi de dung luong dia ao.
.PARAMETER Force
    Bo qua canh bao dung luong.
.PARAMETER DryRun
    Chi in ra, khong tao gi ca.
#>
[CmdletBinding()]
param(
    [string]$Lab,
    [int]$DiskGB = 0,
    [switch]$Force,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

Write-Host "=== 04 - Tao 2 may ao (theo ho so) ===" -ForegroundColor Cyan

$cfg = Get-LabConfig -Lab $Lab
$Lab = $cfg.Lab
if ($DiskGB -le 0) { $DiskGB = [int]$cfg.VmDiskGB }
Write-Host "Ho so: $($cfg.ProfileLabel) | dia ao ${DiskGB}GB | vCPU=$($cfg.VmCpu) | Win10=$($cfg.VmRamWin10MB)MB Server=$($cfg.VmRamServerMB)MB"

# VMware/vdiskmanager
$vmHome = $cfg.VmwareInstallDir
$vdisk  = Join-Path $vmHome "vmware-vdiskmanager.exe"
if (-not $DryRun -and -not (Test-Path -LiteralPath $vdisk)) {
    Write-Host "KHONG thay vmware-vdiskmanager.exe. Da cai VMware chua (script 02)?" -ForegroundColor Red
    exit 1
}

# Kiem tra dung luong (bo qua khi DryRun)
if (-not $DryRun) {
    if (-not (Assert-FreeSpace -Path $Lab -MinGB ([int]$cfg.MinFreeGB) -Force:$Force)) { exit 1 }
}

$tplDir  = Join-Path (Split-Path -Parent $PSScriptRoot) "templates"
$vmsRoot = Join-Path $Lab "VMs"

# Resolve ISO (Lab hoac SourceDir)
$isoWin10  = Find-LabFile -Lab $Lab -SourceDir $cfg.SourceDir -Pattern "*Windows10*.iso"
$isoServer = Find-LabFile -Lab $Lab -SourceDir $cfg.SourceDir -Pattern "*SV*2019*.iso"
if (-not $isoServer) { $isoServer = Find-LabFile -Lab $Lab -SourceDir $cfg.SourceDir -Pattern "*Server*2019*.iso" }

$jobs = @(
    @{ Name="WinSV2019"; Tpl="WinSV2019.vmx.template"; Iso=$isoServer; Memory=$cfg.VmRamServerMB },
    @{ Name="Win10";     Tpl="Win10.vmx.template";     Iso=$isoWin10;  Memory=$cfg.VmRamWin10MB }
)

foreach ($j in $jobs) {
    $dir = Join-Path $vmsRoot $j.Name
    Write-Host "--- $($j.Name) -> $dir ---" -ForegroundColor Yellow

    if (-not $j.Iso) { Write-Host "  CANH BAO: chua tim thay ISO cho $($j.Name). Se de trong __ISO__." -ForegroundColor Yellow }

    # Doc template
    $tplPath = Join-Path $tplDir $j.Tpl
    if (-not (Test-Path -LiteralPath $tplPath)) { Write-Host "Thieu template $tplPath" -ForegroundColor Red; continue }
    $vmx = Get-Content -LiteralPath $tplPath -Raw
    $vmx = $vmx.Replace("__VMNAME__", $j.Name)
    $vmx = $vmx.Replace("__VMDIR__", $dir)
    $vmx = $vmx.Replace("__ISO__", [string]$j.Iso)
    $vmx = $vmx.Replace("__MEMORY__", [string]$j.Memory)
    $vmx = $vmx.Replace("__VCPUS__", [string]$cfg.VmCpu)
    $vmx = $vmx.Replace("__CORES__", [string]$cfg.VmCpu)

    if ($DryRun) {
        Write-Host "  [DryRun] .vmx se tao tai $dir\$($j.Name).vmx:" -ForegroundColor DarkGray
        Write-Host ($vmx -split "`n" | Where-Object { $_ -match 'memsize|numvcpus|coresPerSocket|displayName|ide1:0.fileName|scsi0:0.fileName' } | ForEach-Object { "    $_" })
        continue
    }

    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    # 1) Dia ao
    $vmdk = Join-Path $dir "$($j.Name).vmdk"
    if (Test-Path -LiteralPath $vmdk) {
        Write-Host "  Dia ao da ton tai, bo qua."
    } else {
        Write-Host "  Tao dia ao ${DiskGB}GB..."
        & $vdisk -c -s "${DiskGB}GB" -a lsilogic -t 0 $vmdk | Out-Null
    }

    # 2) Ghi .vmx
    $vmxPath = Join-Path $dir "$($j.Name).vmx"
    if (Test-Path -LiteralPath $vmxPath) {
        Copy-Item -LiteralPath $vmxPath -Destination "$vmxPath.bak" -Force
        Write-Host "  (.vmx cu da sao luu .bak)"
    }
    $vmxOut = ($vmx -replace "`r`n", "`n") -replace "`n", "`r`n"
    [System.IO.File]::WriteAllText($vmxPath, $vmxOut, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "  Da ghi $vmxPath" -ForegroundColor Green

    if (-not $j.Iso) { Write-Host "  -> Sua dong ide1:0.fileName trong .vmx khi co ISO." -ForegroundColor Yellow }
}

if ($DryRun) {
    Write-Host "`n=== DryRun: khong tao gi. Bo -DryRun de tao that. ===" -ForegroundColor Cyan
    exit 0
}

Set-LabStep "04"
Write-Host "`n=== Xong. VM nam trong: $vmsRoot ===" -ForegroundColor Green
Write-Host "Buoc tiep: mo VMware BANG TAY, Power On tung VM de cai Windows (docs/05)." -ForegroundColor Green
if ($cfg.OneVmAtATime) {
    Write-Host "LUU Y (RAM it): chi bat 1 VM moi lan, cai xong VM1 thi tat roi lam VM2." -ForegroundColor Yellow
}

exit 0
