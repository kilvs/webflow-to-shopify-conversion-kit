# PowerShell equivalent of merge-dawn-commerce.sh -- for Windows users.
#
# See merge-dawn-commerce.sh for full whitelist + behavior documentation.
#
# Usage (from project root, after pull-dawn.ps1):
#   pwsh webflow-to-shopify-dawn-kit/scripts/merge-dawn-commerce.ps1

param([string]$DawnDir = "dawn-source")

$ErrorActionPreference = "Stop"
$KitDir = "webflow-to-shopify-dawn-kit"

if (-not (Test-Path $DawnDir -PathType Container)) {
    Write-Error "$DawnDir/ not found. Run pull-dawn.ps1 first."
    exit 1
}
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Error "node is required (used to wrap Dawn CSS in @layer dawn)."
    exit 1
}

New-Item -ItemType Directory -Path "sections", "snippets", "assets", "templates/customers", "locales" -Force | Out-Null

Write-Host ""
Write-Host "> Templates"
Write-Host "----------------------------------------------"
$CommerceTemplates = @(
    "product.json", "collection.json", "cart.json", "search.json",
    "list-collections.json", "gift_card.liquid"
)
foreach ($t in $CommerceTemplates) {
    $src = "$DawnDir/templates/$t"
    if (Test-Path $src) {
        Copy-Item $src "templates/$t" -Force
        Write-Host "  templates/$t"
    } else {
        Write-Warning "$src not in this Dawn version -- skipped"
    }
}

Write-Host ""
Write-Host "> Customer templates"
Write-Host "----------------------------------------------"
if (Test-Path "$DawnDir/templates/customers") {
    foreach ($f in Get-ChildItem "$DawnDir/templates/customers" -File) {
        Copy-Item $f.FullName "templates/customers/$($f.Name)" -Force
        Write-Host "  templates/customers/$($f.Name)"
    }
} else {
    Write-Warning "no templates/customers/ in Dawn -- skipped"
}

Write-Host ""
Write-Host "> Sections (commerce-only whitelist)"
Write-Host "----------------------------------------------"
$CommerceSectionPatterns = @(
    "main-product*.liquid",
    "related-products.liquid",
    "main-collection-*.liquid",
    "main-list-collections.liquid",
    "main-search.liquid",
    "main-cart-*.liquid",
    "cart-drawer.liquid",
    "cart-notification.liquid",
    "predictive-search.liquid",
    "main-account.liquid",
    "main-login.liquid",
    "main-register.liquid",
    "main-addresses.liquid",
    "main-order.liquid",
    "main-reset-password.liquid",
    "main-activate-account.liquid"
)
$sectionCount = 0
foreach ($pat in $CommerceSectionPatterns) {
    foreach ($src in Get-ChildItem "$DawnDir/sections" -Filter $pat -File -ErrorAction SilentlyContinue) {
        Copy-Item $src.FullName "sections/$($src.Name)" -Force
        Write-Host "  sections/$($src.Name)"
        $sectionCount++
    }
}
Write-Host "  ($sectionCount sections copied)"

Write-Host ""
Write-Host "> Snippets (all except header/footer-related)"
Write-Host "----------------------------------------------"
$SkipSnippets = @(
    "header-search.liquid",
    "mega-menu.liquid",
    "list-menu.liquid",
    "header-drawer.liquid"
)
$snipCopied = 0
$snipSkipped = 0
foreach ($src in Get-ChildItem "$DawnDir/snippets" -Filter "*.liquid" -File) {
    if ($SkipSnippets -contains $src.Name) {
        $snipSkipped++
    } else {
        Copy-Item $src.FullName "snippets/$($src.Name)" -Force
        $snipCopied++
    }
}
Write-Host "  $snipCopied copied, $snipSkipped skipped (Webflow-owned)"

Write-Host ""
Write-Host "> Assets (collision check)"
Write-Host "----------------------------------------------"
$collisions = @()
foreach ($src in Get-ChildItem "$DawnDir/assets" -File) {
    if (Test-Path "assets/$($src.Name)") {
        $collisions += $src.Name
    }
}
if ($collisions.Count -gt 0) {
    Write-Host "ERROR: $($collisions.Count) Dawn asset(s) would overwrite existing files in assets/:" -ForegroundColor Red
    $collisions | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    Write-Host ""
    Write-Host "Resolve manually: rename or remove the conflicting file in assets/, then re-run." -ForegroundColor Yellow
    exit 1
}

$assetCopied = 0
foreach ($src in Get-ChildItem "$DawnDir/assets" -File) {
    Copy-Item $src.FullName "assets/$($src.Name)" -Force
    $assetCopied++
}
Write-Host "  $assetCopied Dawn assets copied"

Write-Host ""
Write-Host "> Wrap Dawn CSS in @layer dawn"
Write-Host "----------------------------------------------"
& node "$KitDir/scripts/wrap-css-layers.cjs" assets dawn
if ($LASTEXITCODE -ne 0) {
    Write-Error "wrap-css-layers.cjs failed."
    exit 1
}

Write-Host ""
Write-Host "> Locales"
Write-Host "----------------------------------------------"
if (Test-Path "locales/en.default.json") {
    Write-Host "  locales/en.default.json already exists -- skipped"
    Write-Host "  (you'll need to merge Dawn's commerce strings manually -- see DAWN_INTEGRATION.md)"
} else {
    Copy-Item "$DawnDir/locales/en.default.json" "locales/en.default.json" -Force
    Write-Host "  locales/en.default.json (Dawn defaults)"
}

Write-Host ""
Write-Host "OK Dawn commerce merged into theme." -ForegroundColor Green
Write-Host "  Next: configure layout/theme.liquid (Phase 4) to declare"
Write-Host "       <style>@layer dawn, webflow;</style> and load both bundles."
