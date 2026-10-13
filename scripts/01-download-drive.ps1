#Requires -Version 5.1
<#
.SYNOPSIS
    Tải bộ tài liệu lab (~13.5 GB) từ Google Drive.
.DESCRIPTION
    - Kiểm tra Python + cài gdown.
    - Đặt PYTHONUTF8=1 để tránh lỗi 'charmap' với tên tiếng Việt.
    - Tải toàn bộ folder vào $Lab.
.PARAMETER Lab
    Thư mục đích. Mặc định E:\QuanTriServer
.PARAMETER DriveFolderId
    ID folder Google Drive nguồn.
#>
[CmdletBinding()]
param(
    [string]$Lab = "E:\QuanTriServer",
    [string]$DriveFolderId = "1khCYAzXvKSkpeot1Rg7PG4A5wyjWqLGK"
)

$ErrorActionPreference = "Stop"
Write-Host "=== 01 - Tai bo tai lieu tu Google Drive ===" -ForegroundColor Cyan

# 1) Python?
$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) {
    Write-Host "KHONG tim thay Python. Cai tai https://www.python.org/downloads/ (tick 'Add python.exe to PATH') roi chay lai." -ForegroundColor Red
    exit 1
}
Write-Host ("Python: " + ((python --version) 2>&1))

# 2) gdown
Write-Host "Cai/cap nhat gdown..." -ForegroundColor Yellow
python -m pip install --upgrade gdown | Out-Null

# 3) UTF-8 (bat buoc voi ten tieng Viet)
$env:PYTHONUTF8 = "1"
$env:PYTHONIOENCODING = "utf-8"

# 4) Tai
New-Item -ItemType Directory -Force -Path $Lab | Out-Null
Set-Location $Lab
Write-Host "Bat dau tai folder $DriveFolderId vao $Lab (co the mat 10-40 phut)..." -ForegroundColor Yellow
Write-Host "Neu dung giua chung, chay lai script nay de tiep tuc." -ForegroundColor DarkGray
python -m gdown --folder $DriveFolderId

Write-Host "=== Hoan tat. Noi dung trong $Lab : ===" -ForegroundColor Green
Get-ChildItem $Lab | Select-Object Name, @{n='MB';e={[math]::Round($_.Length/1MB,1)}}
