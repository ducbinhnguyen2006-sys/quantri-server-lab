#Requires -Version 5.1
<#
.SYNOPSIS
    Toi uu .vmx cho ca 2 VM: bat 3D, chinh VRAM, ngat CD-ROM, giam RAM/thiet bi thua.
.DESCRIPTION
    CHI sua .vmx - phai chay KHI VM DA TAT va DA DONG VMware,
    neu khong VMware se ghi de lai.
.PARAMETER Lab
    Thu muc goc. Mac dinh E:\QuanTriServer
#>
[CmdletBinding()]
param(
    [string]$Lab = "E:\QuanTriServer"
)

$ErrorActionPreference = "Stop"
Write-Host "=== 05 - Toi uu .vmx ===" -ForegroundColor Cyan

# ---------- Helper: set mot key trong .vmx ----------
function Set-VmxKey {
    param([string]$Path, [string]$Key, [string]$Value)

    $lines = Get-Content -LiteralPath $Path
    $pattern = "^\s*" + [regex]::Escape($Key) + "\s*="
    $found = $false
    $out = foreach ($ln in $lines) {
        if ($ln -match $pattern) {
            $found = $true
            "$Key = `"$Value`""
        } else {
            $ln
        }
    }
    if (-not $found) {
        $out = @($out) + "$Key = `"$Value`""
    }
    Set-Content -LiteralPath $Path -Value $out -Encoding UTF8
    Write-Host ("  {0} = {1}" -f $Key, $Value) -ForegroundColor DarkGray
}

# Cau hinh mong muon tung VM  (VRAM 256MB = 268435456 byte)
$targets = @(
    @{ Path = (Join-Path $Lab "VMs\Win10\Win10.vmx");
       Keys = @{ "memsize"="6144"; "mks.enable3d"="TRUE"; "svga.vramSize"="268435456";
                 "svga.guestBackedPrimaryAware"="TRUE"; "ide1:0.startConnected"="FALSE";
                 "sound.present"="FALSE" } },
    @{ Path = (Join-Path $Lab "VMs\WinSV2019\WinSV2019.vmx");
       Keys = @{ "memsize"="4096"; "mks.enable3d"="TRUE"; "svga.vramSize"="268435456";
                 "svga.guestBackedPrimaryAware"="TRUE"; "ide1:0.startConnected"="FALSE";
                 "sound.present"="FALSE" } }
)

$any = $false
foreach ($t in $targets) {
    if (Test-Path -LiteralPath $t.Path) {
        $any = $true
        Write-Host "--- $($t.Path) ---" -ForegroundColor Yellow
        # Backup lan dau
        if (-not (Test-Path -LiteralPath "$($t.Path).bak")) {
            Copy-Item -LiteralPath $t.Path -Destination "$($t.Path).bak" -Force
        }
        foreach ($k in $t.Keys.Keys) {
            Set-VmxKey -Path $t.Path -Key $k -Value $t.Keys[$k]
        }
    } else {
        Write-Host "Khong thay: $($t.Path) (bo qua)" -ForegroundColor DarkGray
    }
}

if (-not $any) {
    Write-Host "Khong tim thay .vmx nao. Hay tao VM truoc (script 04)." -ForegroundColor Red
    exit 1
}

Write-Host "=== Xong. Da sao luu .bak truoc khi sua. ===" -ForegroundColor Green

# Power plan High Performance (khong can Admin)
try {
    & powercfg.exe /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
    Write-Host "Da dat Power plan = High Performance." -ForegroundColor Green
} catch {
    Write-Host "Khong dat duoc power plan (bo qua)." -ForegroundColor DarkGray
}
