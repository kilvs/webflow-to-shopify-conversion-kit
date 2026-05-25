#!/usr/bin/env bash
# Flattens webflow-source/{css,js,images,fonts,videos,documents}/ into assets/,
# then rewrites Webflow CSS so ../fonts/ and ../images/ references resolve at
# the new flat path. Reports any filename collisions before exiting.
#
# Finally, wraps each Webflow CSS file in `@layer webflow { ... }` so that
# Dawn's commerce CSS (wrapped in @layer dawn by merge-dawn-commerce) and
# Webflow's brand CSS can coexist with predictable precedence. The layer
# order declared in theme.liquid is `@layer dawn, webflow;` — Webflow wins
# on shared selectors.
#
# Usage (from project root):
#   bash webflow-to-shopify-dawn-kit/scripts/flatten-assets.sh

set -e

SOURCE_DIR="${1:-webflow-source}"
ASSETS_DIR="${2:-assets}"

# Subdirectories to flatten. videos/ and documents/ are not in every Webflow
# export, but when present they belong in assets/ alongside images, fonts, etc.
SUBDIRS=(css js images fonts videos documents)

if [ ! -d "$SOURCE_DIR" ]; then
  echo "ERROR: $SOURCE_DIR/ not found." >&2
  exit 1
fi

mkdir -p "$ASSETS_DIR"

# Collision check (before copying, so we don't accidentally clobber)
collisions=$(
  for d in "${SUBDIRS[@]}"; do
    [ -d "$SOURCE_DIR/$d" ] && ls -1 "$SOURCE_DIR/$d"
  done | sort | uniq -d
)
if [ -n "$collisions" ]; then
  echo "ERROR: filename collisions detected -- would overwrite when flattened:" >&2
  echo "$collisions" >&2
  echo "" >&2
  echo "Rename one copy of each colliding file in $SOURCE_DIR/ before re-running." >&2
  exit 1
fi

# Copy
copied=0
for d in "${SUBDIRS[@]}"; do
  if [ -d "$SOURCE_DIR/$d" ]; then
    n=$(ls -1 "$SOURCE_DIR/$d" | wc -l)
    cp "$SOURCE_DIR/$d"/* "$ASSETS_DIR/" 2>/dev/null
    echo "  $d/  ->  $ASSETS_DIR/  ($n files)"
    copied=$((copied + n))
  fi
done

# Rewrite ../fonts/, ../images/, ../videos/, ../documents/ in CSS so flat paths resolve
fixed=0
for css in "$ASSETS_DIR"/*.css; do
  if [ -f "$css" ] && grep -q "\.\./" "$css"; then
    sed -i "s|\.\./fonts/||g; s|\.\./images/||g; s|\.\./videos/||g; s|\.\./documents/||g" "$css"
    echo "  rewrote ../fonts/ + ../images/ + ../videos/ + ../documents/ in $(basename "$css")"
    fixed=$((fixed + 1))
  fi
done

# Wrap Webflow CSS in @layer webflow (cascade-layer-based conflict resolution
# with Dawn). The helper is idempotent — re-running this script is safe.
KIT_DIR="${KIT_DIR:-webflow-to-shopify-dawn-kit}"
WRAPPER="$KIT_DIR/scripts/wrap-css-layers.cjs"
if [ -f "$WRAPPER" ]; then
  if command -v node >/dev/null 2>&1; then
    echo ""
    echo "Wrapping Webflow CSS in @layer webflow ..."
    node "$WRAPPER" "$ASSETS_DIR" webflow
  else
    echo "WARN: node not found — Webflow CSS NOT wrapped in @layer webflow." >&2
    echo "      Dawn's CSS may override Webflow's on conflicting selectors." >&2
  fi
else
  echo "WARN: $WRAPPER missing — Webflow CSS NOT wrapped in @layer webflow." >&2
fi

# Final report
echo ""
echo "OK $copied files copied into $ASSETS_DIR/"
echo "OK $fixed CSS file(s) had asset references rewritten"
remaining=$(ls -1 "$ASSETS_DIR" | sort | uniq -d | wc -l)
if [ "$remaining" -ne 0 ]; then
  echo "WARN $remaining duplicate filename(s) ended up in $ASSETS_DIR/ -- investigate:" >&2
  ls -1 "$ASSETS_DIR" | sort | uniq -d >&2
  exit 1
fi
