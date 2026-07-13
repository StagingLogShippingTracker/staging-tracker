#Requires -Version 5.1
<#
.SYNOPSIS
  Register a Windows Scheduled Task to sync Prophet21 data to Supabase every 10 minutes.

.NOTES
  Run once on an always-on Swift-network PC as the user who owns scripts/p21-proxy/.env
#>
param(
  [int]$IntervalMinutes = 10,
  [string]$TaskName = 'SLST-P21-Sync'
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$proxyScript = Join-Path $here 'start-proxy.ps1'
$syncScript = Join-Path $here 'sync-to-supabase.ps1'
$proxyStarter = Join-Path $here 'ensure-proxy-running.ps1'

@'
# Ensures local P21 proxy is listening before sync runs
$port = 8787
try {
  $null = Invoke-WebRequest -Uri "http://127.0.0.1:$port/health" -TimeoutSec 3 -UseBasicParsing
  exit 0
} catch {}
Start-Process powershell -WindowStyle Hidden -ArgumentList @(
  '-NoProfile','-ExecutionPolicy','Bypass','-File', (Join-Path $PSScriptRoot 'start-proxy.ps1')
) | Out-Null
Start-Sleep -Seconds 4
'@ | Set-Content -Path $proxyStarter -Encoding UTF8

$runner = Join-Path $here 'run-p21-sync-cycle.ps1'
@(
  "#Requires -Version 5.1",
  "& '$proxyStarter'",
  "& '$syncScript'"
) | Set-Content -Path $runner -Encoding UTF8

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$runner`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) -RepetitionDuration ([TimeSpan]::MaxValue)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
Write-Host "Registered scheduled task '$TaskName' every $IntervalMinutes minutes."
Write-Host "Runner: $runner"
