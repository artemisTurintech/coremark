$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
Set-Location $RepoRoot

# --- Dependency bootstrap ---

function Find-Tool {
    param([string]$Name, [string]$ScoopPath)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    if (Test-Path $ScoopPath) { return $ScoopPath }
    return $null
}

function Install-Via-Scoop {
    param([string]$Package)
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Host "Scoop not found. Installing Scoop..."
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
    }
    Write-Host "Installing '$Package' via Scoop..."
    scoop install $Package
    # Reload PATH so newly installed shims are visible in this session
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH", "User")
}

$make = Find-Tool "make" "$env:USERPROFILE\scoop\shims\make.exe"
if (-not $make) {
    Install-Via-Scoop "make"
    $make = Find-Tool "make" "$env:USERPROFILE\scoop\shims\make.exe"
    if (-not $make) { throw "make could not be installed. Install it manually and retry." }
}
Write-Host "make: $make"

$gcc = Find-Tool "gcc" "$env:USERPROFILE\scoop\apps\gcc\current\bin\gcc.exe"
if (-not $gcc) {
    Install-Via-Scoop "gcc"
    $gcc = Find-Tool "gcc" "$env:USERPROFILE\scoop\apps\gcc\current\bin\gcc.exe"
    if (-not $gcc) { throw "gcc could not be installed. Install it manually and retry." }
}
Write-Host "gcc:  $gcc"

# --- End dependency bootstrap ---

# make runs bash internally; bash cannot parse backslashes in Windows paths
$gccForMake = $gcc -replace '\\', '/'

& $make compile PORT_DIR=posix NO_LIBRT=1 "CC=$gccForMake" "OPATH="
