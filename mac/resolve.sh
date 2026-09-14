#!/usr/bin/env bash
# PRJs runner | platform: mac | scope: repo-local
# Diagnose + optional safe orphan release. Never deletes data/chats.
set -u

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

SKIP_RELEASE=0
for a in "$@"; do
  [[ "$a" == "--skip-release" ]] && SKIP_RELEASE=1
done

echo "==> Safety contract"
echo "  - No system/user/DB/backup deletes"
echo "  - No agent transcript deletes"
echo "  - macOS swap is automatic (no pagefile enable needed)"
echo ""

"$ROOT/diagnose.sh" || true
diag=$?

echo ""
"$ROOT/report-memory-hogs.sh" || true

approx() {
  local pagesize free_pages inactive_pages
  pagesize="$(pagesize 2>/dev/null || echo 4096)"
  free_pages="$(vm_stat | awk '/Pages free/ {gsub("\\.","",$3); print $3}')"
  inactive_pages="$(vm_stat | awk '/Pages inactive/ {gsub("\\.","",$3); print $3}')"
  echo $(( (${free_pages:-0} + ${inactive_pages:-0}) * pagesize / 1024 / 1024 ))
}

free_mb="$(approx)"
if (( free_mb < 1500 && SKIP_RELEASE == 0 )); then
  echo ""
  echo "==> Low reclaimable memory - running SAFE orphan release"
  "$ROOT/release-memory-safe.sh" || true
fi

echo ""
"$ROOT/ensure-swap-safe.sh" || true

echo ""
echo "Agent playbook: ../agent/AGENTS.md + ../agent/PLAYBOOK.md"
exit 0
