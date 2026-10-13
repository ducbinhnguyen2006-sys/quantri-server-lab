#Requires -Version 5.1
<#
.SYNOPSIS
    Lenh CAI TAT CA (1 lenh) - tu dong hoa toi da, thich ung moi may.
.DESCRIPTION
    Chay lan luot: 00 kiem tra/ho so -> 01 tai (stage 1) -> 02 VMware ->
    03 tat Hyper-V (+reboot) -> 04 tao VM. Sau do huong dan cac buoc can GUI
    (cai Windows trong VM), roi 06 don dep -> 01 stage 2 -> 99 kiem tra.
    Trang thai luu o lab.state.json de chay tiep bang -Resume.
.PARAMETER Lab
    Ghi de duong dan lab.
.PARAMETER SourceDir
    Thu muc tai lieu san (offline).
.PARAMETER Force
    Bo qua canh bao (dung luong/RAM...).
.PARAMETER IncludeRemovable
    Cho phep chon o ngoai (USB).
.PARAMETER InstallDeps
    Tu cai Python/gdown qua winget.
.PARAMETER DryRun
    Chi kiem tra + in ke hoach, khong tai/cai.
.PARAMETER Unattended
    Khong dung Read-Host (danh cho AI agent / chay tu dong).
.PARAMETER Reset
    Xoa trang thai, chay lai tu dau.
.PARAMETER Resume
    Chay tiep tu buoc da luu (mac dinh da tu dong resume; co flag nay cho tuong minh).
.EXAMPLE
    .\install-all.ps1
.EXAMPLE
    .\install-all.ps1 -DryRun -Unattended
#>
[CmdletBinding()]
param(
    [string]$Lab,
    [string]$SourceDir,
    [switch]$Force,
    [switch]$IncludeRemovable,
    [switch]$InstallDeps,
    [switch]$DryRun,
    [switch]$Unattended,
    [switch]$Reset,
    [switch]$Resume
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

if ($Reset) {
    Remove-Item -LiteralPath $script:StatePath -Force -ErrorAction SilentlyContinue
    Write-Host "Da xoa trang thai cu." -ForegroundColor DarkGray
}

function Invoke-LabScript {
    param([Parameter(Mandatory)][string]$Name, [hashtable]$Arguments)
    Write-Host "`n======================== $Name ========================" -ForegroundColor Magenta
    $path = Join-Path $PSScriptRoot $Name
    if ($Arguments -and $Arguments.Count -gt 0) { & $path @Arguments } else { & $path }
    return $LASTEXITCODE
}

function Wait-User([string]$Msg) {
    if ($Unattended) { Write-Host "`n>> $Msg" -ForegroundColor Yellow; return }
    Read-Host "`n>> $Msg (nhan Enter de tiep tuc)"
}

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  INSTALL-ALL - Cai lab quan tri Windows Server (tu thich ung)" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
if ($DryRun) { Write-Host "  *** CHE DO DRYRUN: chi kiem tra, khong tai/cai ***" -ForegroundColor Yellow }
if ($Resume) { Write-Host "  (RESUME: tiep tuc tu buoc da luu trong lab.state.json)" -ForegroundColor DarkGray }

# ---------- [00] Kiem tra + lap ho so ----------
$argsPreflight = @{ Save = $true; InstallDeps = $InstallDeps; IncludeRemovable = $IncludeRemovable }
if ($Lab) { $argsPreflight.Lab = $Lab }
if ($DryRun) { $argsPreflight.NoSpeedTest = $true }
$code = Invoke-LabScript "00-preflight.ps1" $argsPreflight
if ($code -eq 2) {
    Write-Host "`n*** PREFLIGHT FAIL - dung lai. Xem huong dan o tren / troubleshooting.md ***" -ForegroundColor Red
    exit 2
}
if ($code -eq 1 -and -not $Force) {
    Write-Host "`n*** Co CANH BAO. Tiep tuc bang cach them -Force neu ban chac chan. ***" -ForegroundColor Yellow
    Wait-User "Van tiep tuc voi cac canh bao?"
}

$cfg = Get-LabConfig -Lab $Lab
if ($SourceDir) { $cfg.SourceDir = $SourceDir }
Write-Host "`nHO SO: '$($cfg.ProfileLabel)' | Lab = $($cfg.Lab) | dia ao $($cfg.VmDiskGB)GB | 1VM/lan=$($cfg.OneVmAtATime)" -ForegroundColor Cyan

if ($DryRun) {
    Invoke-LabScript "04-create-vms.ps1" (@{ Lab=$cfg.Lab; DryRun=$true }) | Out-Null
    Write-Host "`n=== DRYRUN xong. Bo -DryRun de chay that. ===" -ForegroundColor Green
    exit 0
}

# ---------- [01] Tai giai doan 1 ----------
if (-not (Test-LabStep "01s1")) {
    $a = @{ Stage = 1; Force = $Force }
    if ($cfg.Lab) { $a.Lab = $cfg.Lab }
    if ($cfg.SourceDir) { $a.SourceDir = $cfg.SourceDir }
    if ($cfg.SkipVideos) { $a.SkipVideos = $true }
    $c = Invoke-LabScript "01-download-drive.ps1" $a
    if ($c -ne 0) { Write-Host "*** Tai tai lieu (stage 1) loi. Dung." -ForegroundColor Red; exit $c }
    Set-LabStep "01s1"
} else { Write-Host "[bo qua] 01 stage 1 (da xong)." -ForegroundColor DarkGray }

# ---------- [02] Cai VMware ----------
if (-not (Test-LabStep "02")) {
    $c = Invoke-LabScript "02-install-vmware.ps1" (@{ Lab = $cfg.Lab })
    if ($c -ne 0) { Write-Host "*** Cai VMware loi. Dung." -ForegroundColor Red; exit $c }
    Set-LabStep "02"
} else { Write-Host "[bo qua] 02 VMware (da xong)." -ForegroundColor DarkGray }

# ---------- [03] Tat Hyper-V/VBS (neu can) ----------
$hv = $false
try { $hv = (Get-ComputerInfo -Property HyperVisorPresent).HyperVisorPresent } catch {}
if ($hv -and -not (Test-LabStep "03")) {
    Write-Host "`n*** Hyper-V/VBS dang BAT -> can tat de VMware chay native (chong lag). ***" -ForegroundColor Yellow
    Write-Host "*** Thao tac nay se tat WSL2/Docker/Sandbox va CAN REBOOT. ***" -ForegroundColor Yellow
    Invoke-LabScript "03-disable-hyperv-vbs.ps1" (@{ NoRestart = $true }) | Out-Null
    Set-LabStep "03"
    Write-Host "`n>>> HAY KHOI DONG LAI MAY, roi chay lai:  .\scripts\install-all.ps1 -Resume" -ForegroundColor Red
    exit 0
} elseif (-not $hv) {
    Write-Host "[bo qua] 03 - Hyper-V da tat." -ForegroundColor DarkGray
}

# ---------- [04] Tao VM ----------
if (-not (Test-LabStep "04")) {
    $c = Invoke-LabScript "04-create-vms.ps1" (@{ Lab = $cfg.Lab; Force = $Force })
    if ($c -ne 0) { Write-Host "*** Tao VM loi. Dung." -ForegroundColor Red; exit $c }
    Set-LabStep "04"
} else { Write-Host "[bo qua] 04 tao VM (da xong)." -ForegroundColor DarkGray }

# ---------- Buoc THU CONG 1: cai Windows 10 ----------
Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host "  BUOC THU CONG 1: Cai Windows 10 trong VM 'Win10'" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  1. Mo VMware Workstation BANG TAY (Start menu)."
Write-Host "  2. Power On VM 'Win10' -> cai Windows nhu binh thuong."
Write-Host "  3. Sau khi cai xong + cai VMware Tools (VM > Install VMware Tools)."
Write-Host "  4. Quay lai day va tiep tuc." -ForegroundColor Yellow
Wait-User "Da cai xong Windows 10 + VMware Tools?"
Set-LabStep "osWin10"

# ---------- [06] Don ISO Win10 + compact ----------
if (-not (Test-LabStep "06a") -and $cfg.CleanupIso) {
    Invoke-LabScript "06-cleanup-isos.ps1" (@{ Lab = $cfg.Lab; Compact = $true; Force = $true }) | Out-Null
    Set-LabStep "06a"
}

# ---------- [01] Tai giai doan 2 (Server 2019) ----------
if (-not (Test-LabStep "01s2")) {
    $a = @{ Stage = 2; Force = $Force }
    if ($cfg.Lab) { $a.Lab = $cfg.Lab }
    if ($cfg.SourceDir) { $a.SourceDir = $cfg.SourceDir }
    $c = Invoke-LabScript "01-download-drive.ps1" $a
    if ($c -ne 0) { Write-Host "*** Tai stage 2 loi. Dung." -ForegroundColor Red; exit $c }
    Set-LabStep "01s2"
}

# ---------- Buoc THU CONG 2: cai Windows Server 2019 ----------
Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host "  BUOC THU CONG 2: Cai Windows Server 2019 trong VM 'WinSV2019'" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  Power On VM 'WinSV2019' -> cai Windows Server 2019 (Desktop Experience)."
Write-Host "  Sau khi cai xong + VMware Tools, quay lai day." -ForegroundColor Yellow
Wait-User "Da cai xong Windows Server 2019 + VMware Tools?"
Set-LabStep "osServer"

# ---------- [06] Don ISO Server + compact ----------
if (-not (Test-LabStep "06b") -and $cfg.CleanupIso) {
    Invoke-LabScript "06-cleanup-isos.ps1" (@{ Lab = $cfg.Lab; Compact = $true; Force = $true }) | Out-Null
    Set-LabStep "06b"
}

# ---------- [05] Toi uu .vmx (ngat CD-ROM, 3D, RAM) ----------
if (-not (Test-LabStep "05")) {
    Write-Host "`n[05] Toi uu .vmx (nen TAT han 2 VM truoc khi chay)." -ForegroundColor Yellow
    Invoke-LabScript "05-optimize-vmx.ps1" (@{ Lab = $cfg.Lab }) | Out-Null
    Set-LabStep "05"
}

# ---------- [99] Kiem tra tong the ----------
Invoke-LabScript "99-verify.ps1" (@{ Lab = $cfg.Lab }) | Out-Null

Write-Host "`n==================================================================" -ForegroundColor Green
Write-Host "  HOAN TAT! Tiep theo: lam bai lab theo docs/08." -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
if ($cfg.OneVmAtATime) {
    Write-Host "LUU Y: RAM may ban it -> chi bat 1 VM moi lan de chay muot." -ForegroundColor Yellow
}
