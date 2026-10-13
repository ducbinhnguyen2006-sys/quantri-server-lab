#Requires -Version 5.1
<#
.SYNOPSIS
    Tao 2 may ao (WinSV2019 + Win10) tu dong: tao dia ao + sinh .vmx.
.PARAMETER Lab
    Thu muc goc chua tai lieu + ISO. Mac dinh E:\QuanTriServer
.PARAMETER DiskGB
    Dung luong dia ao moi VM. Mac dinh 60.
#>
[CmdletBinding()]
param(
    [string]$Lab = "E:\QuanTriServer",
    [int]$DiskGB = 60
)

$ErrorActionPreference = "Stop"
Write-Host "=== 04 - Tao 2 may ao ===" -ForegroundColor Cyan

$vmHome = "C:\Program Files (x86)\VMware\VMware Workstation"
$vdisk  = Join-Path $vmHome "vmware-vdiskmanager.exe"
if (-not (Test-Path -LiteralPath $vdisk)) {
    Write-Host "KHONG thay vmware-vdiskmanager.exe. Da cai VMware chua (script 02)?" -ForegroundColor Red
    exit 1
}

$tplDir = Join-Path $PSScriptRoot "..\templates"
$vmsRoot = Join-Path $Lab "VMs"

$jobs = @(
    @{ Name = "WinSV2019"; Tpl = "WinSV2019.vmx.template"; Iso = (Join-Path $Lab "Win SV 2019\Win SV 2019.iso") },
    @{ Name = "Win10";     Tpl = "Win10.vmx.template";     Iso = (Join-Path $Lab "Windows10_full.iso") }
)

foreach ($j in $jobs) {
    $dir = Join-Path $vmsRoot $j.Name
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Write-Host "--- $($j.Name) -> $dir ---" -ForegroundColor Yellow

    # 1) Dia ao
    $vmdk = Join-Path $dir "$($j.Name).vmdk"
    if (Test-Path -LiteralPath $vmdk) {
        Write-Host "Dia ao da ton tai, bo qua."
    } else {
        Write-Host "Tao dia ao ${DiskGB}GB..."
        & $vdisk -c -s "${DiskGB}GB" -a lsilogic -t 0 $vmdk | Out-Null
    }

    # 2) Sinh .vmx tu template
    $tplPath = Join-Path $tplDir $j.Tpl
    if (-not (Test-Path -LiteralPath $tplPath)) {
        Write-Host "Thieu template $tplPath" -ForegroundColor Red
        continue
    }
    $vmx = Get-Content -LiteralPath $tplPath -Raw
    $vmx = $vmx.Replace("__VMNAME__", $j.Name)
    $vmx = $vmx.Replace("__VMDIR__", $dir)
    $vmx = $vmx.Replace("__ISO__", $j.Iso)

    $vmxPath = Join-Path $dir "$($j.Name).vmx"
    if (Test-Path -LiteralPath $vmxPath) {
        Write-Host ".vmx da ton tai - ghi ban .bak roi ghi de."
        Copy-Item -LiteralPath $vmxPath -Destination "$vmxPath.bak" -Force
    }
    Set-Content -LiteralPath $vmxPath -Value $vmx -Encoding UTF8

    # 3) Kiem tra ISO
    if (-not (Test-Path -LiteralPath $j.Iso)) {
        Write-Host "CANH BAO: khong thay ISO: $($j.Iso)" -ForegroundColor Yellow
        Write-Host "  -> Sua lai dong ide1:0.fileName trong $vmxPath" -ForegroundColor Yellow
    }
}

Write-Host "=== Xong. VM nam trong: $vmsRoot ===" -ForegroundColor Green
Write-Host "Buoc tiep: mo VMware bang tay, Power On tung VM de cai Windows (docs/05)." -ForegroundColor Green
