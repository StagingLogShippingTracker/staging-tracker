# Builds an Android APK. Uses release signing when android/key.properties exists; otherwise debug APK.
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $root
. (Join-Path $PSScriptRoot '_common.ps1')

Invoke-SlstFlutter -Arguments @('pub', 'get')

$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
Invoke-SlstFlutter -Arguments @('build', 'apk', '--release')
$apk = Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk'
$output = Join-Path $dist 'SLST-Android.apk'
Copy-Item -Force $apk $output
Write-SlstSha256 -Path $output
Write-Host "Wrote dist\SLST-Android.apk"
