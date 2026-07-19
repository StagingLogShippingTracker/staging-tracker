# Builds an Android APK. Uses release signing when android/key.properties exists; otherwise debug APK.
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $root

$flutter = Join-Path $root '.tools\flutter\bin\flutter.bat'
if (-not (Test-Path $flutter)) { $flutter = 'flutter' }

& $flutter pub get

$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$keyProps = Join-Path $root 'android\key.properties'

if (Test-Path $keyProps) {
  & $flutter build apk --release
  $apk = Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk'
  Copy-Item -Force $apk (Join-Path $dist 'slst-release.apk')
  Write-Host "Wrote dist\slst-release.apk (signed release)"
} else {
  Write-Warning 'android/key.properties missing — building debug APK for sideload testing.'
  & $flutter build apk --debug
  $apk = Join-Path $root 'build\app\outputs\flutter-apk\app-debug.apk'
  Copy-Item -Force $apk (Join-Path $dist 'slst-debug.apk')
  Write-Host "Wrote dist\slst-debug.apk"
}
