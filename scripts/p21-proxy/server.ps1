# Prophet21 local proxy for SLST (PowerShell — no Node required)
# Usage: Connect Swift VPN, then run:
#   powershell -ExecutionPolicy Bypass -File scripts/p21-proxy/server.ps1

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$envFile = Join-Path $here '.env'

function Load-DotEnv($path) {
  if (-not (Test-Path $path)) { return @{} }
  $map = @{}
  Get-Content $path | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith('#')) { return }
    $idx = $line.IndexOf('=')
    if ($idx -lt 1) { return }
    $map[$line.Substring(0, $idx).Trim()] = $line.Substring($idx + 1).Trim().Trim('"').Trim("'")
  }
  return $map
}

$cfg = Load-DotEnv $envFile
$BaseUrl = if ($cfg['P21_BASE_URL']) { $cfg['P21_BASE_URL'] } else { 'https://swiftsupply.epicordistribution.com' }
$BaseUrl = $BaseUrl.TrimEnd('/')
$Username = $cfg['P21_USERNAME']
$Password = $cfg['P21_PASSWORD']
$Port = if ($cfg['P21_PROXY_PORT']) { [int]$cfg['P21_PROXY_PORT'] } else { 8787 }
$script:Token = $null
$script:TokenExpires = [datetime]::MinValue

function Write-Json($res, [int]$code, $obj) {
  $bytes = [Text.Encoding]::UTF8.GetBytes(($obj | ConvertTo-Json -Depth 8 -Compress))
  $res.StatusCode = $code
  $res.ContentType = 'application/json; charset=utf-8'
  $res.Headers.Add('Access-Control-Allow-Origin', '*')
  $res.OutputStream.Write($bytes, 0, $bytes.Length)
  $res.Close()
}

function Normalize-So($raw) {
  $s = [string]$raw
  $s = $s.Trim()
  if ($s -match '^SO[#:\s-]*(.*)$') { return $matches[1].Trim() }
  return $s
}

function Get-P21Token {
  if ($script:Token -and (Get-Date) -lt $script:TokenExpires.AddMinutes(-1)) {
    return $script:Token
  }
  if (-not $Username -or -not $Password) {
    throw [System.InvalidOperationException]::new('P21 credentials missing in scripts/p21-proxy/.env')
  }
  $body = @{ username = $Username; password = $Password } | ConvertTo-Json
  $resp = Invoke-RestMethod -Uri "$BaseUrl/api/security/token/v2" -Method Post -ContentType 'application/json' -Headers @{ Accept = 'application/json' } -Body $body -TimeoutSec 45
  if (-not $resp.AccessToken) { throw [System.InvalidOperationException]::new('P21 token response missing AccessToken') }
  $script:Token = $resp.AccessToken
  $ttl = if ($resp.ExpiresInSeconds) { [int]$resp.ExpiresInSeconds } else { 3600 }
  $script:TokenExpires = (Get-Date).AddSeconds($ttl)
  return $script:Token
}

function Invoke-OData($token, $resourceType, $resourceName, $filter, [int]$top = 25) {
  $qs = "?`$top=$top"
  if ($filter) { $qs += "&`$filter=$([uri]::EscapeDataString($filter))" }
  $uri = "$BaseUrl/odataservice/odata/$resourceType/$resourceName$qs"
  $headers = @{ Authorization = "Bearer $token"; Accept = 'application/json' }
  $resp = Invoke-RestMethod -Uri $uri -Headers $headers -TimeoutSec 45
  if ($resp.value) { return @($resp.value) }
  if ($resp.d.results) { return @($resp.d.results) }
  return @()
}

function Pick-First($row, [string[]]$keys) {
  foreach ($k in $keys) {
    if ($null -ne $row.$k -and "$($row.$k)" -ne '') { return $row.$k }
  }
  return $null
}

function Find-OrderHeader($token, $so) {
  $esc = $so.Replace("'", "''")
  $views = @('p21_view_oe_hdr', 'oe_hdr')
  $filters = @("order_no eq '$esc'", "po_no eq '$esc'", "customer_po_no eq '$esc'")
  if ($so -match '^\d+$') { $filters = @("order_no eq $so") + $filters }
  foreach ($view in $views) {
    foreach ($filter in $filters) {
      try {
        $rows = Invoke-OData $token 'view' $view $filter 5
        if ($rows.Count -gt 0) { return @{ row = $rows[0]; view = $view; matchedBy = ($filter -split ' ')[0] } }
      } catch {
        if ($_.Exception.Message -notmatch '404|not found') { throw }
      }
    }
  }
  return $null
}

function Find-OrderLines($token, $orderNo) {
  if ($null -eq $orderNo -or "$orderNo" -eq '') { return @() }
  $esc = "$orderNo".Replace("'", "''")
  $views = @('p21_view_oe_line', 'p21_view_oe_detail', 'oe_line')
  $filters = @("order_no eq '$esc'")
  if ("$orderNo" -match '^\d+$') { $filters = @("order_no eq $orderNo") + $filters }
  foreach ($view in $views) {
    foreach ($filter in $filters) {
      try {
        $rows = Invoke-OData $token 'view' $view $filter 100
        if ($rows.Count -gt 0) { return $rows }
      } catch {
        if ($_.Exception.Message -notmatch '404|not found') { throw }
      }
    }
  }
  return @()
}

function Get-OrderInsights($soRaw) {
  $so = Normalize-So $soRaw
  if (-not $so) { throw [System.ArgumentException]::new('SO required') }
  $token = Get-P21Token
  $hit = Find-OrderHeader $token $so
  if (-not $hit) {
    return @{ so = $so; found = $false; message = "No Prophet21 order found for SO $so." }
  }
  $row = $hit.row
  $header = @{
    orderNo = Pick-First $row @('order_no','OrderNo')
    customerId = Pick-First $row @('customer_id','CustomerId')
    customerName = Pick-First $row @('customer_name','CustomerName','ship_to_name','ShipToName')
    poNo = Pick-First $row @('po_no','PoNo','customer_po_no','CustomerPoNo')
    orderDate = Pick-First $row @('order_date','OrderDate','date_created','DateCreated')
    status = Pick-First $row @('order_status','OrderStatus','status','Status')
    shipTo = Pick-First $row @('ship_to_name','ShipToName')
    shipVia = Pick-First $row @('ship_via','ShipVia','carrier_id')
    warehouse = Pick-First $row @('source_loc_id','SourceLocId','location_id','LocationId')
  }
  $orderNo = if ($header.orderNo) { $header.orderNo } else { $so }
  $lineRows = Find-OrderLines $token $orderNo
  $lines = @()
  foreach ($line in $lineRows) {
    $lines += @{
      lineNo = Pick-First $line @('line_no','LineNo')
      itemId = Pick-First $line @('item_id','ItemId')
      description = Pick-First $line @('item_desc','ItemDesc','extended_desc','ExtendedDesc','description')
      qtyOrdered = Pick-First $line @('qty_ordered','QtyOrdered','unit_quantity','UnitQuantity')
      qtyShipped = Pick-First $line @('qty_shipped','QtyShipped')
      uom = Pick-First $line @('unit_of_measure','UnitOfMeasure','sales_uom')
      requiredDate = Pick-First $line @('required_date','RequiredDate','promise_date','PromiseDate')
    }
  }
  $totalQty = 0
  foreach ($l in $lines) {
    $q = if ($l.qtyOrdered) { [double]$l.qtyOrdered } else { 0 }
    $totalQty += $q
  }
  return @{
    so = $so
    found = $true
    matchedBy = $hit.matchedBy
    sourceView = $hit.view
    header = $header
    lines = $lines
    summary = @{
      customer = if ($header.customerName) { $header.customerName } elseif ($header.customerId) { $header.customerId } else { '—' }
      orderDate = if ($header.orderDate) { $header.orderDate } else { '—' }
      status = if ($header.status) { $header.status } else { '—' }
      poNo = if ($header.poNo) { $header.poNo } else { '—' }
      lineCount = $lines.Count
      totalQtyOrdered = $totalQty
    }
  }
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Start()
Write-Host "P21 proxy listening on http://127.0.0.1:$Port/"
Write-Host "Target: $BaseUrl"
Write-Host "Connect Swift VPN if P21 requests fail."

while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $req = $ctx.Request
  $res = $ctx.Response
  try {
    if ($req.HttpMethod -eq 'OPTIONS') {
      $res.StatusCode = 204
      $res.Headers.Add('Access-Control-Allow-Origin', '*')
      $res.Headers.Add('Access-Control-Allow-Methods', 'GET,OPTIONS')
      $res.Headers.Add('Access-Control-Allow-Headers', 'Content-Type')
      $res.Close()
      continue
    }
    $path = $req.Url.AbsolutePath
    if ($path -eq '/health') {
      Write-Json $res 200 @{ ok = $true; p21BaseUrl = $BaseUrl; credentialsConfigured = [bool]($Username -and $Password) }
      continue
    }
    if ($path -match '^/api/order/(.+)$') {
      $so = [uri]::UnescapeDataString($matches[1])
      $data = Get-OrderInsights $so
      $code = if ($data.found) { 200 } else { 404 }
      Write-Json $res $code $data
      continue
    }
    Write-Json $res 404 @{ error = 'NOT_FOUND' }
  } catch {
    $msg = $_.Exception.Message
    $code = 502
    if ($msg -match 'credentials missing') { $code = 503 }
    if ($msg -match '401|403|authentication|token') { $code = 401 }
    Write-Json $res $code @{ found = $false; error = 'ERROR'; message = $msg }
  }
}
