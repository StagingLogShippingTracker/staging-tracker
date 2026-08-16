# Builds release binaries then compiles a per-user (no elevation) Inno Setup installer.
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $root
. (Join-Path $PSScriptRoot '_common.ps1')

& (Join-Path $PSScriptRoot 'build-windows-portable.ps1')

$iscc = @(
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
  "${env:LOCALAPPDATA}\Programs\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $iscc) {
  throw 'Inno Setup 6 (ISCC.exe) not found. Install from https://jrsoftware.org/isinfo.php'
}

$iss = Join-Path $PSScriptRoot 'swift-staging-log-user-install.iss'
& $iscc $iss
if ($LASTEXITCODE -ne 0) {
  throw "Inno Setup compilation failed (exit $LASTEXITCODE)."
}

$installer = Join-Path $root 'dist\SwiftStagingLog-Setup-User.exe'
if (-not (Test-Path $installer)) {
  throw "Installer missing after compilation: $installer"
}
Write-RepoSha256 -Path $installer
Write-Host "Installer written under dist\SwiftStagingLog-Setup-User.exe"
