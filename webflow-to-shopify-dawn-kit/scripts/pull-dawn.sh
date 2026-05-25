#!/usr/bin/env bash
# Clones Shopify/dawn at the pinned tag into dawn-source/.
# Idempotent: skips if dawn-source/ is already at the pinned tag.
#
# Usage (from project root):
#   bash webflow-to-shopify-dawn-kit/scripts/pull-dawn.sh
#
# To bump the pin, edit DAWN_TAG below and re-run. The Phase 3
# check-dawn-updates.sh script reports when a newer Dawn release exists.

set -e

# ──────────────────────────────────────────────────────────────────────────
# Pinned Dawn version. Bump deliberately — Dawn ships breaking changes
# regularly, and the merge-dawn-commerce whitelist below may need to be
# updated when section/snippet filenames change.
# ──────────────────────────────────────────────────────────────────────────
DAWN_TAG="v15.3.0"
DAWN_DIR="${1:-dawn-source}"
DAWN_REPO="https://github.com/Shopify/dawn.git"

if [ -d "$DAWN_DIR/.git" ]; then
  current=$(cd "$DAWN_DIR" && git describe --tags --exact-match 2>/dev/null || true)
  if [ "$current" = "$DAWN_TAG" ]; then
    echo "✓ $DAWN_DIR/ already at $DAWN_TAG — nothing to do"
    exit 0
  fi
  echo "ERROR: $DAWN_DIR/ exists but is at '${current:-unknown}' (expected $DAWN_TAG)" >&2
  echo "  Delete $DAWN_DIR/ and re-run, or edit DAWN_TAG to match." >&2
  exit 1
fi

if [ -e "$DAWN_DIR" ]; then
  echo "ERROR: $DAWN_DIR/ exists but is not a git checkout. Move or delete it first." >&2
  exit 1
fi

echo "Cloning Shopify/dawn @ $DAWN_TAG into $DAWN_DIR/ ..."
git clone --depth=1 --branch="$DAWN_TAG" "$DAWN_REPO" "$DAWN_DIR"

echo ""
echo "✓ Dawn pulled to $DAWN_DIR/ (commit: $(cd "$DAWN_DIR" && git rev-parse --short HEAD))"
echo "  Next: bash webflow-to-shopify-dawn-kit/scripts/merge-dawn-commerce.sh"
