#Requires -Version 5.1
<#
.SYNOPSIS
    Kiem tra may TRUOC KHI CAI dat lab (preflight). Chi doc, khong can Admin.
.DESCRIPTION
    Kiem: OS, CPU ao hoa (VT-x/AMD-V), RAM, o dia + dung luong, Python/gdown,
    Internet, Hyper-V/VBS, quyen Admin. De xuat o dia toi uu va (tuy chon) ghi
    lab.config.json.
.PARAMETER Lab
    Ghi de duong dan lab (vd 'D:\QuanTriServer').
.PARAMETER MinFreeGB
    Nguong dung luong trong toi thieu (mac dinh 60).
.PARAMETER Save
    Ghi lua chon vao lab.config.json.
.PARAMETER InstallDeps
    Tu cai Python/gdown qua winget neu thieu.
.PARAMETER Json
    In them tom tat dang JSON (cho AI agent doc).
.EXAMPLE
    .\00-preflight.ps1 -Save
.EXAMPLE
    .\00-preflight.ps1 -Lab 'D:\QuanTriServer' -InstallDeps -Save
.NOTES
    Exit code: 0 = PASS, 1 = WARN (van tiep tuc duoc voi -Force), 2 = FAIL.
#>
[CmdletBinding()]
param(
    [string]$Lab,
    [int]$MinFreeGB = 0,
    [switch]$Save,
    [switch]$InstallDeps,
    [switch]$Json
)

. "$PSScriptRoot\_common.ps1"

$cfg = Get-LabConfig -Lab $Lab
if ($MinFreeGB -le 0) { $MinFreeGB = [int]$cfg.MinFreeGB }

$script:fails = @()
$script:warns = @()
$result = [ordered]@{}

function Add-Fail($m) { $script:fails += $m; Write-Host "  [FAIL] $m" -ForegroundColor Red }
function Add-Warn($m) { $script:warns += $m; Write-Host "  [WARN] $m" -ForegroundColor Yellow }
function Add-Ok($m)   { Write-Host "  [OK]   $m" -ForegroundColor Green }

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  00 - KIEM TRA MAY TRUOC KHI CAI LAB" -ForegroundColor Cyan
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
    elseif ($build -lt 19041) { Add-Warn "Build $build hoi cu (nen >= 19041 / Win10 2004)." }
    else { Add-Ok "Windows 64-bit phu hop." }
} catch { Add-Warn "Khong doc duoc thong tin OS." }

# ---------- [2] CPU / ao hoa ----------
Write-Host "`n[2] CPU & ao hoa (VT-x/AMD-V)" -ForegroundColor Yellow
try {
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    Write-Host ("  {0} | {1} nhan / {2} luong" -f $cpu.Name, $cpu.NumberOfCores, $cpu.NumberOfLogicalProcessors)
    $result.CPU = "$($cpu.Name) ($($cpu.NumberOfCores)C/$($cpu.NumberOfLogicalProcessors)T)"

    $vf = $cpu.VirtualizationFirmwareEnabled
    $slat = $cpu.SecondLevelAddressTranslationExtensions
    $vmm = $cpu.VMMonitorModeExtensions

    # Bo sung bang Get-ComputerInfo neu co
    try {
        $ci = Get-ComputerInfo -ErrorAction Stop -Property `
            HyperVRequirementVirtualizationFirmwareEnabled, `
            HyperVRequirementSecondLevelAddressTranslation, `
            HyperVRequirementVMMonitorModeExtensions
        if ($null -ne $ci.HyperVRequirementVirtualizationFirmwareEnabled) { $vf = $ci.HyperVRequirementVirtualizationFirmwareEnabled }
        if ($null -ne $ci.HyperVRequirementSecondLevelAddressTranslation) { $slat = $ci.HyperVRequirementSecondLevelAddressTranslation }
        if ($null -ne $ci.HyperVRequirementVMMonitorModeExtensions) { $vmm = $ci.HyperVRequirementVMMonitorModeExtensions }
    } catch {}

    $result.VirtualizationFirmware = $vf
    if ($vf -eq $false) {
        Add-Fail "Ao hoa (VT-x/AMD-V) DANG TAT trong BIOS/UEFI. Vao BIOS bat 'Intel VT-x' / 'SVM Mode'."
    } elseif ($vf -eq $null) {
        Add-Warn "Khong xac dinh duoc trang thai ao hoa (thuong gap khi Hyper-V dang bat)."
    } else {
        Add-Ok "Ao hoa phan cung da BAT."
    }
    if ($slat -eq $false) { Add-Warn "SLAT (EPT/RVI) chua bat." }
    if ($vmm -eq $false) { Add-Warn "VMMonitorModeExtensions chua bat." }
    if ($cpu.NumberOfCores -and $cpu.NumberOfCores -lt 4) { Add-Warn "Chi co $($cpu.NumberOfCores) nhan (khuyen nghi >= 4)." }
} catch { Add-Warn "Khong doc duoc thong tin CPU." }

# ---------- [3] RAM ----------
Write-Host "`n[3] RAM" -ForegroundColor Yellow
try {
    $cs = Get-CimInstance Win32_ComputerSystem
    $totalGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    $freeGB  = [math]::Round(($os.FreePhysicalMemory * 1KB) / 1GB, 1)
    Write-Host "  Tong: $totalGB GB | Con trong: $freeGB GB"
    $result.RAM_TOTAL_GB = $totalGB
    if ($totalGB -lt 8) { Add-Fail "RAM $totalGB GB qua it (toi thieu 12 GB, khuyen nghi 16 GB)." }
    elseif ($totalGB -lt 12) { Add-Warn "RAM $totalGB GB (khuyen nghi >= 16 GB de chay 2 VM)." }
    else { Add-Ok "RAM du ($totalGB GB)." }
} catch { Add-Warn "Khong doc duoc RAM." }

# ---------- [4] O dia & dung luong ----------
Write-Host "`n[4] O dia & dung luong" -ForegroundColor Yellow
try {
    $vols = Get-Volume -ErrorAction Stop | Where-Object { $_.DriveType -eq "Fixed" -and $_.DriveLetter -and $_.Size -gt 0 } |
            Sort-Object DriveLetter
    foreach ($v in $vols) {
        Write-Host ("  {0}:  {1,7:N1} GB trong / {2,7:N1} GB  {3}" -f `
            $v.DriveLetter, ($v.SizeRemaining/1GB), ($v.Size/1GB), $v.FileSystemLabel)
    }
    $best = Get-BestDataDrive
    if ($best) {
        Write-Host ("  -> De xuat o chua lab: {0}: ({1:N1} GB trong)" -f $best.DriveLetter, ($best.SizeRemaining/1GB)) -ForegroundColor Cyan
        $result.RecommendedDrive = "$($best.DriveLetter):"
    }

    $labDriveLetter = Get-DriveLetter $cfg.Lab
    $free = Get-DriveFreeGB $labDriveLetter
    $result.Lab = $cfg.Lab
    $result.LabDriveFreeGB = $free
    Write-Host "  O chua lab se la ${labDriveLetter}: ($($cfg.Lab)) - con $free GB"

    if ($free -lt 0) { Add-Warn "Khong doc duoc dung luong o ${labDriveLetter}:." }
    elseif ($free -lt $MinFreeGB) { Add-Fail "O ${labDriveLetter}: chi con $free GB (< $MinFreeGB GB). Can don bot truoc khi cai." }
    else { Add-Ok "Dung luong o ${labDriveLetter}: du ($free GB >= $MinFreeGB GB)." }
} catch { Add-Warn "Khong liet ke duoc o dia." }

# ---------- [5] Python / gdown ----------
Write-Host "`n[5] Python & gdown (de tai tai lieu)" -ForegroundColor Yellow
$py = Get-Command python -ErrorAction SilentlyContinue
if ($py) {
    $pyver = ((python --version) 2>&1) -join " "
    Add-Ok "Python: $pyver"
    $result.Python = "$pyver"
    $gdown = (python -m pip show gdown 2>&1) -join " "
    if ($gdown -match "Name:\s*gdown") {
        Add-Ok "gdown da cai."
        $result.gdown = "installed"
    } else {
        Add-Warn "Chua co gdown."
        if ($InstallDeps) {
            Write-Host "  Dang cai gdown..." -ForegroundColor Yellow
            python -m pip install --upgrade gdown 2>&1 | Out-Null
            Add-Ok "Da cai gdown (kiem tra lai neu loi)."
        } else {
            Write-Host "  -> Chay lai voi -InstallDeps hoac: python -m pip install gdown" -ForegroundColor DarkGray
        }
    }
} else {
    $result.Python = "missing"
    $wg = Get-Command winget -ErrorAction SilentlyContinue
    if ($InstallDeps -and $wg) {
        Add-Warn "Chua co Python. Dang cai qua winget..."
        winget install -e --id Python.Python.3.12 --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
        Write-Host "  -> Da cai Python. MO LAI terminal de cap nhat PATH, roi chay lai preflight." -ForegroundColor Yellow
    } elseif (-not $wg) {
        Add-Fail "Chua co Python va cung khong co winget. Cai Python thu cong: https://www.python.org/downloads/"
    } else {
        Add-Warn "Chua co Python. Chay lai voi -InstallDeps (tu cai qua winget) hoac cai tay."
    }
}

# ---------- [6] Internet ----------
Write-Host "`n[6] Ket noi Internet (drive.google.com)" -ForegroundColor Yellow
try {
    $ok = Test-NetConnection -ComputerName "drive.google.com" -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
    if ($ok) { Add-Ok "Ket noi toi drive.google.com:443 OK." ; $result.Internet = $true }
    else { Add-Warn "Khong ket noi duoc drive.google.com:443 (can mang de tai tai lieu)." ; $result.Internet = $false }
} catch { Add-Warn "Khong kiem tra duoc Internet." }

# ---------- [7] Hyper-V/VBS, Admin, winget ----------
Write-Host "`n[7] Hyper-V/VBS, quyen Admin, winget" -ForegroundColor Yellow
try {
    $hv = (Get-ComputerInfo -Property HyperVisorPresent).HyperVisorPresent
    $result.HyperVisorPresent = $hv
    if ($hv) { Add-Warn "Hyper-V/VBS dang BAT -> VM se LAG. Can chay script 03 + reboot." }
    else { Add-Ok "Hypervisor da tat (VM se chay native)." }
} catch { Add-Warn "Khong doc duoc trang thai Hyper-V." }

try {
    $dg = Get-CimInstance Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction Stop
    $result.VBS = $dg.VirtualizationBasedSecurityStatus
    if ($dg.VirtualizationBasedSecurityStatus -eq 0) { Add-Ok "VBS = Off." }
    else { Add-Warn "VBS = $($dg.VirtualizationBasedSecurityStatus) (nen tat qua script 03)." }
} catch {}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$result.IsAdmin = $isAdmin
if ($isAdmin) { Add-Ok "Dang chay voi quyen Admin." } else { Write-Host "  [--]   Chay dang user thuong (binh thuong; script 02/03 se hoi UAC)." -ForegroundColor DarkGray }

$wg = Get-Command winget -ErrorAction SilentlyContinue
$result.HasWinget = [bool]$wg
if ($wg) { Add-Ok "winget co san ($((winget --version) 2>&1))." } else { Add-Warn "Khong co winget (khong tu cai duoc Python)." }

# ---------- Ghi config ----------
if ($Save) {
    $cfg.Lab = $cfg.Lab
    $cfg.MinFreeGB = $MinFreeGB
    Save-LabConfig -Config $cfg
}

# ---------- Tong ket ----------
Write-Host "`n==================================================================" -ForegroundColor Cyan
$status = if ($script:fails.Count -gt 0) { "FAIL" } elseif ($script:warns.Count -gt 0) { "WARN" } else { "PASS" }
$color = switch ($status) { "FAIL" { "Red" } "WARN" { "Yellow" } default { "Green" } }
Write-Host "  KET QUA: $status" -ForegroundColor $color
Write-Host "  (Fail: $($script:fails.Count) | Warn: $($script:warns.Count))" 
if ($script:fails.Count -gt 0) {
    Write-Host "`n  Van de nghiem trong:" -ForegroundColor Red
    $script:fails | ForEach-Object { Write-Host "   - $_" -ForegroundColor Red }
    Write-Host "`n  => Sua cac loi tren roi chay lai preflight." -ForegroundColor Red
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

# Exit code
if ($script:fails.Count -gt 0) { exit 2 } elseif ($script:warns.Count -gt 0) { exit 1 } else { exit 0 }
