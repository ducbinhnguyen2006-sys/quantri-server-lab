#Requires -Version 5.1
<#
.SYNOPSIS
    Tai bo tai lieu lab tu Google Drive (ho tro tai theo giai doan, bo video, offline).
.DESCRIPTION
    - Doc cau hinh tu lab.config.json.
    - Neu co -SourceDir (hoac config.SourceDir): dung tai lieu co san, KHONG tai.
    - Tu dong do manifest file ID (gdown --json) de tai CHON LOC tung file.
    - -Stage 1 = VMware + Win10 (+PDF, +video neu khong bo); -Stage 2 = Server 2019.
    - Neu khong do duoc manifest -> tai ca folder (gdown --folder) roi xoa video neu can.
.PARAMETER Lab
    Thu muc dich (ghi de cau hinh).
.PARAMETER Stage
    0 = tai het (mac dinh), 1 = giai doan 1, 2 = giai doan 2.
.PARAMETER SkipVideos
    Bo qua video bai giang (~2GB).
.PARAMETER SourceDir
    Thu muc chua tai lieu da tai san (che do offline).
.PARAMETER RefreshManifest
    Ep do lai manifest file ID.
.PARAMETER Force
    Bo qua canh bao dung luong.
#>
[CmdletBinding()]
param(
    [string]$Lab,
    [ValidateSet(0,1,2)][int]$Stage = 0,
    [switch]$SkipVideos,
    [string]$SourceDir,
    [switch]$RefreshManifest,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

Write-Host "=== 01 - Tai bo tai lieu tu Google Drive ===" -ForegroundColor Cyan

$cfg = Get-LabConfig -Lab $Lab
if ($SourceDir) { $cfg.SourceDir = $SourceDir }
$skip = ($SkipVideos -or $cfg.SkipVideos)
$manifestPath = Join-Path $PSScriptRoot "drive-files.json"

Write-Host "Thu muc lab : $($cfg.Lab)"
Write-Host "Ho so       : $($cfg.ProfileLabel) (bo video=$skip, staged=$($cfg.StagedDownload))"

# ---------- Che do offline: dung tai lieu co san ----------
if ($cfg.SourceDir -and (Test-Path -LiteralPath $cfg.SourceDir)) {
    Write-Host "Che do OFFLINE: dung tai lieu tai '$($cfg.SourceDir)'." -ForegroundColor Yellow
    $need = @('*Windows10*.iso','*SV*2019*.iso','*VMware-workstation*.exe')
    foreach ($p in $need) {
        $f = Find-LabFile -SourceDir $cfg.SourceDir -Pattern $p
        if ($f) { Write-Host "  OK: $f" -ForegroundColor Green } else { Write-Host "  THIEU: $p trong $($cfg.SourceDir)" -ForegroundColor Yellow }
    }
    Save-LabConfig -Config $cfg
    Set-LabStep "01"
    Write-Host "=== Xong (offline). Tiep: 02-install-vmware.ps1 ===" -ForegroundColor Green
    exit 0
}

# ---------- Kiem tra dung luong ----------
$needGB = if ($Stage -eq 2) { 6 } elseif ($skip) { 12 } else { 15 }
if (-not (Assert-FreeSpace -Path $cfg.Lab -MinGB $needGB -Force:$Force)) { exit 1 }

# ---------- Python / gdown ----------
$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) {
    Write-Host "Chua co Python." -ForegroundColor Red
    $wg = Get-Command winget -ErrorAction SilentlyContinue
    if ($wg) {
        Write-Host "Dang cai Python qua winget..." -ForegroundColor Yellow
        winget install -e --id Python.Python.3.12 --accept-source-agreements --accept-package-agreements
        Write-Host "Da cai Python. MO LAI terminal roi chay lai script nay." -ForegroundColor Yellow
    } else {
        Write-Host "Cai Python: https://www.python.org/downloads/ (tick 'Add python.exe to PATH')." -ForegroundColor Red
    }
    exit 1
}
Write-Host ("Python: " + ((python --version) 2>&1))
$gdownInfo = (python -m pip show gdown 2>&1) -join "`n"
if ($gdownInfo -notmatch "Name:\s*gdown") { Write-Host "Cai gdown..." -ForegroundColor Yellow; python -m pip install --upgrade gdown | Out-Null }

$env:PYTHONUTF8 = "1"
$env:PYTHONIOENCODING = "utf-8"

New-Item -ItemType Directory -Force -Path $cfg.Lab | Out-Null

# ---------- Helper phan loai file ----------
function Get-EntryKind([string]$p) {
    if ($p -match '\.(mp4|mkv|avi|mov|wmv)$')            { return 'video' }
    if ($p -match '(?i)VMware-workstation.*\.exe$')       { return 'vmware' }
    if ($p -match '(?i)windows\s*10')                     { return 'win10' }
    if ($p -match '(?i)sv\s*2019|server\s*2019|winsv')    { return 'server' }
    if ($p -match '\.pdf$')                               { return 'pdf' }
    if ($p -match '\.iso$')                               { return 'other-iso' }
    return 'other'
}

# ---------- Doc / do manifest ----------
$entries = @()
$manifest = $null
if ((Test-Path -LiteralPath $manifestPath) -and -not $RefreshManifest) {
    try { $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json } catch {}
}
if ($manifest -and $manifest.files -and @($manifest.files).Count -gt 0 -and -not $RefreshManifest) {
    $entries = @($manifest.files)
    Write-Host "Dung manifest co san ($($entries.Count) file)." -ForegroundColor DarkGray
} else {
    Write-Host "Dang do danh sach file tu Drive (gdown --json)..." -ForegroundColor Yellow
    try {
        $raw = (python -m gdown --folder $cfg.DriveFolderId --json 2>$null) -join "`n"
        $json = $raw.Substring($raw.IndexOf('['))
        $list = $json | ConvertFrom-Json
        foreach ($e in $list) {
            $id = $null
            if ($e.url -match 'id=([A-Za-z0-9_\-]+)') { $id = $Matches[1] }
            elseif ($e.url -match '/d/([A-Za-z0-9_\-]+)') { $id = $Matches[1] }
            elseif ($e.id) { $id = $e.id }
            if ($id) { $entries += [pscustomobject]@{ id = $id; path = "$($e.path)" } }
        }
        if ($entries.Count -gt 0) {
            $mj = [pscustomobject]@{ generated = (Get-Date).ToString("s"); note = "auto"; files = $entries } | ConvertTo-Json -Depth 5
            [System.IO.File]::WriteAllText($manifestPath, $mj, (New-Object System.Text.UTF8Encoding($false)))
            Write-Host "Da do duoc $($entries.Count) file -> $manifestPath" -ForegroundColor Green
        }
    } catch { Write-Host "Khong do duoc manifest: $($_.Exception.Message)" -ForegroundColor Yellow }
}

# ---------- Tai ----------
$downloaded = @()
if ($entries.Count -gt 0) {
    $selected = $entries | Where-Object {
        $k = Get-EntryKind $_.path
        $isServer = ($k -eq 'server')
        $isVideo  = ($k -eq 'video')
        switch ($Stage) {
            1 { (-not $isServer) -and (-not $isVideo -or -not $skip) }
            2 { $isServer }
            default { (-not $isVideo -or -not $skip) }
        }
    }
    Write-Host "Se tai $($selected.Count) file (Stage=$Stage, bo video=$skip)." -ForegroundColor Yellow
    foreach ($e in $selected) {
        $rel = ($e.path -replace '/', '\')
        $dest = Join-Path $cfg.Lab $rel
        $destDir = Split-Path -Parent $dest
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
        if ((Test-Path -LiteralPath $dest) -and (Get-Item -LiteralPath $dest).Length -gt 0) {
            Write-Host "  [bo qua] $rel (da co)" -ForegroundColor DarkGray; continue
        }
        Write-Host "  [tai] $rel" -ForegroundColor Yellow
        python -m gdown "https://drive.google.com/uc?id=$($e.id)" -O $dest --continue
        $downloaded += $rel
    }
} else {
    Write-Host "Khong co manifest -> tai CA folder (10-40 phut). Neu dung giua chung, chay lai de tiep tuc." -ForegroundColor Yellow
    python -m gdown --folder $cfg.DriveFolderId -O $cfg.Lab --continue
    if ($skip) {
        $vd = Join-Path $cfg.Lab "video"
        if (Test-Path -LiteralPath $vd) { Remove-Item -LiteralPath $vd -Recurse -Force; Write-Host "Da xoa thu muc video (bo video)." -ForegroundColor Green }
    }
}

# ---------- Kiem tra ket qua ----------
Write-Host "`nKiem tra tai lieu trong $($cfg.Lab):" -ForegroundColor Cyan
foreach ($p in @('*Windows10*.iso','*SV*2019*.iso','*VMware-workstation*.exe')) {
    $f = Find-LabFile -Lab $cfg.Lab -Pattern $p
    if ($f) { Write-Host "  OK: $f" -ForegroundColor Green } else { Write-Host "  THIEU: $p" -ForegroundColor Yellow }
}

Set-LabStep "01"
if ($Stage -ne 2) {
    Write-Host "`n=== Xong. Tiep: 02-install-vmware.ps1  (Stage 2 se tai sau khi cai VM1) ===" -ForegroundColor Green
} else {
    Write-Host "`n=== Xong Stage 2. Tiep: 04-create-vms.ps1 ===" -ForegroundColor Green
}

exit 0
