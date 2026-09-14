#!/usr/bin/env bash
# PRJs runner | platform: mac | scope: repo-local
# One entry when crashing happens again.
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo ""
echo "============================================================"
echo " SAME CRASH AGAIN? SAFE RESOLVE (mac) - no data / chat loss"
echo "============================================================"
echo "  Step 1: Diagnose"
echo "  Step 2: Release absorbing processes (keep editor + OS)"
echo "  Step 3: Confirm swap / free disk (macOS auto-manages swap)"
echo "============================================================"
echo ""

"$ROOT/RELEASE-MEMORY.sh" "$@"
ec=$?

echo ""
"$ROOT/resolve.sh" --skip-release || true

echo ""
echo "If diagnose still UNSAFE:"
echo "  - Free disk on / (do not delete System folders)"
echo "  - Quit unused apps in Activity Monitor"
echo "  - Reboot once if swap looked stuck at 0"
echo ""
exit "$ec"
