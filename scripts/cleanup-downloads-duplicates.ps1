# Removes duplicate SLST project files from Downloads root after consolidating into staging-tracker.
# Safe to run multiple times — only deletes known project paths, not personal downloads.
#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$downloads = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if ((Split-Path $downloads -Leaf) -ne 'Downloads') {
  $downloads = Join-Path $env:USERPROFILE 'Downloads'
}
$repo = Join-Path $downloads 'staging-tracker'
if (-not (Test-Path $repo)) {
  throw "Expected repo at $repo"
}

$removeFiles = @(
  'app.js','auth.js','autoscan.js','batch.js','config.js','contacts.js','contacts.html','employees.js',
  'history.js','index.html','manifest.webmanifest','media.js','notifications.html','operations.js','.js',
  'partials-loader.js','reports.js','reports.html','ship.html','split.js','stage.html','style.css','ui.js',
  '.gitignore','staging-shipping-logo.png'
)
$removeDirs = @('partials','scripts','supabase','brand')

Write-Host "Removing duplicate project copies from: $downloads"
Write-Host "Canonical repo: $repo"
Write-Host ""

foreach ($item in $removeFiles) {
  $path = Join-Path $downloads $item
  if (Test-Path $path) {
    Remove-Item $path -Force -Recurse
    Write-Host "  removed file $item"
  }
}
foreach ($dir in $removeDirs) {
  $path = Join-Path $downloads $dir
  if (Test-Path $path) {
    Remove-Item $path -Recurse -Force
    Write-Host "  removed folder $dir"
  }
}

$tools = Join-Path $downloads 'tools'
if (Test-Path $tools) {
  $left = @(Get-ChildItem $tools -Force -ErrorAction SilentlyContinue)
  if ($left.Count -eq 0) {
    Remove-Item $tools -Force -Recurse
    Write-Host '  removed empty tools folder'
  }
}

Write-Host ''
Write-Host 'Done. Open and edit only: ' (Join-Path $downloads 'staging-tracker')
