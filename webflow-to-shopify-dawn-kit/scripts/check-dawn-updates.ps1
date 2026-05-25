# PowerShell equivalent of check-dawn-updates.sh -- for Windows users.
#
# Reports whether a newer Dawn release exists than the version pinned in
# pull-dawn.ps1.
#
# Usage (from project root):
#   pwsh webflow-to-shopify-dawn-kit/scripts/check-dawn-updates.ps1
#
# Exit codes:
#   0 -- pinned version is current
#   1 -- newer release available
#   2 -- couldn't reach GitHub or parse response

$ErrorActionPreference = "Stop"

# IMPORTANT: keep this in sync with $DawnTag in pull-dawn.ps1
$DawnTag = "v15.3.0"
$DawnRepo = "Shopify/dawn"
$ApiUrl = "https://api.github.com/repos/$DawnRepo/releases/latest"

Write-Host "Checking $DawnRepo for newer Dawn releases ..."
Write-Host "  pinned: $DawnTag"

try {
    $resp = Invoke-RestMethod -Uri $ApiUrl -Headers @{ "User-Agent" = "dawn-update-check" } -ErrorAction Stop
} catch {
    Write-Host "ERROR: couldn't reach GitHub API: $_" -ForegroundColor Red
    if ($_.Exception.Response -and $_.Exception.Response.StatusCode.value__ -eq 403) {
        Write-Host "  (likely rate-limited -- anonymous GitHub API allows ~60 req/hour per IP)" -ForegroundColor Yellow
    }
    exit 2
}

$latest = $resp.tag_name
if (-not $latest) {
    Write-Host "ERROR: couldn't parse tag_name from API response." -ForegroundColor Red
    exit 2
}

Write-Host "  latest: $latest"
Write-Host ""

if ($DawnTag -eq $latest) {
    Write-Host "OK Pinned version is current." -ForegroundColor Green
    exit 0
}

Write-Host "WARN A newer Dawn release is available: $latest" -ForegroundColor Yellow
Write-Host ""
Write-Host "To bump:"
Write-Host "  1. Review the changelog: https://github.com/$DawnRepo/releases"
Write-Host "  2. Edit `$DawnTag in pull-dawn.ps1 AND check-dawn-updates.ps1"
Write-Host "     (and pull-dawn.sh / check-dawn-updates.sh if you support Unix)"
Write-Host "  3. Delete dawn-source/ and re-run:"
Write-Host "       pwsh webflow-to-shopify-dawn-kit/scripts/pull-dawn.ps1"
Write-Host "       pwsh webflow-to-shopify-dawn-kit/scripts/merge-dawn-commerce.ps1"
Write-Host "  4. Re-test commerce pages -- Dawn ships breaking changes regularly."
exit 1
