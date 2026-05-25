# PowerShell equivalent of pull-dawn.sh -- for Windows users.
#
# Clones Shopify/dawn at the pinned tag into dawn-source/. Idempotent.
#
# Usage (from project root):
#   pwsh webflow-to-shopify-dawn-kit/scripts/pull-dawn.ps1
#
# To bump the pin, edit $DawnTag below and re-run.

param([string]$DawnDir = "dawn-source")

$ErrorActionPreference = "Stop"

# Pinned Dawn version. Bump deliberately -- merge whitelist may need updates.
$DawnTag = "v15.3.0"
$DawnRepo = "https://github.com/Shopify/dawn.git"

if (Test-Path "$DawnDir/.git") {
    Push-Location $DawnDir
    try {
        $current = (git describe --tags --exact-match 2>$null)
    } catch { $current = "" }
    Pop-Location
    if ($current -eq $DawnTag) {
        Write-Host "OK $DawnDir/ already at $DawnTag -- nothing to do" -ForegroundColor Green
        exit 0
    }
    Write-Error "$DawnDir/ exists but is at '$current' (expected $DawnTag). Delete and re-run, or edit `$DawnTag to match."
    exit 1
}

if (Test-Path $DawnDir) {
    Write-Error "$DawnDir/ exists but is not a git checkout. Move or delete it first."
    exit 1
}

Write-Host "Cloning Shopify/dawn @ $DawnTag into $DawnDir/ ..."
git clone --depth=1 --branch=$DawnTag $DawnRepo $DawnDir
if ($LASTEXITCODE -ne 0) {
    Write-Error "git clone failed."
    exit 1
}

Push-Location $DawnDir
$sha = (git rev-parse --short HEAD)
Pop-Location

Write-Host ""
Write-Host "OK Dawn pulled to $DawnDir/ (commit: $sha)" -ForegroundColor Green
Write-Host "  Next: pwsh webflow-to-shopify-dawn-kit/scripts/merge-dawn-commerce.ps1"
