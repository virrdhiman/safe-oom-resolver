#!/usr/bin/env bash
# PRJs runner | platform: mac | scope: repo-local
# Free memory by stopping ONLY safe orphan absorbers.
# NEVER deletes files, chats, DB data, or OS components.
# NEVER kills the editor (agent chats) or macOS system processes.
#
# Usage:
#   ./release-memory-safe.sh
#   ./release-memory-safe.sh --whatif
#   ./release-memory-safe.sh --browsers          # also quit Chrome/Edge/Firefox/Brave
#   ./release-memory-safe.sh --aggressive        # also large non-editor node/bun
#   ./release-memory-safe.sh --min-mb 80
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$ROOT/logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/release-memory-mac.log"

WHATIF=0
BROWSERS=0
AGGRESSIVE=0
MIN_MB=80

while [[ $# -gt 0 ]]; do
  case "$1" in
    --whatif|-n) WHATIF=1; shift ;;
    --browsers) BROWSERS=1; shift ;;
    --aggressive) AGGRESSIVE=1; shift ;;
    --min-mb) MIN_MB="${2:-80}"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

log() {
  local line="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo "$line" | tee -a "$LOG"
}

approx_free_mb() {
  local pagesize free_pages inactive_pages
  pagesize="$(pagesize 2>/dev/null || echo 4096)"
  free_pages="$(vm_stat | awk '/Pages free/ {gsub("\\.","",$3); print $3}')"
  inactive_pages="$(vm_stat | awk '/Pages inactive/ {gsub("\\.","",$3); print $3}')"
  free_pages="${free_pages:-0}"
  inactive_pages="${inactive_pages:-0}"
  echo $(( (free_pages + inactive_pages) * pagesize / 1024 / 1024 ))
}

is_protected() {
  local pid="$1" comm="$2" args="$3"
  # Never touch system / editor / agents / DB
  case "$comm" in
    kernel_task|launchd|WindowServer|loginwindow|Finder|Dock|SystemUIServer|\
    cfprefsd|distnoted|UserEventAgent|coreservicesd|mds|mds_stores|mdworker*|\
    trustd|securityd|bluetoothd|configd|powerd|notifyd|syslogd|Cursor|\
    postgres|redis-server|OrbStack|Docker|com.docker*)
      return 0 ;;
  esac
  [[ "$comm" == *Cursor* ]] && return 0
  [[ "$args" == *"/Cursor.app/"* || "$args" == *"Cursor Helper"* ]] && return 0
  [[ "$args" == *"desktop-agent"* || "$args" == *"Desktop Agent"* ]] && return 0
  [[ "$pid" == "$$" || "$pid" == "$PPID" ]] && return 0
  return 1
}

is_candidate() {
  local pid="$1" comm="$2" args="$3" rss_kb="$4"
  local rss_mb=$(( rss_kb / 1024 ))
  (( rss_mb < MIN_MB )) && return 1
  is_protected "$pid" "$comm" "$args" && return 1

  local base
  base="$(basename "$comm")"

  # Playwright / Puppeteer Chromium only
  if [[ "$base" == "Chromium" || "$base" == "chrome" || "$base" == "Google Chrome Helper" || "$base" == "Chrome" ]]; then
    if [[ "$args" == *playwright* || "$args" == *puppeteer* || "$args" == *ms-playwright* || "$args" == *user-data-dir=*flipkart* ]]; then
      return 0
    fi
    if (( BROWSERS == 1 )); then
      if [[ "$base" == "Google Chrome" || "$base" == "Google Chrome Helper" || "$base" == "Chrome" || \
            "$base" == "Microsoft Edge" || "$base" == "Firefox" || "$base" == "Brave Browser" ]]; then
        return 0
      fi
    fi
    return 1
  fi

  if [[ "$base" == "prisma" ]]; then
    return 0
  fi

  if [[ "$base" == "node" || "$base" == "nodejs" || "$base" == "bun" ]]; then
    [[ "$args" == *"/Cursor.app/"* || "$args" == *"cursor-agent"* ]] && return 1
    if [[ "$args" == *prisma* || "$args" == *"db push"* || "$args" == *db:push* || \
          "$args" == *prisma-push-safe* || "$args" == *ensure-local-stack* || \
          "$args" == *max-old-space-size=8192* || "$args" == *max-old-space-size=16384* ]]; then
      return 0
    fi
    (( AGGRESSIVE == 1 )) && return 0
    (( rss_mb > 700 )) && return 0
    return 1
  fi

  if (( BROWSERS == 1 )); then
    case "$base" in
      "Google Chrome"|"Microsoft Edge"|"Firefox"|"Brave Browser"|"Opera") return 0 ;;
    esac
  fi

  return 1
}

echo ""
echo "============================================================"
echo " SAFE MEMORY RELEASE (mac) - no deletes, keep editor chats"
echo "============================================================"
echo " Protects: editor, desktop agents, macOS system, Postgres/Redis"
echo " May stop: leftover Prisma/Node db:push, Playwright Chromium"
echo " Log: $LOG"
echo ""

before="$(approx_free_mb)"
log "BEFORE approxFree=${before}MB whatif=${WHATIF} browsers=${BROWSERS} aggressive=${AGGRESSIVE} minMB=${MIN_MB}"

# pid rss(kb) comm args...
candidates=()
while IFS= read -r line; do
  # Format from ps: PID RSS COMM ARGS...
  pid="$(awk '{print $1}' <<<"$line")"
  rss="$(awk '{print $2}' <<<"$line")"
  comm="$(awk '{print $3}' <<<"$line")"
  args="$(awk '{for(i=4;i<=NF;i++) printf $i" "; print ""}' <<<"$line")"
  [[ -z "$pid" || "$pid" == "PID" ]] && continue
  if is_candidate "$pid" "$comm" "$args" "$rss"; then
    mb=$(( rss / 1024 ))
    candidates+=("$pid|$mb|$comm")
    echo "  candidate: pid=$pid ~${mb}MB  $comm"
  fi
done < <(ps -axo pid=,rss=,comm=,args=)

if (( ${#candidates[@]} == 0 )); then
  log "No safe release candidates found. Editor/system left untouched."
  echo "Nothing safe to stop. Quit unused apps manually if still low."
  exit 0
fi

stopped=0
failed=0
for item in "${candidates[@]}"; do
  IFS='|' read -r pid mb comm <<<"$item"
  if (( WHATIF == 1 )); then
    log "WOULD STOP $comm pid=$pid ~${mb}MB"
    continue
  fi
  if kill -TERM "$pid" 2>/dev/null; then
    sleep 0.3
    if kill -0 "$pid" 2>/dev/null; then
      kill -KILL "$pid" 2>/dev/null || true
    fi
    log "STOPPED $comm pid=$pid ~${mb}MB"
    stopped=$((stopped + 1))
  else
    log "SKIP $comm pid=$pid (permission or already gone)"
    failed=$((failed + 1))
  fi
done

sleep 1
after="$(approx_free_mb)"
log "AFTER approxFree=${after}MB (was ${before}MB) stopped=${stopped} failed=${failed}"

echo ""
echo "Stopped ${stopped} process(es). Approx reclaimable: ${before}MB -> ${after}MB"
echo "Editor / agent chats / macOS system were NOT touched."
echo "No files deleted."

if (( after < 900 )); then
  echo ""
  echo "Still tight. Next:"
  echo "  1) Re-run: ./RELEASE-MEMORY.sh --browsers"
  echo "  2) Free disk on / (swap needs space): df -h /"
  echo "  3) Quit unused apps in Activity Monitor yourself"
  exit 2
fi

exit 0
