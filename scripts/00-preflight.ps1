#Requires -Version 5.1
<#
.SYNOPSIS
    Kiem tra may + LAP HO SO (profile) thich ung cho lab. Chi doc, khong can Admin.
.DESCRIPTION
    Kiem: OS, CPU ao hoa, RAM, o dia, Python/gdown, Internet, Hyper-V/VBS.
    Tu chon o tot nhat, phan loai ho so dung luong & RAM, roi (tuy chon) ghi
    lab.config.json de cac script sau tu dieu chinh.
.PARAMETER Lab
    Ghi de duong dan lab (vd 'D:\QuanTriServer').
.PARAMETER MinFreeGB
    Ghi de nguong dung luong trong toi thieu.
.PARAMETER Save
    Ghi cau hinh + ho so vao lab.config.json.
.PARAMETER InstallDeps
    Tu cai Python/gdown qua winget neu thieu.
.PARAMETER IncludeRemovable
    Cho phep chon ca o ngoai (USB).
.PARAMETER SkipVideos
    Ep bo qua video (tiet kiem ~2GB).
.PARAMETER NoSpeedTest
    Bo qua uoc tinh toc do mang.
.PARAMETER Json
    In them tom tat JSON (cho AI agent doc).
.EXAMPLE
    .\00-preflight.ps1 -Save
.NOTES
    Exit code: 0 = PASS, 1 = WARN, 2 = FAIL.
#>
[CmdletBinding()]
param(
    [string]$Lab,
    [int]$MinFreeGB = 0,
    [switch]$Save,
    [switch]$InstallDeps,
    [switch]$IncludeRemovable,
    [switch]$SkipVideos,
    [switch]$NoSpeedTest,
    [switch]$Json
)

. "$PSScriptRoot\_common.ps1"

$cfg = Get-LabConfig -Lab $Lab

$script:fails = @()
$script:warns = @()
$result = [ordered]@{}

function Add-Fail($m) { $script:fails += $m; Write-Host "  [FAIL] $m" -ForegroundColor Red }
function Add-Warn($m) { $script:warns += $m; Write-Host "  [WARN] $m" -ForegroundColor Yellow }
function Add-Ok($m)   { Write-Host "  [OK]   $m" -ForegroundColor Green }
function Add-Info($m) { Write-Host "  [--]   $m" -ForegroundColor DarkGray }

function Measure-DownloadSpeedMBps {
    # Uoc tinh toc do bang cach tai ~8MB tu Cloudflare. Tra ve MB/s hoac $null.
    try {
        $url = "https://speed.cloudflare.com/__down?bytes=8000000"
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 20
        $sw.Stop()
        $bytes = $resp.RawContentLength
        if ($bytes -gt 0 -and $sw.Elapsed.TotalSeconds -gt 0) {
            return [math]::Round(($bytes / 1MB) / $sw.Elapsed.TotalSeconds, 2)
        }
    } catch {}
    return $null
}

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  00 - KIEM TRA MAY + LAP HO SO (thich ung moi may)" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# ---------- [1] OS ----------
Write-Host "`n[1] He dieu hanh" -ForegroundColor Yellow
try {
    $os = Get-CimInstance Win32_OperatingSystem
    $arch = "$($os.OSArchitecture)"
    $caption = "$($os.Caption)"
    $build = [int]$os.BuildNumber
    Write-Host "  $caption ($arch), build $build"
    $result.OS = "$caption $arch build $build"
    if ($arch -notmatch "64") { Add-Fail "Can Windows 64-bit." }
    elseif ($caption -match "Server") { Add-Warn "Day la Windows Server - co the chay VMware nhung khong khuyen nghi." }
    elseif ($build -lt 19041) { Add-Warn "Build $build hoi cu (nen >= 19041 / Win10 2004). Nen cap nhat Windows." }
    else { Add-Ok "Windows 64-bit phu hop." }
} catch { Add-Warn "Khong doc duoc thong tin OS." }

# ---------- [2] CPU / ao hoa ----------
Write-Host "`n[2] CPU & ao hoa (VT-x/AMD-V)" -ForegroundColor Yellow
$cores = 4
try {
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $cores = [int]$cpu.NumberOfCores
    Write-Host ("  {0} | {1} nhan / {2} luong" -f $cpu.Name, $cpu.NumberOfCores, $cpu.NumberOfLogicalProcessors)
    $result.CPU = "$($cpu.Name) ($($cpu.NumberOfCores)C/$($cpu.NumberOfLogicalProcessors)T)"

    $vf = $cpu.VirtualizationFirmwareEnabled
    $slat = $cpu.SecondLevelAddressTranslationExtensions
    try {
        $ci = Get-ComputerInfo -ErrorAction Stop -Property HyperVRequirementVirtualizationFirmwareEnabled, HyperVRequirementSecondLevelAddressTranslation
        if ($null -ne $ci.HyperVRequirementVirtualizationFirmwareEnabled) { $vf = $ci.HyperVRequirementVirtualizationFirmwareEnabled }
        if ($null -ne $ci.HyperVRequirementSecondLevelAddressTranslation) { $slat = $ci.HyperVRequirementSecondLevelAddressTranslation }
    } catch {}
    $result.VirtualizationFirmware = $vf
    if ($vf -eq $false) {
        Add-Fail "Ao hoa (VT-x/AMD-V) DANG TAT trong BIOS/UEFI. Vao BIOS bat 'Intel VT-x' / 'SVM Mode'."
    } elseif ($null -eq $vf) {
        Add-Warn "Khong xac dinh duoc trang thai ao hoa (thuong gap khi Hyper-V dang bat)."
    } else {
        Add-Ok "Ao hoa phan cung da BAT."
    }
    if ($slat -eq $false) { Add-Warn "SLAT (EPT/RVI) chua bat." }
    if ($cores -lt 4) { Add-Warn "Chi co $cores nhan (khuyen nghi >= 4). vCPU se dat = 1." }
} catch { Add-Warn "Khong doc duoc thong tin CPU." }

# ---------- [3] RAM ----------
Write-Host "`n[3] RAM" -ForegroundColor Yellow
$totalGB = 0
try {
    $cs = Get-CimInstance Win32_ComputerSystem
    $totalGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    $freeGB  = [math]::Round(($os.FreePhysicalMemory * 1KB) / 1GB, 1)
    Write-Host "  Tong: $totalGB GB | Con trong: $freeGB GB"
    $result.RAM_TOTAL_GB = $totalGB
} catch { Add-Warn "Khong doc duoc RAM." }

$ramProfile = Get-RamProfile -TotalGB $totalGB -Cores $cores
$result.RamProfile = $ramProfile.Label
if ($ramProfile.Win10MB -eq 0) {
    Add-Fail "RAM $totalGB GB qua it (< 8 GB) de chay 2 VM. Nang RAM hoac dung may khac."
} elseif ($ramProfile.OneVm) {
    Add-Warn "RAM $totalGB GB: se dat CHE DO 1 VM (chay lan luot, khong dong thoi)."
} else {
    Add-Ok "RAM du ($totalGB GB) - chay 2 VM song song."
}

# ---------- [4] O dia ----------
Write-Host "`n[4] O dia & dung luong" -ForegroundColor Yellow
$sizeProfile = $null
$chosenLetter = $null
try {
    $vols = Get-LabVolumes -IncludeRemovable:$IncludeRemovable | Sort-Object DriveLetter
    foreach ($v in $vols) {
        $kind = if ("$($v.DriveType)" -eq "Removable") { "[ngoai]" } else { "" }
        Write-Host ("  {0}:  {1,7:N1} GB trong / {2,7:N1} GB  {3}" -f $v.DriveLetter, ($v.SizeRemaining/1GB), ($v.Size/1GB), $kind)
    }

    $best = Get-BestDataDrive -IncludeRemovable:$IncludeRemovable
    if ($best) {
        Write-Host ("  -> Chon o chua lab: {0}: ({1:N1} GB trong)" -f $best.DriveLetter, ($best.SizeRemaining/1GB)) -ForegroundColor Cyan
        $result.RecommendedDrive = "$($best.DriveLetter):"
    }

    $chosenLetter = Get-DriveLetter $cfg.Lab
    if (-not $chosenLetter) { $chosenLetter = if ($best) { $best.DriveLetter } else { "C" } ; $cfg.Lab = "${chosenLetter}:\QuanTriServer" }
    $free = Get-DriveFreeGB $chosenLetter
    $result.Lab = $cfg.Lab
    $result.LabDriveFreeGB = $free
    Write-Host "  O chua lab = ${chosenLetter}: ($($cfg.Lab))  -  con $free GB"

    # Chi co 1 o?
    $fixedCount = (Get-LabVolumes | Measure-Object).Count
    if ($fixedCount -le 1) { Add-Warn "May chi co 1 o dia - nen can nhac danh rieng o/phan vung cho lab." }

    # Loai o
    $media = Get-DiskMediaType -DriveLetter $chosenLetter
    $result.DiskType = $media
    if ($media -eq "HDD") { Add-Warn "O ${chosenLetter}: la HDD (khong phai SSD) -> VM se CHAM. Nen dung SSD neu co." }
    elseif ($media -eq "SSD") { Add-Ok "O ${chosenLetter}: la SSD." }

    # Phan loai dung luong
    $sizeProfile = Get-SizeProfile -FreeGB $free
    $result.SizeProfile = $sizeProfile.Id
    $result.SizeProfileLabel = $sizeProfile.Label
    Write-Host ("  -> Ho so dung luong: {0}" -f $sizeProfile.Label) -ForegroundColor Cyan
    if ($sizeProfile.Id -eq "KhongDu") {
        Add-Fail "O ${chosenLetter}: chi con $free GB (< 32 GB). Khong du cho lab 2 VM. Don o / doi o (00-preflight -Lab 'D:\...') / dung o ngoai."
    } else {
        Add-Ok "Dung luong phu hop ho so '$($sizeProfile.Label)'."
    }
} catch { Add-Warn "Khong liet ke duoc o dia." }

# ---------- [5] Python / gdown ----------
Write-Host "`n[5] Python & gdown (de tai tai lieu)" -ForegroundColor Yellow
$py = Get-Command python -ErrorAction SilentlyContinue
if ($py) {
    $pyver = ((python --version) 2>&1) -join " "
    Add-Ok "Python: $pyver"
    $result.Python = "$pyver"
    $gdown = (python -m pip show gdown 2>&1) -join " "
    if ($gdown -match "Name:\s*gdown") { Add-Ok "gdown da cai."; $result.gdown = "installed" }
    else {
        Add-Warn "Chua co gdown."
        if ($InstallDeps) { python -m pip install --upgrade gdown 2>&1 | Out-Null; Add-Ok "Da cai gdown." }
        else { Add-Info "Chay lai voi -InstallDeps hoac: python -m pip install gdown" }
    }
} else {
    $result.Python = "missing"
    $wg = Get-Command winget -ErrorAction SilentlyContinue
    if ($InstallDeps -and $wg) {
        Add-Warn "Chua co Python. Dang cai qua winget..."
        winget install -e --id Python.Python.3.12 --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
        Add-Warn "Da cai Python. MO LAI terminal roi chay lai preflight."
    } elseif (-not $wg) {
        Add-Fail "Chua co Python va khong co winget. Cai Python: https://www.python.org/downloads/"
    } else {
        Add-Warn "Chua co Python. Chay lai voi -InstallDeps hoac cai tay."
    }
}

# ---------- [6] Internet + uoc tinh thoi gian tai ----------
Write-Host "`n[6] Internet (drive.google.com)" -ForegroundColor Yellow
$online = $false
try {
    $online = Test-NetConnection -ComputerName "drive.google.com" -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
    if ($online) { Add-Ok "Ket noi drive.google.com:443 OK."; $result.Internet = $true }
    else { Add-Warn "Khong ket noi duoc drive.google.com:443 (can mang hoac dung -SourceDir)."; $result.Internet = $false }
} catch { Add-Warn "Khong kiem tra duoc Internet." }

if ($online -and -not $NoSpeedTest -and $sizeProfile) {
    $skip = $SkipVideos -or $sizeProfile.SkipVideos
    $gb = if ($skip) { 11.5 } else { 13.5 }
    $speed = Measure-DownloadSpeedMBps
    if ($speed -and $speed -gt 0) {
        $mins = [math]::Round(($gb * 1024) / ($speed * 60), 1)
        $result.DownloadSpeedMBps = $speed
        Add-Info ("Uoc tinh tai {0} GB: ~{1} phut (toc do ~{2} MB/s)." -f $gb, $mins, $speed)
    } else { Add-Info "Khong do duoc toc do mang (bo qua uoc tinh thoi gian)." }
}

# ---------- [7] Hyper-V/VBS, Admin, winget ----------
Write-Host "`n[7] Hyper-V/VBS, quyen Admin, winget" -ForegroundColor Yellow
try {
    $hv = (Get-ComputerInfo -Property HyperVisorPresent).HyperVisorPresent
    $result.HyperVisorPresent = $hv
    if ($hv) { Add-Warn "Hyper-V/VBS dang BAT -> VM se LAG. Chay script 03 + reboot." }
    else { Add-Ok "Hypervisor da tat (VM chay native)." }
} catch { Add-Warn "Khong doc duoc trang thai Hyper-V." }

try {
    $dg = Get-CimInstance Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction Stop
    $result.VBS = $dg.VirtualizationBasedSecurityStatus
    if ($dg.VirtualizationBasedSecurityStatus -eq 0) { Add-Ok "VBS = Off." } else { Add-Warn "VBS = $($dg.VirtualizationBasedSecurityStatus) (nen tat qua script 03)." }
} catch {}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$result.IsAdmin = $isAdmin
if ($isAdmin) { Add-Ok "Dang chay quyen Admin." } else { Add-Info "Chay dang user thuong (script 02/03 se hoi UAC)." }

$wg = Get-Command winget -ErrorAction SilentlyContinue
$result.HasWinget = [bool]$wg
if ($wg) { Add-Ok "winget co san." } else { Add-Warn "Khong co winget." }

# ---------- [8] Canh bao bo sung ----------
Write-Host "`n[8] Canh bao bo sung" -ForegroundColor Yellow

# Pin (laptop)
try {
    $bat = Get-CimInstance Win32_Battery -ErrorAction Stop | Select-Object -First 1
    if ($bat -and $bat.BatteryStatus -eq 1) { Add-Warn "Dang dung PIN (chua cam sac). Cam sac truoc khi tai/cai de tranh tat may." ; $result.OnBattery = $true }
    elseif ($bat) { Add-Ok "Dang cam sac / khong dung pin." ; $result.OnBattery = $false }
} catch {}

# Antivirus
try {
    $av = Get-CimInstance -Namespace root\SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction Stop
    if ($av) {
        $names = ($av | Select-Object -ExpandProperty displayName) -join ", "
        Add-Info "Antivirus: $names. Nen loai tru '$($cfg.Lab)' khoi danh sach quet."
        $result.Antivirus = $names
    }
} catch {}

# VMware da cai?
$vmrun = Join-Path $cfg.VmwareInstallDir "vmrun.exe"
$vmwareInstalled = Test-Path -LiteralPath $vmrun
if (-not $vmwareInstalled) {
    $found = Get-ItemProperty -ErrorAction SilentlyContinue -Path @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*","HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*") | Where-Object { $_.DisplayName -like "*VMware Workstation*" } | Select-Object -First 1
    if ($found) { $vmwareInstalled = $true; $cfg.VmwareInstallDir = if ($found.InstallLocation) { $found.InstallLocation.TrimEnd('\') } else { $cfg.VmwareInstallDir } }
}
$result.VmwareInstalled = $vmwareInstalled
if ($vmwareInstalled) { Add-Info "Phat hien VMware Workstation da cai -> bo qua buoc 02." } else { Add-Info "Chua co VMware -> se cai o buoc 02." }

# ---------- Ghi config + ho so ----------
if ($Save -and $sizeProfile) {
    $cfg.Profile           = $sizeProfile.Id
    $cfg.ProfileLabel      = $sizeProfile.Label
    $cfg.SkipVideos        = ($SkipVideos -or $sizeProfile.SkipVideos)
    $cfg.StagedDownload    = $sizeProfile.Staged
    $cfg.CleanupIso        = $sizeProfile.Cleanup
    $cfg.VmDiskGB          = $sizeProfile.VmDiskGB
    $cfg.VmRamWin10MB      = $ramProfile.Win10MB
    $cfg.VmRamServerMB     = $ramProfile.ServerMB
    $cfg.VmCpu             = $ramProfile.VmCpu
    $cfg.OneVmAtATime      = ($ramProfile.OneVm -or $sizeProfile.Id -eq "SieuTietKiem")
    $cfg.MinFreeGB         = if ($MinFreeGB -gt 0) { $MinFreeGB } else { $sizeProfile.MinFreeGB }
    Save-LabConfig -Config $cfg
    $result.SavedConfig = $script:ConfigPath
}

# ---------- Tong ket ----------
Write-Host "`n==================================================================" -ForegroundColor Cyan
$status = if ($script:fails.Count -gt 0) { "FAIL" } elseif ($script:warns.Count -gt 0) { "WARN" } else { "PASS" }
$color = switch ($status) { "FAIL" { "Red" } "WARN" { "Yellow" } default { "Green" } }
Write-Host "  KET QUA: $status" -ForegroundColor $color
Write-Host "  (Fail: $($script:fails.Count) | Warn: $($script:warns.Count))"
if ($sizeProfile) {
    Write-Host ("  Ho so: dung luong='{0}' | RAM='{1}' | dia ao={2}GB | vCPU={3}" -f $sizeProfile.Label, $ramProfile.Label, $sizeProfile.VmDiskGB, $ramProfile.VmCpu)
}
if ($script:fails.Count -gt 0) {
    Write-Host "`n  Van de nghiem trong:" -ForegroundColor Red
    $script:fails | ForEach-Object { Write-Host "   - $_" -ForegroundColor Red }
    Write-Host "`n  => Sua cac loi tren roi chay lai preflight. KHONG cai tiep." -ForegroundColor Red
} elseif ($script:warns.Count -gt 0) {
    Write-Host "`n  Canh bao (co the tiep tuc voi -Force):" -ForegroundColor Yellow
    $script:warns | ForEach-Object { Write-Host "   - $_" -ForegroundColor Yellow }
} else {
    Write-Host "`n  => May SAN SANG. Buoc tiep: scripts\01-download-drive.ps1" -ForegroundColor Green
}
Write-Host "==================================================================" -ForegroundColor Cyan

if ($Json) {
    $result.Status = $status
    $result.Fails = $script:fails
    $result.Warns = $script:warns
    ($result | ConvertTo-Json -Depth 4)
}

if ($script:fails.Count -gt 0) { exit 2 } elseif ($script:warns.Count -gt 0) { exit 1 } else { exit 0 }
