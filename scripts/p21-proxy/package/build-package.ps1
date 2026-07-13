#Requires -Version 5.1
<#
.SYNOPSIS
  Build the Slack-PC portable zip + Start-P21-Connector.exe
#>
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$proxy = Join-Path $root 'scripts\p21-proxy'
$pkgSrc = Join-Path $proxy 'package'
$outDir = Join-Path $root 'packages\SLST-P21-Swift-Connector'
$zipPath = Join-Path $root 'packages\SLST-P21-Swift-Connector.zip'
$csc = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'

if (Test-Path $outDir) { Remove-Item $outDir -Recurse -Force }
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

$copyFiles = @(
  'start-proxy.ps1',
  'server.ps1',
  'server.mjs',
  'p21-core.mjs',
  'test-p21.ps1',
  'discover-p21-endpoints.ps1',
  'sync-to-supabase.ps1',
  'install-p21-sync-task.ps1',
  '.env.example'
)
foreach ($f in $copyFiles) {
  $src = Join-Path $proxy $f
  if (Test-Path $src) {
    Copy-Item $src (Join-Path $outDir $f) -Force
  }
}

Copy-Item (Join-Path $pkgSrc 'SETUP.txt') (Join-Path $outDir 'SETUP.txt') -Force
Copy-Item (Join-Path $pkgSrc 'Start-P21-Connector.bat') (Join-Path $outDir 'Start-P21-Connector.bat') -Force

# Package .env.example with public Supabase anon key pre-filled (not a secret)
$anon = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmVzZSIsInJlZiI6ImdkcnBkaXd5a21ueWJta2FkbHJ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA1MjMyMTIsImV4cCI6MjA5NjA5OTIxMn0.Z7ih_vQic1GtzCyZmTEV-RWJnmuaNZQDfOV2_Fvan5g'
# Fix: use exact anon from config - I may have typo'd "esZS" vs "eZS"
$anon = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdkcnBkaXd5a21ueWJta2FkbHJ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA1MjMyMTIsImV4cCI6MjA5NjA5OTIxMn0.Z7ih_vQic1GtzCyZmTEV-RWJnmuaNZQDfOV2_Fvan5g'

@(
  '# Fill P21_USERNAME and P21_PASSWORD, then save as .env (or run Start-P21-Connector.exe)',
  'P21_BASE_URL=https://swiftsupply.epicordistribution.com',
  'P21_USERNAME=your.p21.username',
  'P21_PASSWORD=your_p21_password',
  'P21_PROXY_PORT=8787',
  'P21_TLS_REJECT_UNAUTHORIZED=1',
  '',
  'SUPABASE_URL=https://gdrpdiwykmnybmkadlrv.supabase.co',
  "SUPABASE_ANON_KEY=$anon",
  'P21_SYNC_KEY=change_me_only_needed_for_bulk_sync'
) | Set-Content -Encoding UTF8 (Join-Path $outDir '.env.example')

# Build EXE
$exe = Join-Path $outDir 'Start-P21-Connector.exe'
$cs = Join-Path $pkgSrc 'StartP21Connector.cs'
& $csc /nologo /target:winexe /r:System.Windows.Forms.dll /out:$exe $cs
if ($LASTEXITCODE -ne 0) { throw "csc failed with $LASTEXITCODE" }

if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $outDir '*') -DestinationPath $zipPath -Force

# Also zip the folder itself as a clean named root for unzip UX
$staging = Join-Path $root 'packages\_zip_staging'
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
New-Item -ItemType Directory -Path (Join-Path $staging 'SLST-P21-Swift-Connector') -Force | Out-Null
Copy-Item (Join-Path $outDir '*') (Join-Path $staging 'SLST-P21-Swift-Connector') -Force
Remove-Item $zipPath -Force
Compress-Archive -Path (Join-Path $staging 'SLST-P21-Swift-Connector') -DestinationPath $zipPath -Force
Remove-Item $staging -Recurse -Force

Write-Host "EXE: $exe"
Write-Host "ZIP: $zipPath"
Write-Host "ZIP_BYTES=$((Get-Item $zipPath).Length)"
