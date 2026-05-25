# PowerShell equivalent of flatten-assets.sh -- for Windows users.
#
# Flattens webflow-source/{css,js,images,fonts,videos,documents}/ into
# assets/, rewrites Webflow CSS paths, and wraps each Webflow CSS file in
# `@layer webflow { ... }` for cascade-layer-based conflict resolution with
# Dawn. Layer order declared in theme.liquid is `@layer dawn, webflow;` --
# Webflow wins on shared selectors.
#
# Usage (from project root):
#   pwsh webflow-to-shopify-dawn-kit/scripts/flatten-assets.ps1

param(
    [string]$SourceDir = "webflow-source",
    [string]$AssetsDir = "assets"
)

$ErrorActionPreference = "Stop"

# Subdirectories to flatten. videos/ and documents/ are not in every Webflow
# export, but when present they belong in assets/ alongside images, fonts, etc.
$Subdirs = @("css", "js", "images", "fonts", "videos", "documents")

if (-not (Test-Path $SourceDir -PathType Container)) {
    Write-Error "$SourceDir/ not found."
    exit 1
}

New-Item -ItemType Directory -Path $AssetsDir -Force | Out-Null

# Collision check
$allNames = @()
foreach ($d in $Subdirs) {
    if (Test-Path "$SourceDir/$d") {
        $allNames += (Get-ChildItem "$SourceDir/$d" -File | ForEach-Object { $_.Name })
    }
}
$collisions = $allNames | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name }
if ($collisions) {
    Write-Host "ERROR: filename collisions detected -- would overwrite when flattened:" -ForegroundColor Red
    $collisions | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    Write-Host ""
    Write-Host "Rename one copy of each colliding file in $SourceDir/ before re-running." -ForegroundColor Yellow
    exit 1
}

# Copy
$copied = 0
foreach ($d in $Subdirs) {
    if (Test-Path "$SourceDir/$d") {
        $files = Get-ChildItem "$SourceDir/$d" -File
        $files | Copy-Item -Destination $AssetsDir -Force
        Write-Host "  $d/  ->  $AssetsDir/  ($($files.Count) files)"
        $copied += $files.Count
    }
}

# Rewrite ../fonts/, ../images/, ../videos/, ../documents/ in CSS
$fixed = 0
foreach ($css in Get-ChildItem "$AssetsDir/*.css" -File) {
    $content = Get-Content $css.FullName -Raw
    if ($content -match '\.\./') {
        $content = $content `
            -replace '\.\./fonts/', '' `
            -replace '\.\./images/', '' `
            -replace '\.\./videos/', '' `
            -replace '\.\./documents/', ''
        Set-Content -Path $css.FullName -Value $content -NoNewline
        Write-Host "  rewrote ../fonts/ + ../images/ + ../videos/ + ../documents/ in $($css.Name)"
        $fixed++
    }
}

# Wrap Webflow CSS in @layer webflow (cascade-layer-based conflict resolution
# with Dawn). The helper is idempotent -- re-running this script is safe.
$KitDir = if ($env:KIT_DIR) { $env:KIT_DIR } else { "webflow-to-shopify-dawn-kit" }
$Wrapper = "$KitDir/scripts/wrap-css-layers.cjs"
if (Test-Path $Wrapper) {
    if (Get-Command node -ErrorAction SilentlyContinue) {
        Write-Host ""
        Write-Host "Wrapping Webflow CSS in @layer webflow ..."
        & node $Wrapper $AssetsDir webflow
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "wrap-css-layers.cjs returned non-zero; check output above."
        }
    } else {
        Write-Warning "node not found -- Webflow CSS NOT wrapped in @layer webflow."
        Write-Warning "Dawn's CSS may override Webflow's on conflicting selectors."
    }
} else {
    Write-Warning "$Wrapper missing -- Webflow CSS NOT wrapped in @layer webflow."
}

# Report
Write-Host ""
Write-Host "OK $copied files copied into $AssetsDir/" -ForegroundColor Green
Write-Host "OK $fixed CSS file(s) had asset references rewritten" -ForegroundColor Green

# Final dedupe check
$dupes = Get-ChildItem $AssetsDir -File | Group-Object Name | Where-Object { $_.Count -gt 1 }
if ($dupes) {
    Write-Host "WARN Duplicate filenames in $AssetsDir/:" -ForegroundColor Yellow
    $dupes | ForEach-Object { Write-Host "  $($_.Name)" }
    exit 1
}
