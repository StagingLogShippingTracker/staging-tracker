# Start local Prophet21 proxy for SLST (requires .env in this folder)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$envFile = Join-Path $here '.env'
if (Test-Path $envFile) {
  Get-Content $envFile | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith('#')) { return }
    $idx = $line.IndexOf('=')
    if ($idx -lt 1) { return }
    $name = $line.Substring(0, $idx).Trim()
    $value = $line.Substring($idx + 1).Trim().Trim('"').Trim("'")
    [Environment]::SetEnvironmentVariable($name, $value, 'Process')
  }
}
Write-Host 'Starting P21 proxy on http://127.0.0.1:8787 ...'
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
  node (Join-Path $here 'server.mjs')
} else {
  Write-Host 'Node not found — using PowerShell proxy.'
  & (Join-Path $here 'server.ps1')
}
