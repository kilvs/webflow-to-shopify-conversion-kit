#!/usr/bin/env bash
# Reports whether a newer Dawn release exists than the version pinned in
# pull-dawn.sh. Hits GitHub's public Releases API — no auth required.
#
# Usage (from project root):
#   bash webflow-to-shopify-dawn-kit/scripts/check-dawn-updates.sh
#
# Exit codes:
#   0 — pinned version is current
#   1 — newer release available
#   2 — couldn't reach GitHub or parse response
#
# To bump the pin: edit DAWN_TAG in pull-dawn.sh AND below (kept in sync
# manually — the kit could move them to a shared file later if friction
# grows). Then delete dawn-source/ and re-run pull-dawn.sh +
# merge-dawn-commerce.sh.

set -e

# IMPORTANT: keep this in sync with DAWN_TAG in pull-dawn.sh
DAWN_TAG="v15.3.0"
DAWN_REPO="Shopify/dawn"
API_URL="https://api.github.com/repos/$DAWN_REPO/releases/latest"

if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl is required for this script." >&2
  exit 2
fi

echo "Checking $DAWN_REPO for newer Dawn releases ..."
echo "  pinned: $DAWN_TAG"

# Write response body to a temp file. -f fails on HTTP 4xx/5xx so we don't
# have to parse the status code ourselves (which interacts poorly with
# curl's -w flag under some Windows shells).
TMP_BODY="${TMPDIR:-/tmp}/dawn-update-check.json"
trap 'rm -f "$TMP_BODY"' EXIT

if ! curl -sSfL -H 'User-Agent: dawn-update-check' -o "$TMP_BODY" "$API_URL"; then
  echo "ERROR: couldn't reach GitHub API." >&2
  echo "  (network down, rate-limited [~60 req/hour anonymous], or API change)" >&2
  exit 2
fi

if [ ! -s "$TMP_BODY" ]; then
  echo "ERROR: empty response from GitHub API." >&2
  exit 2
fi

# Parse tag_name from JSON. No jq dependency — grep+sed handles the simple case.
latest=$(grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' "$TMP_BODY" | head -n1 | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

if [ -z "$latest" ]; then
  echo "ERROR: couldn't parse tag_name from API response." >&2
  exit 2
fi

echo "  latest: $latest"
echo ""

if [ "$DAWN_TAG" = "$latest" ]; then
  echo "✓ Pinned version is current."
  exit 0
fi

echo "⚠ A newer Dawn release is available: $latest"
echo ""
echo "To bump:"
echo "  1. Review the changelog: https://github.com/$DAWN_REPO/releases"
echo "  2. Edit DAWN_TAG in pull-dawn.sh AND check-dawn-updates.sh"
echo "     (and pull-dawn.ps1 / check-dawn-updates.ps1 if you support Windows)"
echo "  3. Delete dawn-source/ and re-run:"
echo "       bash webflow-to-shopify-dawn-kit/scripts/pull-dawn.sh"
echo "       bash webflow-to-shopify-dawn-kit/scripts/merge-dawn-commerce.sh"
echo "  4. Re-test commerce pages — Dawn ships breaking changes regularly."
exit 1
