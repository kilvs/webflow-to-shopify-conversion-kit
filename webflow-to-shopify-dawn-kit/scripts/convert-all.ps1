# PowerShell equivalent of convert-all.sh -- for Windows users.
#
# Runs every fully-automatable step of the Dawn-augmented Webflow -> Shopify
# conversion. See convert-all.sh for full strategy + behavior documentation.
#
# Usage (from project root):
#   pwsh webflow-to-shopify-dawn-kit/scripts/convert-all.ps1

$ErrorActionPreference = "Stop"
$Kit = "webflow-to-shopify-dawn-kit"

if (-not (Test-Path "webflow-source" -PathType Container)) {
    Write-Error "webflow-source/ not found. Unzip your Webflow export there first."
    exit 1
}
if (-not (Test-Path $Kit -PathType Container)) {
    Write-Error "$Kit/ not found. Copy the kit folder into the project root first."
    exit 1
}

function Heading($txt) {
    Write-Host ""
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host "  $txt" -ForegroundColor Cyan
    Write-Host "===============================================================" -ForegroundColor Cyan
}
function Step($txt) {
    Write-Host ""
    Write-Host "> $txt" -ForegroundColor Yellow
    Write-Host "----------------------------------------------"
}

Heading "Webflow -> Shopify (Dawn-augmented) conversion"

Write-Host ""
Write-Host "  Brand pages   -> Webflow (verbatim CSS/JS/markup preserved)"
Write-Host "  Commerce      -> Dawn @ pinned tag"
Write-Host "  CSS conflicts -> resolved by cascade layers (Webflow wins)"

Step "Step 0: install Shopify AI skills (skipped if already)"
if ((Test-Path ".agents/skills/shopify-dev") -and (Test-Path ".agents/skills/shopify-liquid")) {
    Write-Host "  OK skills already at .agents/skills/ -- skipping" -ForegroundColor Green
} else {
    & pwsh "$Kit/scripts/install-skills.ps1"
}

Step "Step 1: audit Webflow source -> AUDIT.md"
& pwsh "$Kit/scripts/audit-source.ps1"

Step "Step 2: flatten Webflow assets (wraps CSS in @layer webflow)"
& pwsh "$Kit/scripts/flatten-assets.ps1"

Step "Step 3: bootstrap starter theme (Webflow-side defaults)"
Copy-Item -Recurse -Force "$Kit/starter-theme/*" .
# .shopifyignore is hidden -- copy explicitly
Copy-Item -Force "$Kit/starter-theme/.shopifyignore" .
Write-Host "  OK starter-theme/ copied to project root" -ForegroundColor Green
Write-Host "  OK includes CLAUDE.md, theme.liquid (with placeholders), 404, password, snippets" -ForegroundColor Green

Step "Step 4: pull Dawn at pinned tag -> dawn-source/"
& pwsh "$Kit/scripts/pull-dawn.ps1"

Step "Step 5: merge Dawn commerce (templates/sections/snippets/assets -- wraps CSS in @layer dawn)"
& pwsh "$Kit/scripts/merge-dawn-commerce.ps1"

Step "Step 6: extract Webflow brand pages -> sections + templates (skips Dawn-owned)"
& node "$Kit/scripts/convert.cjs"

Step "Step 7: convert Webflow newsletter forms (if any)"
$hasNewsletter = Get-ChildItem sections/*.liquid -ErrorAction SilentlyContinue | Select-String -Pattern "wf-form-Newsletter-Form" -SimpleMatch -List
if ($hasNewsletter) {
    & node "$Kit/scripts/convert-forms.cjs"
} else {
    Write-Host "  (no newsletter forms found in sections/ -- skipping)" -ForegroundColor DarkGray
}

Step "Step 8: audit CSS conflicts (Dawn ∩ Webflow) -> AUDIT.md"
& node "$Kit/scripts/audit-css-conflicts.cjs"

Step "Step 9: check for newer Dawn releases (informational)"
try {
    & pwsh "$Kit/scripts/check-dawn-updates.ps1"
} catch {
    Write-Host "  (newer release available -- see message above; not blocking)" -ForegroundColor DarkGray
}

Step "Step 10: verify Shopify-required files"
& bash "$Kit/scripts/check-required-files.sh"

Heading "Automated steps complete."

Write-Host ""
Write-Host "  Still TODO (need judgement -- hand to an AI assistant with"
Write-Host "  webflow-to-shopify-dawn-kit/CONVERT_PROMPT.md as the brief):"
Write-Host ""
Write-Host "  • Fill placeholders in layout/theme.liquid (use AUDIT.md):" -ForegroundColor Yellow
Write-Host "      <YOUR_WF_SITE_ID>      -- constant data-wf-site"
Write-Host "      <WF_PAGE_*>            -- per-template data-wf-page IDs"
Write-Host "      <WEBFLOW_BUNDLE>       -- Webflow JS bundle filename"
Write-Host "      <WEBFLOW_PRIMARY_CSS>  -- your brand's primary CSS file"
Write-Host "  • Build sections/header.liquid + sections/footer.liquid" -ForegroundColor Yellow
Write-Host "      (lift from webflow-source/index.html, wrap with schema)"
Write-Host "  • Wire Webflow 'Add to cart' buttons to Dawn's cart drawer" -ForegroundColor Yellow
Write-Host "      (see DAWN_INTEGRATION.md -- single-line JS bridge)"
Write-Host "  • (Optional) Split homepage into per-block sections via" -ForegroundColor Yellow
Write-Host "      node $Kit/scripts/split-page.cjs"
Write-Host ""
Write-Host "  Dawn handles (already wired):"
Write-Host "    templates/product.json, collection.json, cart.json, search.json"
Write-Host "    templates/customers/*"
Write-Host "    Cart drawer (rendered globally by layout/theme.liquid)"
Write-Host ""
Write-Host "  When the TODOs are done: commit + push + import to Shopify." -ForegroundColor Green
