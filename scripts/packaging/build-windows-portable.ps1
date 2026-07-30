# Builds a portable Windows ZIP: EXE + Flutter runtime next to it.
# Also refreshes dist/SLST-Windows-Portable/ so launches aren't stale vs ZIP-only.
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $root
. (Join-Path $PSScriptRoot '_common.ps1')

Invoke-SlstFlutter -Arguments @('pub', 'get')
Invoke-SlstFlutter -Arguments @('build', 'windows', '--release')

$release = Join-Path $root 'build\windows\x64\runner\Release'
$exe = Join-Path $release 'slst.exe'
if (-not (Test-Path $exe)) {
  throw "Windows release EXE missing: $exe"
}

$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$stage = Join-Path $dist '.SLST-windows-portable-stage'
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force -Path $stage | Out-Null
Copy-Item -Recurse -Force (Join-Path $release '*') $stage

$zip = Join-Path $dist 'SLST-Windows-Portable.zip'
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip
Write-SlstSha256 -Path $zip

# Keep extracted portable folder in sync with Release (ZIP alone left this stale).
$portable = Join-Path $dist 'SLST-Windows-Portable'
if (Test-Path $portable) { Remove-Item -Recurse -Force $portable }
New-Item -ItemType Directory -Force -Path $portable | Out-Null
Copy-Item -Recurse -Force (Join-Path $stage '*') $portable

Remove-Item -Recurse -Force $stage
Write-Host "Wrote $zip"
Write-Host "Synced $portable"
