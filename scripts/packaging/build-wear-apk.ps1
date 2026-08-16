# Builds the Wear OS APK from apps/wear into dist/SwiftStagingLog-Wear.apk.
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$wear = Join-Path $root 'apps\wear'
Set-Location $wear
. (Join-Path $PSScriptRoot '_common.ps1')

Invoke-RepoFlutter -Arguments @('pub', 'get')
Invoke-RepoFlutter -Arguments @('build', 'apk', '--release')

$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$apk = Join-Path $wear 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $apk)) {
    # Flutter may nest build under apps/wear/build or redirect via android buildDir.
    $alt = Join-Path $wear 'build\app\outputs\flutter-apk\app-release.apk'
    $apk = $alt
}
if (-not (Test-Path $apk)) {
    throw "Wear APK not found after build. Expected under apps/wear/build/app/outputs/flutter-apk/"
}
$output = Join-Path $dist 'SwiftStagingLog-Wear.apk'
Copy-Item -Force $apk $output
Write-RepoSha256 -Path $output
Write-Host "Wrote dist\SwiftStagingLog-Wear.apk"
