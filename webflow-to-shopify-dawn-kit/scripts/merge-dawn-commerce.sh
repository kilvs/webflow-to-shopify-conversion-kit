#!/usr/bin/env bash
# Copies Dawn's commerce templates/sections/snippets/assets into the project
# theme. Run AFTER pull-dawn.sh.
#
# WHAT GETS COPIED (whitelist):
#   templates/        product.json, collection.json, cart.json, search.json,
#                     list-collections.json, gift_card.liquid
#   templates/customers/  all files
#   sections/         main-product*, related-products, main-collection-*,
#                     main-list-collections, main-search, main-cart-*,
#                     cart-drawer, cart-notification, predictive-search,
#                     main-account, main-login, main-register, main-addresses,
#                     main-order, main-reset-password, main-activate-account
#   snippets/         ALL Dawn snippets EXCEPT header-search, mega-menu,
#                     list-menu, header-drawer (Webflow's header.liquid handles
#                     nav)
#   assets/           ALL Dawn assets. Each .css is wrapped in @layer dawn { }.
#                     Filename collisions with existing assets/ files → ERROR
#                     (user must resolve manually).
#   locales/en.default.json — only if not already present.
#
# WHAT DOES NOT GET COPIED (Webflow's job or kit-supplied):
#   layout/theme.liquid, layout/password.liquid
#   config/settings_schema.json, config/settings_data.json
#   templates/{index,page,blog,article,404,password}.json
#   sections/{header,footer,announcement-bar}.liquid
#   home/about/blog-related sections (image-banner, slideshow, multicolumn, …)
#
# Usage (from project root, after pull-dawn.sh):
#   bash webflow-to-shopify-dawn-kit/scripts/merge-dawn-commerce.sh
#
# Idempotent: re-running overwrites Dawn-managed files but preserves locale
# customizations and aborts on Webflow-asset collisions.

set -e

DAWN_DIR="${1:-dawn-source}"
KIT_DIR="webflow-to-shopify-dawn-kit"

if [ ! -d "$DAWN_DIR" ]; then
  echo "ERROR: $DAWN_DIR/ not found. Run pull-dawn.sh first." >&2
  exit 1
fi
if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: node is required (used to wrap Dawn CSS in @layer dawn)." >&2
  exit 1
fi

mkdir -p sections snippets assets templates/customers locales

echo "▶ Templates"
echo "──────────────────────────────────────────────"
COMMERCE_TEMPLATES=(
  product.json collection.json cart.json search.json list-collections.json
  gift_card.liquid
)
for t in "${COMMERCE_TEMPLATES[@]}"; do
  src="$DAWN_DIR/templates/$t"
  if [ -f "$src" ]; then
    cp "$src" "templates/$t"
    echo "  templates/$t"
  else
    echo "  WARN: $src not in this Dawn version — skipped" >&2
  fi
done

echo ""
echo "▶ Customer templates"
echo "──────────────────────────────────────────────"
if [ -d "$DAWN_DIR/templates/customers" ]; then
  for f in "$DAWN_DIR"/templates/customers/*; do
    [ -f "$f" ] && cp "$f" "templates/customers/$(basename "$f")" && echo "  templates/customers/$(basename "$f")"
  done
else
  echo "  WARN: no templates/customers/ in Dawn — skipped" >&2
fi

echo ""
echo "▶ Sections (commerce-only whitelist)"
echo "──────────────────────────────────────────────"
COMMERCE_SECTION_PATTERNS=(
  "main-product*.liquid"
  "related-products.liquid"
  "main-collection-*.liquid"
  "main-list-collections.liquid"
  "main-search.liquid"
  "main-cart-*.liquid"
  "cart-drawer.liquid"
  "cart-notification.liquid"
  "predictive-search.liquid"
  "main-account.liquid"
  "main-login.liquid"
  "main-register.liquid"
  "main-addresses.liquid"
  "main-order.liquid"
  "main-reset-password.liquid"
  "main-activate-account.liquid"
)
section_count=0
for pat in "${COMMERCE_SECTION_PATTERNS[@]}"; do
  for src in "$DAWN_DIR"/sections/$pat; do
    if [ -f "$src" ]; then
      cp "$src" "sections/$(basename "$src")"
      echo "  sections/$(basename "$src")"
      section_count=$((section_count + 1))
    fi
  done
done
echo "  ($section_count sections copied)"

echo ""
echo "▶ Snippets (all except header/footer-related)"
echo "──────────────────────────────────────────────"
# Webflow's header.liquid + footer.liquid handle navigation — Dawn equivalents skipped
SKIP_SNIPPETS=(
  header-search.liquid
  mega-menu.liquid
  list-menu.liquid
  header-drawer.liquid
)
snip_copied=0
snip_skipped=0
for src in "$DAWN_DIR"/snippets/*.liquid; do
  base=$(basename "$src")
  skip=false
  for s in "${SKIP_SNIPPETS[@]}"; do
    if [ "$base" = "$s" ]; then skip=true; break; fi
  done
  if [ "$skip" = true ]; then
    snip_skipped=$((snip_skipped + 1))
  else
    cp "$src" "snippets/$base"
    snip_copied=$((snip_copied + 1))
  fi
done
echo "  $snip_copied copied, $snip_skipped skipped (Webflow-owned)"

echo ""
echo "▶ Assets (collision check)"
echo "──────────────────────────────────────────────"
collisions=()
for src in "$DAWN_DIR"/assets/*; do
  base=$(basename "$src")
  dest="assets/$base"
  if [ -f "$dest" ]; then
    collisions+=("$base")
  fi
done
if [ ${#collisions[@]} -gt 0 ]; then
  echo "ERROR: ${#collisions[@]} Dawn asset(s) would overwrite existing files in assets/:" >&2
  for c in "${collisions[@]}"; do
    echo "  $c" >&2
  done
  echo "" >&2
  echo "Resolve manually: rename or remove the conflicting file in assets/, then re-run." >&2
  exit 1
fi

asset_copied=0
for src in "$DAWN_DIR"/assets/*; do
  cp "$src" "assets/$(basename "$src")"
  asset_copied=$((asset_copied + 1))
done
echo "  $asset_copied Dawn assets copied"

echo ""
echo "▶ Wrap Dawn CSS in @layer dawn"
echo "──────────────────────────────────────────────"
node "$KIT_DIR/scripts/wrap-css-layers.cjs" assets dawn

echo ""
echo "▶ Locales"
echo "──────────────────────────────────────────────"
if [ -f "locales/en.default.json" ]; then
  echo "  locales/en.default.json already exists — skipped"
  echo "  (you'll need to merge Dawn's commerce strings manually — see DAWN_INTEGRATION.md)"
else
  cp "$DAWN_DIR/locales/en.default.json" locales/en.default.json
  echo "  locales/en.default.json (Dawn defaults)"
fi

echo ""
echo "✓ Dawn commerce merged into theme."
echo "  Next: configure layout/theme.liquid (Phase 4) to declare"
echo "       <style>@layer dawn, webflow;</style> and load both bundles."
