#!/usr/bin/env bash
# PRJs runner | platform: mac | scope: repo-local
# If OOM/editor crash pressure returns: free absorbing processes safely.
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
mkdir -p "$ROOT/../logs"

echo ""
echo "============================================================"
echo " IF CRASH PRESSURE RETURNS - SAFE MEMORY RELEASE (mac)"
echo "============================================================"
echo "  - Does NOT delete files, chats, DB, or OS components"
echo "  - Does NOT kill the editor (agent chats stay)"
echo "  - Stops leftover Node/Bun/Playwright memory hogs"
echo "  - Optional: --browsers (tabs close; profile data kept on disk)"
echo "============================================================"
echo ""

"$ROOT/diagnose.sh" || true
echo ""

EXTRA=()
# Forward known flags; optionally prompt for browsers when interactive and no flag given
has_browsers=0
for a in "$@"; do
  case "$a" in
    --browsers|-y) has_browsers=1 ;;
  esac
  EXTRA+=("$a")
done

if (( has_browsers == 0 )) && [[ -t 0 ]]; then
  read -r -p "Also quit Chrome/Edge/Brave/Firefox? [y/N] " ans || true
  if [[ "${ans:-}" =~ ^[Yy]$ ]]; then
    EXTRA+=(--browsers)
  fi
fi

"$ROOT/release-memory-safe.sh" "${EXTRA[@]}"
ec=$?

echo ""
echo "--- diagnose after release ---"
"$ROOT/diagnose.sh" || true

echo ""
echo "Log: $ROOT/../logs/release-memory-mac.log"
exit "$ec"
