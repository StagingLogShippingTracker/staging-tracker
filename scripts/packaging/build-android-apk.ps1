# Builds an Android APK. Uses release signing when android/key.properties exists; otherwise debug APK.
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $root

$flutter = Join-Path $root '.tools\flutter\bin\flutter.bat'
if (-not (Test-Path $flutter)) { $flutter = 'flutter' }

& $flutter pub get

$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
& $flutter build apk --release
$apk = Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk'
Copy-Item -Force $apk (Join-Path $dist 'SLST-Android.apk')
Write-Host "Wrote dist\SLST-Android.apk"
