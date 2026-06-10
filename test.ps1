$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$md5     = [System.Security.Cryptography.MD5]::Create()
$failed  = $false

foreach ($line in Get-Content "coremark.md5") {
    $line = $line.TrimEnd("`r")
    if ([string]::IsNullOrWhiteSpace($line)) { continue }

    $expectedHash, $file = $line -split '  ', 2

    # Read raw bytes and strip \r (0x0D) to normalise CRLF -> LF before hashing
    $bytes        = [System.IO.File]::ReadAllBytes($file) | Where-Object { $_ -ne 0x0D }
    $hashBytes    = $md5.ComputeHash([byte[]]$bytes)
    $computedHash = ($hashBytes | ForEach-Object { $_.ToString("x2") }) -join ""

    if ($computedHash -eq $expectedHash) {
        Write-Host "${file}: OK"
    } else {
        Write-Host "${file}: FAILED  expected=$expectedHash  got=$computedHash"
        $failed = $true
    }
}

if ($failed) { exit 1 }
