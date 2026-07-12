# Git wrapper — uses portable MinGit in .tools if system git is unavailable
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$GitArgs
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Get-GitExe {
  $cmd = Get-Command git -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $portable = Join-Path $repoRoot '.tools\MinGit\cmd\git.exe'
  if (Test-Path $portable) { return $portable }
  throw 'Git not found. Install Git for Windows or ensure .tools/MinGit exists.'
}

Set-Location $repoRoot
& (Get-GitExe) @GitArgs
exit $LASTEXITCODE
