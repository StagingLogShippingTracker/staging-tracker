# Builds the Wear OS APK from apps/slst_wear into dist/SLST-Wear.apk.
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$wear = Join-Path $root 'apps\slst_wear'
Set-Location $wear
. (Join-Path $PSScriptRoot '_common.ps1')

Invoke-SlstFlutter -Arguments @('pub', 'get')
Invoke-SlstFlutter -Arguments @('build', 'apk', '--release')

$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$apk = Join-Path $wear 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $apk)) {
    # Flutter may nest build under apps/slst_wear/build or redirect via android buildDir.
    $alt = Join-Path $wear 'build\app\outputs\flutter-apk\app-release.apk'
    $apk = $alt
}
if (-not (Test-Path $apk)) {
    throw "Wear APK not found after build. Expected under apps/slst_wear/build/app/outputs/flutter-apk/"
}
$output = Join-Path $dist 'SLST-Wear.apk'
Copy-Item -Force $apk $output
Write-SlstSha256 -Path $output
Write-Host "Wrote dist\SLST-Wear.apk"
