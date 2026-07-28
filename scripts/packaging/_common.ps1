Set-StrictMode -Version Latest

$script:SlstRepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$script:SlstFlutter = Join-Path $script:SlstRepoRoot '.tools\flutter\bin\flutter.bat'
if (-not (Test-Path $script:SlstFlutter)) {
  $script:SlstFlutter = 'flutter'
}

function Invoke-SlstFlutter {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
  )

  & $script:SlstFlutter @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "flutter $($Arguments -join ' ') failed (exit $LASTEXITCODE)."
  }
}

function Write-SlstSha256 {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $hash = (Get-FileHash -Algorithm SHA256 -Path $Path).Hash.ToLowerInvariant()
  $checksumPath = "$Path.sha256"
  Set-Content -Path $checksumPath -Value "$hash *$([System.IO.Path]::GetFileName($Path))" -NoNewline
  Write-Host "Wrote $checksumPath"
}
