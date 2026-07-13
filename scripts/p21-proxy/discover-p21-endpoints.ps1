#Requires -Version 5.1
<#
.SYNOPSIS
  Diagnose Prophet21 API reachability from the current network.

.DESCRIPTION
  Checks token auth, OData, Transaction API, and Inventory API paths.
  Requires scripts/p21-proxy/.env with P21 credentials.
#>
$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$cfg = @{}
Get-Content (Join-Path $here '.env') | ForEach-Object {
  if ($_ -match '^([^#=]+)=(.*)$') { $cfg[$matches[1].Trim()] = $matches[2].Trim().Trim('"').Trim("'") }
}
$base = $cfg['P21_BASE_URL'].TrimEnd('/')
$body = @{ username = $cfg['P21_USERNAME']; password = $cfg['P21_PASSWORD'] } | ConvertTo-Json

Write-Host "P21 base: $base"
try {
  $tok = Invoke-RestMethod -Uri "$base/api/security/token/v2" -Method Post -ContentType 'application/json' -Headers @{ Accept = 'application/json' } -Body $body -TimeoutSec 45
  Write-Host "[OK] Token endpoint"
} catch {
  Write-Host "[FAIL] Token endpoint: $($_.Exception.Message)"
  exit 1
}

$h = @{ Authorization = "Bearer $($tok.AccessToken)"; Accept = 'application/json' }
$checks = @(
  @{ label = 'OData supplier table'; uri = "$base/odataservice/odata/table/supplier?`$top=1" },
  @{ label = 'OData oe_hdr view'; uri = "$base/odataservice/odata/view/p21_view_oe_hdr?`$top=1" },
  @{ label = 'Transaction API'; uri = "$base/api/v2/definition/Order" },
  @{ label = 'Inventory API'; uri = "$base/api/inventory/parts?`$top=1" }
)
foreach ($c in $checks) {
  try {
    $r = Invoke-WebRequest -Uri $c.uri -Headers $h -TimeoutSec 30 -UseBasicParsing
    Write-Host "[OK] $($c.label) ($($r.StatusCode))"
  } catch {
    $code = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 'ERR' }
    Write-Host "[FAIL] $($c.label) ($code)"
  }
}

Write-Host ''
Write-Host 'If OData/Transaction fail with 404 on Swift WiFi, connect FortiClient VPN and/or ask IT for the internal middleware URL and OData permissions.'
