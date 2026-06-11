param(
    [int]$Runs = 1   # number of repeated performance runs
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
Set-Location $RepoRoot

function Find-Tool {
    param([string]$Name, [string]$ScoopPath)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    if (Test-Path $ScoopPath) { return $ScoopPath }
    return $null
}

$make = Find-Tool "make" "$env:USERPROFILE\scoop\shims\make.exe"
if (-not $make) { throw "make not found. Run compile.ps1 first to install dependencies." }

$gcc  = Find-Tool "gcc" "$env:USERPROFILE\scoop\apps\gcc\current\bin\gcc.exe"
if (-not $gcc)  { throw "gcc not found. Run compile.ps1 first to install dependencies." }

$gccForMake = $gcc -replace '\\', '/'
$exe        = "$RepoRoot\coremark.exe"

& $make compile PORT_DIR=posix NO_LIBRT=1 "CC=$gccForMake" "OPATH="

# --- Stats helpers (population std-dev) ---
function Stat-Mean {
    param([double[]]$v)
    ($v | Measure-Object -Sum).Sum / $v.Count
}
function Stat-Std {
    param([double[]]$v)
    $m = Stat-Mean $v
    [Math]::Sqrt((($v | ForEach-Object { ($_ - $m) * ($_ - $m) } |
        Measure-Object -Sum).Sum / $v.Count))
}

# --- Repeated performance runs ---
$scores = @()   # Iterations/Sec  (primary CoreMark score)
$times  = @()   # Total time (secs)
$iters  = @()   # Iterations executed
$errs   = @()   # 1.0 if errors detected, else 0.0

Write-Host ""
Write-Host "Starting $Runs performance run(s)..."
Write-Host ""

for ($i = 1; $i -le $Runs; $i++) {
    Write-Host "--- Performance run $i / $Runs ---"

    $runOutput = & $exe "0x0" "0x0" "0x66" 0 7 1 2000
    $runOutput | Out-Host
    $runOutput | Set-Content -Path "$RepoRoot\run1.log" -Encoding ascii

    $text = if ($runOutput) { $runOutput -join "`n" } else { "" }

    $m = [regex]::Match($text, 'Iterations/Sec\s*:\s*([\d.]+)')
    if ($m.Success) { $scores += [double]$m.Groups[1].Value }

    $m = [regex]::Match($text, 'Total time \(secs\)\s*:\s*([\d.]+)')
    if ($m.Success) { $times += [double]$m.Groups[1].Value }

    # "Iterations       : 100000" — \s+ prevents matching "Iterations/Sec"
    $m = [regex]::Match($text, 'Iterations\s+:\s+(\d+)')
    if ($m.Success) { $iters += [double]$m.Groups[1].Value }

    $errs += [double]([int]($text -match 'Errors detected'))
    Write-Host ""
}

# --- Single validation run ---
Write-Host "--- Validation run -> run2.log ---"
& $exe "0x3415" "0x3415" "0x66" 0 7 1 2000 | Tee-Object -FilePath "$RepoRoot\run2.log"
Write-Host ""

# --- Aggregate and export ---
$result = [ordered]@{
    num_runs             = $Runs
    coremark_score_mean  = [Math]::Round((Stat-Mean $scores), 4)
    coremark_score_std   = [Math]::Round((Stat-Std  $scores), 4)
    total_time_secs_mean = [Math]::Round((Stat-Mean $times),  4)
    total_time_secs_std  = [Math]::Round((Stat-Std  $times),  4)
    iterations_mean      = [Math]::Round((Stat-Mean $iters),  4)
    iterations_std       = [Math]::Round((Stat-Std  $iters),  4)
    error_rate_mean      = [Math]::Round((Stat-Mean $errs),   4)
    error_rate_std       = [Math]::Round((Stat-Std  $errs),   4)
}

$json = @($result) | ConvertTo-Json

# UTF-8 without BOM (compatible with Python, jq, etc.)
[System.IO.File]::WriteAllText(
    "$RepoRoot\artemis_results.json",
    ($json + [System.Environment]::NewLine)
)

Write-Host "Results exported to artemis_results.json"
Write-Host $json
