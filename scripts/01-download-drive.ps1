#Requires -Version 5.1
<#
.SYNOPSIS
    Tai bo tai lieu lab (~13.5 GB) tu Google Drive.
.DESCRIPTION
    - Doc cau hinh tu lab.config.json (hoac tu dong chon o).
    - Kiem tra dung luong o truoc khi tai.
    - Cai gdown neu thieu (pip, hoac winget cho Python).
    - PYTHONUTF8=1 de tranh loi 'charmap' voi ten tieng Viet.
.PARAMETER Lab
    Thu muc dich (ghi de cau hinh).
.PARAMETER Force
    Bo qua canh bao dung luong.
#>
[CmdletBinding()]
param(
    [string]$Lab,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

Write-Host "=== 01 - Tai bo tai lieu tu Google Drive ===" -ForegroundColor Cyan

$cfg = Get-LabConfig -Lab $Lab
Write-Host "Thu muc lab: $($cfg.Lab)"

# 1) Kiem tra dung luong o (can ~15 GB)
if (-not (Assert-FreeSpace -Path $cfg.Lab -MinGB 16 -Force:$Force)) {
    exit 1
}

# 2) Python
$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) {
    Write-Host "Chua co Python." -ForegroundColor Red
    $wg = Get-Command winget -ErrorAction SilentlyContinue
    if ($wg) {
        Write-Host "Dang cai Python qua winget..." -ForegroundColor Yellow
        winget install -e --id Python.Python.3.12 --accept-source-agreements --accept-package-agreements
        Write-Host "Da cai Python. MO LAI terminal de cap nhat PATH, roi chay lai script nay." -ForegroundColor Yellow
    } else {
        Write-Host "Hay cai Python: https://www.python.org/downloads/ (tick 'Add python.exe to PATH')." -ForegroundColor Red
    }
    exit 1
}
Write-Host ("Python: " + ((python --version) 2>&1))

# 3) gdown
$gdownInfo = (python -m pip show gdown 2>&1) -join "`n"
if ($gdownInfo -notmatch "Name:\s*gdown") {
    Write-Host "Cai gdown..." -ForegroundColor Yellow
    python -m pip install --upgrade gdown | Out-Null
} else {
    Write-Host "gdown da co san." -ForegroundColor Green
}

# 4) UTF-8 (bat buoc voi ten tieng Viet)
$env:PYTHONUTF8 = "1"
$env:PYTHONIOENCODING = "utf-8"

# 5) Tai
New-Item -ItemType Directory -Force -Path $cfg.Lab | Out-Null
Set-Location $cfg.Lab
Write-Host "Bat dau tai folder $($cfg.DriveFolderId) vao $($cfg.Lab) (10-40 phut)..." -ForegroundColor Yellow
Write-Host "Neu dung giua chung, chay lai script nay de tiep tuc." -ForegroundColor DarkGray
python -m gdown --folder $cfg.DriveFolderId

Write-Host "=== Hoan tat. Noi dung trong $($cfg.Lab): ===" -ForegroundColor Green
Get-ChildItem $cfg.Lab | Select-Object Name, @{n='MB';e={[math]::Round($_.Length/1MB,1)}}
