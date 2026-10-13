#Requires -Version 5.1
<#
.SYNOPSIS
    Ham dung chung cho cac script lab (config, chon o, dung luong, ho so may, trang thai).
.DESCRIPTION
    Dot-source file nay tu cac script khac:
        . "$PSScriptRoot\_common.ps1"
#>

$script:RepoRoot          = Split-Path -Parent $PSScriptRoot
$script:ConfigPath        = Join-Path $RepoRoot "lab.config.json"
$script:ExampleConfigPath = Join-Path $RepoRoot "lab.config.example.json"
$script:StatePath         = Join-Path $RepoRoot "lab.state.json"

# Gia tri mac dinh (neu chua co config)
$script:ConfigDefaults = @{
    Lab               = ""
    DataDrive         = ""
    VmwareInstallDir  = "C:\Program Files (x86)\VMware\VMware Workstation"
    DriveFolderId     = "1khCYAzXvKSkpeot1Rg7PG4A5wyjWqLGK"
    SourceDir         = ""
    Profile           = "Du"
    ProfileLabel      = "Du"
    MinFreeGB         = 32
    RecommendedFreeGB = 80
    SkipVideos        = $false
    StagedDownload    = $false
    CleanupIso        = $false
    VmDiskGB          = 60
    VmRamWin10MB      = 6144
    VmRamServerMB     = 4096
    VmCpu             = 2
    OneVmAtATime      = $false
}

# ============================================================
#  O dia
# ============================================================

function Get-DriveLetter {
    <# Tra ve chu cai o (khong dau ':') tu mot duong dan. VD 'E:\x' -> 'E' #>
    param([Parameter(Mandatory)][string]$Path)
    try {
        $q = Split-Path -Qualifier $Path
        if ($q) { return $q.TrimEnd(':') }
    } catch {}
    if ($Path -match '^([A-Za-z]):') { return $Matches[1] }
    return $null
}

function Get-LabVolumes {
    <# Liet ke cac volume co the dung lam noi chua lab. #>
    [CmdletBinding()]
    param([switch]$IncludeRemovable)
    $types = @("Fixed")
    if ($IncludeRemovable) { $types += "Removable" }
    Get-Volume -ErrorAction SilentlyContinue |
        Where-Object { $_.DriveLetter -and $_.Size -gt 0 -and ($types -contains "$($_.DriveType)") }
}

function Get-BestDataDrive {
    <# Chon o con trong nhieu nhat (uu tien bo qua C:). Tra ve doi tuong volume. #>
    [CmdletBinding()]
    param([string]$ExcludeLetter = "C", [switch]$IncludeRemovable)
    $vols = Get-LabVolumes -IncludeRemovable:$IncludeRemovable
    if (-not $vols) { return $null }
    $nonC = $vols | Where-Object { $_.DriveLetter -ne $ExcludeLetter }
    $pick = if ($nonC) { $nonC } else { $vols }
    return ($pick | Sort-Object SizeRemaining -Descending | Select-Object -First 1)
}

function Get-DriveFreeGB {
    param([Parameter(Mandatory)][string]$DriveLetter)
    $letter = $DriveLetter.TrimEnd(':')
    $v = Get-Volume -DriveLetter $letter -ErrorAction SilentlyContinue
    if ($v) { return [math]::Round($v.SizeRemaining / 1GB, 2) }
    return -1
}

function Get-DiskMediaType {
    <# Tra ve 'SSD' / 'HDD' / 'Unspecified' cho o dia. #>
    param([Parameter(Mandatory)][string]$DriveLetter)
    $letter = $DriveLetter.TrimEnd(':')
    try {
        $mt = (Get-Partition -DriveLetter $letter -ErrorAction Stop |
               Get-Disk | Get-PhysicalDisk |
               Select-Object -First 1).MediaType
        if ($mt) { return "$mt" }
    } catch {}
    return "Unspecified"
}

# ============================================================
#  Ho so may (profile)
# ============================================================

function Get-SizeProfile {
    <# Phan loai theo dung luong trong (GB). Tra ve hashtable. #>
    param([Parameter(Mandatory)][double]$FreeGB)
    if     ($FreeGB -ge 80) { return @{ Id="Du";            Label="Du";              SkipVideos=$false; Staged=$false; Cleanup=$false; VmDiskGB=60; MinFreeGB=80 } }
    elseif ($FreeGB -ge 60) { return @{ Id="ThoaiMai";      Label="Thoai mai";       SkipVideos=$true;  Staged=$false; Cleanup=$false; VmDiskGB=60; MinFreeGB=60 } }
    elseif ($FreeGB -ge 42) { return @{ Id="TietKiem";      Label="Tiet kiem";       SkipVideos=$true;  Staged=$true;  Cleanup=$true;  VmDiskGB=40; MinFreeGB=42 } }
    elseif ($FreeGB -ge 32) { return @{ Id="SieuTietKiem";  Label="Sieu tiet kiem";  SkipVideos=$true;  Staged=$true;  Cleanup=$true;  VmDiskGB=40; MinFreeGB=32 } }
    else                    { return @{ Id="KhongDu";       Label="Khong du";        SkipVideos=$true;  Staged=$true;  Cleanup=$true;  VmDiskGB=40; MinFreeGB=32 } }
}

function Get-RamProfile {
    <# Phan loai theo RAM (GB). Tra ve hashtable. #>
    param([Parameter(Mandatory)][double]$TotalGB, [int]$Cores = 4)
    $vcpu = if ($Cores -ge 4) { 2 } else { 1 }
    if     ($TotalGB -ge 16) { return @{ Win10MB=6144; ServerMB=4096; VmCpu=$vcpu;        OneVm=$false; Label=">=16GB" } }
    elseif ($TotalGB -ge 12) { return @{ Win10MB=4096; ServerMB=3072; VmCpu=$vcpu;        OneVm=$false; Label="12-16GB" } }
    elseif ($TotalGB -ge 8)  { return @{ Win10MB=3072; ServerMB=2048; VmCpu=[Math]::Min($vcpu,1); OneVm=$true;  Label="8-12GB" } }
    else                     { return @{ Win10MB=0;    ServerMB=0;    VmCpu=1;           OneVm=$true;  Label="<8GB" } }
}

function Get-LocalIpv4 {
    <# Lay IP LAN (best-effort) de uoc tinh trong chuong trinh - khong bat buoc. #>
    try {
        return (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
                Where-Object { $_.IPAddress -notmatch '^127\.' -and $_.PrefixOrigin -ne 'WellKnown' } |
                Select-Object -First 1).IPAddress
    } catch { return $null }
}

# ============================================================
#  Config
# ============================================================

function Get-LabConfig {
    <#
    .SYNOPSIS
        Doc lab.config.json (neu co), tra ve doi tuong cau hinh day du.
        Tham so -Lab ghi de duong dan.
    #>
    [CmdletBinding()]
    param([string]$Lab)

    $cfg = $null
    if (Test-Path -LiteralPath $script:ConfigPath) {
        try { $cfg = Get-Content -LiteralPath $script:ConfigPath -Raw | ConvertFrom-Json } catch { $cfg = $null }
    }

    if (-not $cfg) {
        $best = Get-BestDataDrive
        $ltr  = if ($best) { $best.DriveLetter } else { "C" }
        $cfg = [pscustomobject]@{
            Lab               = "${ltr}:\QuanTriServer"
            DataDrive         = "${ltr}:"
            VmwareInstallDir  = $script:ConfigDefaults.VmwareInstallDir
            DriveFolderId     = $script:ConfigDefaults.DriveFolderId
            SourceDir         = ""
            Profile           = $script:ConfigDefaults.Profile
            ProfileLabel      = $script:ConfigDefaults.ProfileLabel
            MinFreeGB         = $script:ConfigDefaults.MinFreeGB
            RecommendedFreeGB = $script:ConfigDefaults.RecommendedFreeGB
            SkipVideos        = [bool]$script:ConfigDefaults.SkipVideos
            StagedDownload    = [bool]$script:ConfigDefaults.StagedDownload
            CleanupIso        = [bool]$script:ConfigDefaults.CleanupIso
            VmDiskGB          = $script:ConfigDefaults.VmDiskGB
            VmRamWin10MB      = $script:ConfigDefaults.VmRamWin10MB
            VmRamServerMB     = $script:ConfigDefaults.VmRamServerMB
            VmCpu             = $script:ConfigDefaults.VmCpu
            OneVmAtATime      = [bool]$script:ConfigDefaults.OneVmAtATime
        }
    }

    # Bo sung truong thieu
    foreach ($k in $script:ConfigDefaults.Keys) {
        if ($null -eq $cfg.PSObject.Properties[$k]) {
            $cfg | Add-Member -NotePropertyName $k -NotePropertyValue $script:ConfigDefaults[$k] -Force
        }
    }

    if ($Lab) { $cfg.Lab = $Lab }
    if (-not $cfg.Lab) {
        $best = Get-BestDataDrive
        $ltr  = if ($best) { $best.DriveLetter } else { "C" }
        $cfg.Lab = "${ltr}:\QuanTriServer"
    }
    # DataDrive luon khop voi o chua Lab
    $dl = Get-DriveLetter $cfg.Lab
    if ($dl) { $cfg.DataDrive = "$($dl):" }
    return $cfg
}

function Save-LabConfig {
    param([Parameter(Mandatory)]$Config)
    $json = $Config | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText($script:ConfigPath, $json, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "Da ghi cau hinh: $script:ConfigPath" -ForegroundColor Green
}

function Assert-FreeSpace {
    param(
        [Parameter(Mandatory)][string]$Path,
        [int]$MinGB = 32,
        [switch]$Force
    )
    $letter = Get-DriveLetter $Path
    if (-not $letter) { Write-Warning "Khong xac dinh duoc o dia tu '$Path'."; return $true }
    $free = Get-DriveFreeGB $letter
    if ($free -lt 0) { Write-Warning "Khong doc duoc dung luong o $letter."; return $true }
    if ($free -lt $MinGB) {
        if ($Force) {
            Write-Warning "O ${letter}: chi con $free GB (< $MinGB GB) nhung tiep tuc do -Force."
            return $true
        }
        Write-Host "O ${letter}: chi con $free GB, CAN >= $MinGB GB. Dung lai." -ForegroundColor Red
        Write-Host "  -> Don o dia, doi o (00-preflight -Lab ...), hoac chay lai voi -Force." -ForegroundColor Yellow
        return $false
    }
    Write-Host "O ${letter}: con $free GB (>= $MinGB GB) -> OK" -ForegroundColor Green
    return $true
}

# ============================================================
#  Tim file tai lieu (ho tro -SourceDir offline)
# ============================================================

function Find-LabFile {
    <#
    .SYNOPSIS
        Tim 1 file tai lieu (ISO/PDF/exe) trong $Lab hoac $SourceDir.
        -Pattern: mau ten (vd '*Windows10*.iso').
    #>
    [CmdletBinding()]
    param([string]$Lab, [string]$SourceDir, [Parameter(Mandatory)][string]$Pattern)
    foreach ($base in @($SourceDir, $Lab)) {
        if (-not $base -or -not (Test-Path -LiteralPath $base)) { continue }
        $hit = Get-ChildItem -LiteralPath $base -Recurse -File -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -like $Pattern } | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

# ============================================================
#  Trang thai (resume)
# ============================================================

function Get-LabState {
    if (Test-Path -LiteralPath $script:StatePath) {
        try { return (Get-Content -LiteralPath $script:StatePath -Raw | ConvertFrom-Json) } catch {}
    }
    return [pscustomobject]@{ Steps = @{} ; Updated = (Get-Date).ToString("s") }
}

function Save-LabState {
    param([Parameter(Mandatory)]$State)
    $State.Updated = (Get-Date).ToString("s")
    $json = $State | ConvertTo-Json -Depth 6
    [System.IO.File]::WriteAllText($script:StatePath, $json, (New-Object System.Text.UTF8Encoding($false)))
}

function Set-LabStep {
    param([Parameter(Mandatory)][string]$Name, [bool]$Done = $true)
    $st = Get-LabState
    $steps = [ordered]@{}
    if ($st.Steps) {
        if ($st.Steps -is [System.Collections.IDictionary]) {
            foreach ($k in @($st.Steps.Keys)) { $steps[$k] = $st.Steps[$k] }
        } else {
            $st.Steps.PSObject.Properties | ForEach-Object { $steps[$_.Name] = $_.Value }
        }
    }
    $steps[$Name] = $Done
    $st.Steps = $steps
    Save-LabState -State $st
}

function Test-LabStep {
    param([Parameter(Mandatory)][string]$Name)
    $st = Get-LabState
    if ($st.Steps -and $st.Steps.PSObject.Properties[$Name]) { return [bool]$st.Steps.PSObject.Properties[$Name].Value }
    return $false
}
