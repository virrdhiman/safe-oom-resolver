#!/usr/bin/env bash
# PRJs runner | platform: mac | scope: repo-local
# Read-only memory / swap diagnosis. No deletes. No mutations.
set -euo pipefail

echo "=== Memory (macOS) ==="
pagesize="$(pagesize 2>/dev/null || echo 4096)"
# vm_stat: free + inactive as rough reclaimable
vm_stat | head -20

phys_bytes="$(sysctl -n hw.memsize 2>/dev/null || echo 0)"
phys_mb=$(( phys_bytes / 1024 / 1024 ))
echo "Physical RAM: ${phys_mb} MB"

echo ""
echo "=== Swap ==="
swap_line="$(sysctl -n vm.swapusage 2>/dev/null || true)"
echo "${swap_line:-unavailable}"

# Parse total/used/free from: total = 1.00G  used = 200.00M  free = 800.00M
parse_to_mb() {
  local v="$1"
  if [[ "$v" =~ ([0-9.]+)G ]]; then
    awk -v n="${BASH_REMATCH[1]}" 'BEGIN{printf "%d", n*1024}'
  elif [[ "$v" =~ ([0-9.]+)M ]]; then
    awk -v n="${BASH_REMATCH[1]}" 'BEGIN{printf "%d", n}'
  else
    echo 0
  fi
}

total_swap_mb=0
used_swap_mb=0
free_swap_mb=0
if [[ "$swap_line" =~ total[[:space:]]*=[[:space:]]*([^ ]+) ]]; then
  total_swap_mb="$(parse_to_mb "${BASH_REMATCH[1]}")"
fi
if [[ "$swap_line" =~ used[[:space:]]*=[[:space:]]*([^ ]+) ]]; then
  used_swap_mb="$(parse_to_mb "${BASH_REMATCH[1]}")"
fi
if [[ "$swap_line" =~ free[[:space:]]*=[[:space:]]*([^ ]+) ]]; then
  free_swap_mb="$(parse_to_mb "${BASH_REMATCH[1]}")"
fi

echo "Parsed swap MB: total=${total_swap_mb} used=${used_swap_mb} free=${free_swap_mb}"

echo ""
echo "=== Memory pressure (if available) ==="
if command -v memory_pressure >/dev/null 2>&1; then
  memory_pressure 2>/dev/null | head -15 || true
else
  echo "memory_pressure tool not present (OK on older macOS)"
fi

echo ""
echo "=== Disk free (swap needs free space on root) ==="
df -h / | tail -1

# Heuristic free RAM from vm_stat Pages free
free_pages="$(vm_stat | awk '/Pages free/ {gsub("\\.","",$3); print $3}')"
inactive_pages="$(vm_stat | awk '/Pages inactive/ {gsub("\\.","",$3); print $3}')"
free_pages="${free_pages:-0}"
inactive_pages="${inactive_pages:-0}"
approx_free_mb=$(( (free_pages + inactive_pages) * pagesize / 1024 / 1024 ))
echo "Approx reclaimable (free+inactive): ${approx_free_mb} MB"

echo ""
# Unsafe if very little reclaimable AND heavy swap used, or root almost full
root_avail_g="$(df -g / | awk 'NR==2{print $4}')"
root_avail_g="${root_avail_g:-99}"

unsafe=0
if (( approx_free_mb < 900 && used_swap_mb > 2048 )); then
  unsafe=1
fi
if (( root_avail_g < 5 )); then
  unsafe=1
  echo "WARN: root volume has <5GB free - macOS may struggle to grow swap."
fi

if (( unsafe == 1 )); then
  echo "VERDICT: UNSAFE / PRESSURE - run ./IF-CRASH-AGAIN.sh (safe orphan release)."
  exit 2
fi

echo "VERDICT: OK - memory/swap headroom looks usable."
exit 0
