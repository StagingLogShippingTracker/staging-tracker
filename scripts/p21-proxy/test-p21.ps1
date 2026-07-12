#Requires -Version 5.1
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$cfg = @{}
Get-Content (Join-Path $here '.env') | ForEach-Object {
  if ($_ -match '^([^#=]+)=(.*)$') { $cfg[$matches[1].Trim()] = $matches[2].Trim().Trim('"').Trim("'") }
}
$base = $cfg['P21_BASE_URL'].TrimEnd('/')
$body = @{ username = $cfg['P21_USERNAME']; password = $cfg['P21_PASSWORD'] } | ConvertTo-Json
try {
  $tok = Invoke-RestMethod -Uri "$base/api/security/token/v2" -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 45
  Write-Output "TOKEN_OK=$([bool]$tok.AccessToken)"
  $h = @{ Authorization = "Bearer $($tok.AccessToken)"; Accept = 'application/json' }
  $views = @('p21_view_oe_hdr', 'oe_hdr')
  foreach ($view in $views) {
    $uri = "$base/odataservice/odata/view/$view" + '?$top=1&$filter=' + [uri]::EscapeDataString('order_no eq 1399020')
    try {
      $r = Invoke-WebRequest -Uri $uri -Headers $h -TimeoutSec 45 -UseBasicParsing
      Write-Output "VIEW_${view}_STATUS=$($r.StatusCode)"
    } catch {
      Write-Output "VIEW_${view}_ERR=$($_.Exception.Message)"
    }
  }
} catch {
  Write-Output "TOKEN_ERR=$($_.Exception.Message)"
}
