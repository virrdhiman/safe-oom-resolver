#!/usr/bin/env bash
# Preview only - lists targets; changes nothing
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
"$ROOT/release-memory-safe.sh" --whatif "$@"
