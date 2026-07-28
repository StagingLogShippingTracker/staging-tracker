# Builds a portable Windows ZIP: EXE + Flutter runtime next to it.
# Also refreshes dist/SST-Windows-Portable/ so launches aren't stale vs ZIP-only.
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $root

$flutter = Join-Path $root '.tools\flutter\bin\flutter.bat'
if (-not (Test-Path $flutter)) { $flutter = 'flutter' }

& $flutter pub get
& $flutter build windows --release
if ($LASTEXITCODE -ne 0) {
  throw "flutter build windows --release failed (exit $LASTEXITCODE). Close any running slst.exe and retry."
}

$release = Join-Path $root 'build\windows\x64\runner\Release'
$exe = Join-Path $release 'slst.exe'
if (-not (Test-Path $exe)) {
  throw "Windows release EXE missing: $exe"
}

$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$stage = Join-Path $dist '.sst-windows-portable-stage'
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force -Path $stage | Out-Null
Copy-Item -Recurse -Force (Join-Path $release '*') $stage

$zip = Join-Path $dist 'SST-Windows-Portable.zip'
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip

# Keep extracted portable folder in sync with Release (ZIP alone left this stale).
$portable = Join-Path $dist 'SST-Windows-Portable'
if (Test-Path $portable) { Remove-Item -Recurse -Force $portable }
New-Item -ItemType Directory -Force -Path $portable | Out-Null
Copy-Item -Recurse -Force (Join-Path $stage '*') $portable

Remove-Item -Recurse -Force $stage
Write-Host "Wrote $zip"
Write-Host "Synced $portable"
