#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
# This script lives in scripts/p21-proxy/package → root is 3 levels up
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
Set-Location $root
$gitCmd = Join-Path $root '.tools\MinGit\cmd'
$env:Path = "$gitCmd;$env:Path"
gh release create p21-swift-connector-v1 `
  'packages/SLST-P21-Swift-Connector.zip' `
  --title 'P21 Swift PC Connector v1' `
  --notes 'Portable Prophet21 proxy for warehouse PCs on Swift WiFi. Unzip, edit .env with P21 credentials, run Start-P21-Connector.exe. See SETUP.txt inside the zip.'
