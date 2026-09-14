#!/usr/bin/env bash
# PRJs runner | platform: mac | scope: repo-local
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
echo ""
echo "============================================================"
echo " SAFE OOM RESOLVER (mac) - diagnose + fix without deleting data"
echo "============================================================"
echo ""
"$ROOT/resolve.sh" "$@"
echo ""
echo "Done. If pressure returns later: ./IF-CRASH-AGAIN.sh"
