# Builds a portable Windows ZIP: EXE + Flutter runtime next to it.
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $root

$flutter = Join-Path $root '.tools\flutter\bin\flutter.bat'
if (-not (Test-Path $flutter)) { $flutter = 'flutter' }

& $flutter pub get
& $flutter build windows --release

$release = Join-Path $root 'build\windows\x64\runner\Release'
if (-not (Test-Path $release)) {
  throw "Windows release folder missing: $release"
}

$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$stage = Join-Path $dist 'slst-windows-portable'
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force -Path $stage | Out-Null
Copy-Item -Recurse -Force (Join-Path $release '*') $stage

$zip = Join-Path $dist 'slst-windows-portable.zip'
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip
Write-Host "Wrote $zip"
