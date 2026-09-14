#!/usr/bin/env bash
# PRJs runner | platform: mac | scope: repo-local
# macOS swap is normally always on (unlike Windows pagefile).
# This script only CHECKS swap + free disk; it does NOT delete anything
# and does NOT disable SIP or change system files.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$ROOT/logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/ensure-swap-mac.log"

log() {
  local line="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo "$line" | tee -a "$LOG"
}

echo "==> macOS swap check (SAFE - no deletes, no OS mutations)"
log "==== ensure-swap-safe start ===="

swap_line="$(sysctl -n vm.swapusage 2>/dev/null || true)"
log "vm.swapusage: ${swap_line:-unavailable}"

# If swap total is 0, something disabled swap (rare) - guide only
if [[ -z "$swap_line" || "$swap_line" == *"total = 0"* || "$swap_line" == *"total = 0.00"* ]]; then
  log "WARN: swap appears disabled or unavailable."
  echo "macOS usually manages swap automatically. Do NOT delete /private/var/vm files."
  echo "Check: free disk on / (need several GB), then reboot."
  echo "If an MDM/policy disabled swap, ask IT - do not wipe system files."
  exit 2
fi

root_avail_g="$(df -g / | awk 'NR==2{print $4}')"
log "Root free GB: ${root_avail_g}"
if (( root_avail_g < 8 )); then
  log "WARN: low disk on / can block swap growth."
  echo "Free space on Macintosh HD (user files you choose) - do not delete System/Library."
  exit 2
fi

log "OK: swap present and root has headroom. No action required (macOS auto-manages swap)."
echo "OK: nothing to enable. macOS swap is automatic (unlike Windows pagefile)."
echo "If editor/Node still OOM: run ./IF-CRASH-AGAIN.sh"
exit 0
