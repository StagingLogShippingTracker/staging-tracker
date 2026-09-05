Set-StrictMode -Version Latest

$script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$script:RepoFlutter = Join-Path $script:RepoRoot '.tools\flutter\bin\flutter.bat'
if (-not (Test-Path $script:RepoFlutter)) {
  $script:RepoFlutter = 'flutter'
}

function Invoke-RepoFlutter {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
  )

  & $script:RepoFlutter @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "flutter $($Arguments -join ' ') failed (exit $LASTEXITCODE)."
  }
}

function Get-RepoVersion {
  $pubspec = Join-Path $script:RepoRoot 'pubspec.yaml'
  $line = Select-String -Path $pubspec -Pattern '^version:\s*(\S+)' | Select-Object -First 1
  if (-not $line) {
    throw "Could not find a version: line in $pubspec"
  }
  $full = $line.Matches[0].Groups[1].Value
  return $full.Split('+')[0]
}

function Write-RepoSha256 {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $hash = (Get-FileHash -Algorithm SHA256 -Path $Path).Hash.ToLowerInvariant()
  $checksumPath = "$Path.sha256"
  Set-Content -Path $checksumPath -Value "$hash *$([System.IO.Path]::GetFileName($Path))" -NoNewline
  Write-Host "Wrote $checksumPath"
}
