#Requires -Version 5.1
<#
.SYNOPSIS
    Don dep sau khi cai OS: xoa file ISO (giai phong ~5 GB) + compact dia ao.
.DESCRIPTION
    - Xoa cac file .iso trong $Lab (KHONG xoa trong SourceDir).
    - Compact dia ao (.vmdk) qua vmware-vdiskmanager de thu hoi dung luong.
    - Chi chay khi da cai xong OS trong VM.
.PARAMETER Lab
    Thu muc goc.
.PARAMETER Compact
    Chay compact dia ao (cham hon).
.PARAMETER Force
    Khong hoi xac nhan.
#>
[CmdletBinding()]
param(
    [string]$Lab,
    [switch]$Compact,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

Write-Host "=== 06 - Don dep ISO + compact dia ao ===" -ForegroundColor Cyan
$cfg = Get-LabConfig -Lab $Lab
$Lab = $cfg.Lab

# ---------- Xoa ISO ----------
$isos = Get-ChildItem -LiteralPath $Lab -Recurse -File -Filter *.iso -ErrorAction SilentlyContinue
if (-not $isos) {
    Write-Host "Khong co file ISO nao trong $Lab (da don roi?)." -ForegroundColor DarkGray
} else {
    $total = ($isos | Measure-Object Length -Sum).Sum
    Write-Host ("Tim thay {0} ISO, tong {1:N1} GB:" -f $isos.Count, ($total/1GB)) -ForegroundColor Yellow
    $isos | ForEach-Object { Write-Host ("  {0}  ({1:N1} GB)" -f $_.FullName, ($_.Length/1GB)) }
    if (-not $Force) {
        $ans = Read-Host "Xoa cac ISO nay? (Y/N)"
        if ($ans -notmatch "^[Yy]") { Write-Host "Bo qua xoa ISO." -ForegroundColor DarkGray; $isos = @() }
    }
    $deleted = @()
    foreach ($f in $isos) {
        try { Remove-Item -LiteralPath $f.FullName -Force; $deleted += $f; Write-Host "  Da xoa: $($f.Name)" -ForegroundColor Green }
        catch { Write-Host "  Khong xoa duoc: $($f.FullName) - $($_.Exception.Message)" -ForegroundColor Red }
    }
    if ($deleted.Count -gt 0) {
        $freed = ($deleted | Measure-Object Length -Sum).Sum
        Write-Host ("Da giai phong ~{0:N1} GB." -f ($freed/1GB)) -ForegroundColor Green
    }
}

# ---------- Compact dia ao ----------
if ($Compact) {
    $vdisk = Join-Path $cfg.VmwareInstallDir "vmware-vdiskmanager.exe"
    if (-not (Test-Path -LiteralPath $vdisk)) {
        Write-Host "Khong thay vmware-vdiskmanager.exe -> bo qua compact." -ForegroundColor Yellow
    } else {
        $vmdks = Get-ChildItem -LiteralPath $Lab -Recurse -File -Filter *.vmdk -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -notlike "*-s0*" -and $_.Name -notlike "*flat*" }
        foreach ($v in $vmdks) {
            Write-Host "  Compact: $($v.Name) (co the lau)..." -ForegroundColor Yellow
            & $vdisk -k $v.FullName | Out-Null
        }
        Write-Host "Da compact xong." -ForegroundColor Green
    }
}

Set-LabStep "06"
$free = Get-DriveFreeGB (Get-DriveLetter $Lab)
Write-Host "`n=== Xong. O $(Get-DriveLetter $Lab): con $free GB trong. ===" -ForegroundColor Green

exit 0
