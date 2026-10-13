#Requires -Version 5.1
<#
.SYNOPSIS
    Ham dung chung cho cac script lab (config, chon o dia, kiem tra dung luong).
.DESCRIPTION
    Dot-source file nay tu cac script khac:
        . "$PSScriptRoot\_common.ps1"
    Cung cap: Get-LabConfig, Save-LabConfig, Get-BestDataDrive,
              Get-DriveFreeGB, Get-DriveLetter, Assert-FreeSpace.
#>

$script:RepoRoot         = Split-Path -Parent $PSScriptRoot
$script:ConfigPath       = Join-Path $RepoRoot "lab.config.json"
$script:ExampleConfigPath = Join-Path $RepoRoot "lab.config.example.json"

$script:ConfigDefaults = @{
    Lab              = ""
    DataDrive        = ""
    VmwareInstallDir = "C:\Program Files (x86)\VMware\VMware Workstation"
    DriveFolderId    = "1khCYAzXvKSkpeot1Rg7PG4A5wyjWqLGK"
    MinFreeGB        = 60
    RecommendedFreeGB = 80
}

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

function Get-BestDataDrive {
    <# Chon o co dinh con trong nhieu nhat (bo qua C:). Tra ve doi tuong volume. #>
    [CmdletBinding()]
    param([string]$ExcludeLetter = "C")
    $vols = Get-Volume -ErrorAction SilentlyContinue |
        Where-Object { $_.DriveType -eq "Fixed" -and $_.DriveLetter -and $_.DriveLetter -ne $ExcludeLetter -and $_.Size -gt 0 }
    if (-not $vols) {
        # Neu chi co C: thi lay C: lam chot
        $vols = Get-Volume -ErrorAction SilentlyContinue |
            Where-Object { $_.DriveType -eq "Fixed" -and $_.DriveLetter -and $_.Size -gt 0 }
    }
    if (-not $vols) { return $null }
    return ($vols | Sort-Object SizeRemaining -Descending | Select-Object -First 1)
}

function Get-DriveFreeGB {
    param([Parameter(Mandatory)][string]$DriveLetter)
    $letter = $DriveLetter.TrimEnd(':')
    $v = Get-Volume -DriveLetter $letter -ErrorAction SilentlyContinue
    if ($v) { return [math]::Round($v.SizeRemaining / 1GB, 2) }
    return -1
}

function Get-LabConfig {
    <#
    .SYNOPSIS
        Doc lab.config.json (neu co), tra ve doi tuong cau hinh.
        Neu thieu -> dung defaults + tu dong chon o trong nhieu nhat.
        Tham so -Lab ghi de duong dan.
    #>
    [CmdletBinding()]
    param([string]$Lab)

    $cfg = $null
    if (Test-Path -LiteralPath $script:ConfigPath) {
        try { $cfg = Get-Content -LiteralPath $script:ConfigPath -Raw | ConvertFrom-Json } catch { $cfg = $null }
    }

    if (-not $cfg) {
        $best  = Get-BestDataDrive
        $ltr   = if ($best) { $best.DriveLetter } else { "C" }
        $cfg = [pscustomobject]@{
            Lab               = "${ltr}:\QuanTriServer"
            DataDrive         = "${ltr}:"
            VmwareInstallDir  = $script:ConfigDefaults.VmwareInstallDir
            DriveFolderId     = $script:ConfigDefaults.DriveFolderId
            MinFreeGB         = $script:ConfigDefaults.MinFreeGB
            RecommendedFreeGB = $script:ConfigDefaults.RecommendedFreeGB
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
    if (-not $cfg.DataDrive -or $cfg.DataDrive -eq "") {
        $d = Get-DriveLetter $cfg.Lab
        $cfg.DataDrive = "$($d):"
    }
    return $cfg
}

function Save-LabConfig {
    param([Parameter(Mandatory)]$Config)
    $Config | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $script:ConfigPath -Encoding UTF8
    Write-Host "Da ghi cau hinh: $script:ConfigPath" -ForegroundColor Green
}

function Assert-FreeSpace {
    <#
    .SYNOPSIS
        Kiem tra o chua $Path co du $MinGB trong khong.
        Tra ve $true neu du (hoac co -Force), $false neu thieu (khong co -Force).
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [int]$MinGB = 60,
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
        Write-Host "  -> Don o dia, hoac chay lai voi -Force de bo qua canh bao." -ForegroundColor Yellow
        return $false
    }
    Write-Host "O ${letter}: con $free GB (>= $MinGB GB) -> OK" -ForegroundColor Green
    return $true
}
