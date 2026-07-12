#Requires -Version 5.1
<#
.SYNOPSIS
  Sync Prophet21 order data from Swift network into Supabase (runs on a Swift WiFi/VPN PC).

.DESCRIPTION
  1. Reads all SO numbers from staging + shipped in Supabase
  2. Fetches each order from the local P21 proxy (must be on Swift network)
  3. Pushes payloads to the p21-ingest edge function

  Schedule this every 5-15 minutes via Task Scheduler on an always-on Swift PC.

.NOTES
  Copy .env.example to .env and set P21_SYNC_KEY (match Supabase Edge Function secret).
#>
param(
  [string]$EnvFile = (Join-Path $PSScriptRoot '.env'),
  [int]$ProxyPort = 8787
)

function Load-DotEnv($path) {
  if (-not (Test-Path $path)) { throw "Missing $path" }
  Get-Content $path | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith('#')) { return }
    $eq = $line.IndexOf('=')
    if ($eq -lt 1) { return }
    $k = $line.Substring(0, $eq).Trim()
    $v = $line.Substring($eq + 1).Trim().Trim('"').Trim("'")
    Set-Item -Path "Env:$k" -Value $v
  }
}

Load-DotEnv $EnvFile

$supabaseUrl = $env:SUPABASE_URL
$anonKey = $env:SUPABASE_ANON_KEY
$syncKey = $env:P21_SYNC_KEY
if (-not $supabaseUrl -or -not $anonKey -or -not $syncKey) {
  throw 'Set SUPABASE_URL, SUPABASE_ANON_KEY, and P21_SYNC_KEY in .env'
}

$headers = @{
  apikey = $anonKey
  Authorization = "Bearer $anonKey"
  Accept = 'application/json'
}

Write-Host 'Fetching tracker SO list from Supabase...'
$staging = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/staging?select=so" -Headers $headers
$shipped = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/shipped?select=so" -Headers $headers
$sos = @($staging + $shipped | ForEach-Object { $_.so } | Where-Object { $_ } | Sort-Object -Unique)
Write-Host "Found $($sos.Count) unique SO numbers."

$payloads = @()
foreach ($so in $sos) {
  try {
    $encoded = [uri]::EscapeDataString([string]$so)
    $p21 = Invoke-RestMethod -Uri "http://127.0.0.1:$ProxyPort/api/order/$encoded" -TimeoutSec 60
    $payloads += @{ so = $so; payload = $p21; source = 'swift-sync' }
    Write-Host "  OK $so (found=$($p21.found))"
  } catch {
    Write-Warning "  FAIL $so : $($_.Exception.Message)"
  }
}

if (-not $payloads.Count) {
  Write-Host 'Nothing to sync.'
  exit 0
}

$ingestUrl = "$supabaseUrl/functions/v1/p21-ingest"
$ingestHeaders = @{
  'Content-Type' = 'application/json'
  apikey = $anonKey
  Authorization = "Bearer $anonKey"
  'x-p21-sync-key' = $syncKey
}

$body = @{ mode = 'bulk'; payloads = $payloads } | ConvertTo-Json -Depth 20 -Compress
$result = Invoke-RestMethod -Method Post -Uri $ingestUrl -Headers $ingestHeaders -Body $body -TimeoutSec 120
Write-Host "Synced $($result.synced) orders to Supabase."
