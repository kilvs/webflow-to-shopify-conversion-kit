#!/usr/bin/env bash
# Runs every fully-automatable step of the Dawn-augmented Webflow → Shopify
# conversion. Stops on the first error.
#
# Strategy:
#   Webflow handles brand pages (home, about, contact, /pages/*, blog,
#   articles, 404, password). Dawn handles commerce (product, collection,
#   cart, search, customer account). Cascade layers resolve CSS conflicts.
#
# Preconditions:
#   - webflow-source/ exists (contains the unzipped Webflow export)
#   - webflow-to-shopify-dawn-kit/ lives at the project root
#   - git, node, curl available
#
# Usage (from project root):
#   bash webflow-to-shopify-dawn-kit/scripts/convert-all.sh
#
# After this runs cleanly, only judgement-call steps remain:
#   - fill placeholders in layout/theme.liquid (using AUDIT.md)
#   - build sections/header.liquid + sections/footer.liquid
#   - integrate Webflow "Add to cart" buttons with Dawn's cart drawer
#     (see DAWN_INTEGRATION.md)
#   - run check-required-files.sh
#
# An AI assistant with CONVERT_PROMPT.md context can finish those for you.

set -euo pipefail
KIT="webflow-to-shopify-dawn-kit"

if [ ! -d "webflow-source" ]; then
  echo "ERROR: webflow-source/ not found. Unzip your Webflow export there first." >&2
  exit 1
fi
if [ ! -d "$KIT" ]; then
  echo "ERROR: $KIT/ not found. Copy the kit folder into the project root first." >&2
  exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Webflow → Shopify (Dawn-augmented) conversion"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  Brand pages   → Webflow (verbatim CSS/JS/markup preserved)"
echo "  Commerce      → Dawn @ pinned tag"
echo "  CSS conflicts → resolved by cascade layers (Webflow wins)"
echo ""

echo ""
echo "▶ Step 0: install Shopify AI skills (skipped if already)"
echo "──────────────────────────────────────────────"
if [ ! -d ".agents/skills/shopify-dev" ] || [ ! -d ".agents/skills/shopify-liquid" ]; then
  bash "$KIT/scripts/install-skills.sh"
else
  echo "  ✓ skills already at .agents/skills/ — skipping"
fi

echo ""
echo "▶ Step 1: audit Webflow source → AUDIT.md"
echo "──────────────────────────────────────────────"
bash "$KIT/scripts/audit-source.sh"

echo ""
echo "▶ Step 2: flatten Webflow assets (wraps CSS in @layer webflow)"
echo "──────────────────────────────────────────────"
bash "$KIT/scripts/flatten-assets.sh"

echo ""
echo "▶ Step 3: bootstrap starter theme (Webflow-side defaults)"
echo "──────────────────────────────────────────────"
cp -r "$KIT/starter-theme/." .
echo "  ✓ starter-theme/ copied to project root"
echo "  ✓ includes CLAUDE.md, theme.liquid (with placeholders), 404, password, snippets"

echo ""
echo "▶ Step 4: pull Dawn at pinned tag → dawn-source/"
echo "──────────────────────────────────────────────"
bash "$KIT/scripts/pull-dawn.sh"

echo ""
echo "▶ Step 5: merge Dawn commerce (templates/sections/snippets/assets — wraps CSS in @layer dawn)"
echo "──────────────────────────────────────────────"
bash "$KIT/scripts/merge-dawn-commerce.sh"

echo ""
echo "▶ Step 6: extract Webflow brand pages → sections + templates (skips Dawn-owned)"
echo "──────────────────────────────────────────────"
node "$KIT/scripts/convert.cjs"

echo ""
echo "▶ Step 7: convert Webflow newsletter forms (if any)"
echo "──────────────────────────────────────────────"
if grep -q "wf-form-Newsletter-Form" sections/*.liquid 2>/dev/null; then
  node "$KIT/scripts/convert-forms.cjs"
else
  echo "  (no newsletter forms found in sections/ — skipping)"
fi

echo ""
echo "▶ Step 8: audit CSS conflicts (Dawn ∩ Webflow) → AUDIT.md"
echo "──────────────────────────────────────────────"
node "$KIT/scripts/audit-css-conflicts.cjs"

echo ""
echo "▶ Step 9: check for newer Dawn releases (informational)"
echo "──────────────────────────────────────────────"
bash "$KIT/scripts/check-dawn-updates.sh" || echo "  (newer release available — see message above; not blocking)"

echo ""
echo "▶ Step 10: verify Shopify-required files"
echo "──────────────────────────────────────────────"
bash "$KIT/scripts/check-required-files.sh" || true

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Automated steps complete."
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  Still TODO (need judgement — hand to an AI assistant with"
echo "  webflow-to-shopify-dawn-kit/CONVERT_PROMPT.md as the brief):"
echo ""
echo "  • Fill placeholders in layout/theme.liquid (use AUDIT.md):"
echo "      <YOUR_WF_SITE_ID>      — constant data-wf-site"
echo "      <WF_PAGE_*>            — per-template data-wf-page IDs"
echo "      <WEBFLOW_BUNDLE>       — Webflow JS bundle filename"
echo "      <WEBFLOW_PRIMARY_CSS>  — your brand's primary CSS file"
echo "  • Build sections/header.liquid + sections/footer.liquid"
echo "      (lift from webflow-source/index.html, wrap with schema)"
echo "  • Wire Webflow 'Add to cart' buttons to Dawn's cart drawer"
echo "      (see DAWN_INTEGRATION.md — single-line JS bridge)"
echo "  • (Optional) Split homepage into per-block sections via"
echo "      node $KIT/scripts/split-page.cjs"
echo ""
echo "  Dawn handles (already wired):"
echo "    templates/product.json, collection.json, cart.json, search.json"
echo "    templates/customers/*"
echo "    Cart drawer (rendered globally by layout/theme.liquid)"
echo ""
echo "  When the TODOs are done: commit + push + import to Shopify."
