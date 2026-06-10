$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$make = "$env:USERPROFILE\scoop\shims\make.exe"
$gcc  = "$env:USERPROFILE\scoop\apps\gcc\current\bin\gcc.exe"

& $make compile PORT_DIR=posix NO_LIBRT=1 "CC=$gcc" "OPATH="
