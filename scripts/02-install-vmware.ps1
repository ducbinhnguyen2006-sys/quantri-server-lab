#Requires -Version 5.1
<#
.SYNOPSIS
    Cai VMware Workstation 16.2.4 (im lang) + nhap serial.
.PARAMETER Lab
    Thu muc chua bo tai lieu (ghi de cau hinh trong lab.config.json).
.PARAMETER ExePath
    Duong dan tro truc tiep toi file cai (neu khac vi tri mac dinh).
.PARAMETER Serial
    Serial VMware. Mac dinh lay tu KEYS.md.
#>
[CmdletBinding()]
param(
    [string]$Lab,
    [string]$ExePath,
    [string]$Serial = "ZF3R0-FHED2-M80TY-8QYGC-NPKYF"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

Write-Host "=== 02 - Cai VMware Workstation 16.2.4 ===" -ForegroundColor Cyan

$cfg = Get-LabConfig -Lab $Lab
$Lab = $cfg.Lab

# VMware cai vao C: (~1 GB) - kiem tra so qua
Assert-FreeSpace -Path "C:\" -MinGB 2 -Force | Out-Null

# Tim file cai
if (-not $ExePath) {
    $vmwareDir = Join-Path $Lab "vmware"
    $exeItem = Get-ChildItem -Path $vmwareDir -Filter "VMware-workstation-full-*.exe" -ErrorAction SilentlyContinue |
               Select-Object -First 1
    if ($exeItem) { $ExePath = $exeItem.FullName }
}

if (-not $ExePath -or -not (Test-Path -LiteralPath $ExePath)) {
    Write-Host "KHONG tim thay file cai VMware trong '$Lab\vmware'." -ForegroundColor Red
    Write-Host "Hay tai bo tai lieu (script 01) hoac dung -ExePath." -ForegroundColor Red
    exit 1
}
Write-Host "File cai: $ExePath"

# Tham so im lang cua VMware installer (MSI ben trong)
$instArgs = @(
    "/s",
    "/v`"/qn EULAS_AGREED=1 SERIALNUMBER=$Serial AUTOSOFTWAREUPDATE=0 DATACOLLECTION=0`""
)

Write-Host "Dang cai (se hien UAC -> bam Yes, cho 2-5 phut)..." -ForegroundColor Yellow
Start-Process -FilePath $ExePath -Verb RunAs -Wait -ArgumentList $instArgs

# Kiem tra
$found = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                          "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" `
         -ErrorAction SilentlyContinue |
         Where-Object { $_.DisplayName -like "*VMware Workstation*" } |
         Select-Object -First 1

if ($found) {
    Write-Host "=== Da cai: $($found.DisplayName) $($found.DisplayVersion) ===" -ForegroundColor Green
} else {
    Write-Host "Chua xac nhan duoc trong registry - kiem tra bang tay trong Add/Remove Programs." -ForegroundColor Yellow
}
