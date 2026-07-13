# Enable branch protection on main (requires: gh auth login)
#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$owner = 'StagingLogShippingTracker'
$repo = 'staging-tracker'
$branch = 'main'

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  throw 'GitHub CLI (gh) is not installed. Run: winget install GitHub.cli'
}

gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
  Write-Host 'Not logged in to GitHub. Run: gh auth login'
  exit 1
}

Write-Host "Protecting $owner/$repo branch '$branch'..."

$body = @'
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": false,
  "lock_branch": false,
  "allow_fork_syncing": true
}
'@

$tmp = [System.IO.Path]::GetTempFileName()
try {
  [System.IO.File]::WriteAllText($tmp, $body, [System.Text.UTF8Encoding]::new($false))
  gh api "repos/$owner/$repo/branches/$branch/protection" --method PUT --input $tmp
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  Write-Host 'Branch protection enabled on main.'
} finally {
  Remove-Item $tmp -Force -ErrorAction SilentlyContinue
}
