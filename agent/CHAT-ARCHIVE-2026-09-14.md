# Chat archive — OOM crash resolution (2026-09-14)

Preserved so future agents do not re-learn the hard way.

## User intent

- Resolve crashing permanently; frustration high.
- **Do not delete system files** — recovery previously took ~10 days.
- Later: create a **personal (`D:\pers`) repo** that resolves this class of error without data loss, and keep agent guidance for the future.

## What was wrong

- Host: ~16GB RAM Windows.
- **No pagefile** (`PagingFiles` empty) → commit limit ≈ physical RAM (~15.6GB).
- Commit free often **&lt; 1GB** while physical free looked ~3.5GB (misleading).
- Flipkart `ensure-local-stack.ps1` / database `push` pinned **`--max-old-space-size=8192`**, which thrash-crashed editor/agent sessions.
- Prior related chats: “Prisma harden + admingb fix”, “Resolve crashing issue”.

## What fixed it (code)

In `flipkart-automation-suite`:

- `scripts/prisma-push-safe.mjs` — heap from min(phys, commit) free; refuse if commit &lt; ~1.2GB; skip push if schema stamp unchanged.
- Removed blind 8192 heap from `packages/database` push + `ensure-local-stack.ps1`.
- `scripts/enable-pagefile-safe.ps1` — Admin enable automatic pagefile only.

## What still needs the human once

- Run Admin pagefile enable + **reboot** (OS-level permanent fix).
- Close extra Chrome/editor windows when commit free is tiny.

## Do not repeat

- Do not “clean” OS files to free RAM.
- Do not wipe DB/OTP during deploy or local fix.
- Do not move agent roots thrashing multi-root workspaces while the machine is already commit-starved (can abort mid-turn).

## This repo

`D:\pers\safe-oom-resolver` packages the diagnose/fix scripts + this archive for reuse on any project.
