# Builds release binaries then compiles a per-user (no elevation) Inno Setup installer.
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $root

& (Join-Path $PSScriptRoot 'build-windows-portable.ps1')

$iscc = @(
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
  "${env:LOCALAPPDATA}\Programs\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $iscc) {
  throw 'Inno Setup 6 (ISCC.exe) not found. Install from https://jrsoftware.org/isinfo.php'
}

$iss = Join-Path $PSScriptRoot 'slst-user-install.iss'
& $iscc $iss
Write-Host "Installer written under dist\SLST-Setup-User.exe"
