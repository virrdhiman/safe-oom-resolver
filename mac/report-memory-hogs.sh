#!/usr/bin/env bash
# PRJs runner | platform: mac | scope: repo-local
# Report top RAM consumers. Does NOT stop processes.
set -euo pipefail

echo "Top processes by RSS (MB) - informational only:"
ps -axo rss,pid,comm | sort -nr | head -15 | awk '{printf "%8.0f MB  pid=%-6s  %s\n", $1/1024, $2, $3}'
echo "Tip: quit unused Chrome tabs / extra editor windows yourself - this script does not."
