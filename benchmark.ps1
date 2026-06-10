$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$make = "$env:USERPROFILE\scoop\shims\make.exe"
$gcc  = "$env:USERPROFILE\scoop\apps\gcc\current\bin\gcc.exe"
$exe  = "$PSScriptRoot\coremark.exe"

# Build if the binary is missing or sources are newer
& $make compile PORT_DIR=posix NO_LIBRT=1 "CC=$gcc" "OPATH="

# Performance run  (matches Makefile run1.log target)
Write-Host "Performance run -> run1.log"
& $exe 0x0 0x0 0x66 0 7 1 2000 | Tee-Object -FilePath run1.log

# Validation run   (matches Makefile run2.log target)
Write-Host "Validation run  -> run2.log"
& $exe 0x3415 0x3415 0x66 0 7 1 2000 | Tee-Object -FilePath run2.log

Write-Host ""
Write-Host "Check run1.log and run2.log for results."
Write-Host "See README.md for run and reporting rules."
