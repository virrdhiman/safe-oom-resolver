# safe-oom-resolver

One-click, **data-safe** fix for Windows “Allocation failed / process out of memory” crashes that take down your editor, Node, Prisma `db:push`, and agent chats.

**Never deletes** system files, user data, DB volumes, backups, pagefile contents, or agent transcripts.

## Quick run (Windows)

```bat
RUN.bat
```

Or:

```powershell
powershell -ExecutionPolicy Bypass -File .\resolve.ps1
```

Admin once (pagefile enable — **adds** virtual memory only):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\enable-pagefile-safe.ps1
```

Then reboot.

## What it fixes

| Symptom | Real cause | Safe fix |
|--------|------------|----------|
| Editor / agent “keeps crashing” mid-task | Commit limit ≈ RAM (no pagefile) + Chrome/editor pressure | Enable automatic pagefile; free commit; refuse huge Node heaps |
| Prisma `db:push` → `Allocation failed - process out of memory` | Scripts pinning `--max-old-space-size=8192` on 16GB boxes | Cap heap from **commit** free; skip unchanged schema |
| Prior “cleanup” wiped recovery data | Aggressive deletes | This kit **never** deletes OS/user/DB files |

## Layout

```
RUN.bat / resolve.ps1     ← operator entry
scripts/                  ← diagnose + pagefile + free-commit report
agent/                    ← playbook for future AI agents (preserve this chat’s lessons)
templates/                ← drop-in prisma-push-safe.mjs for monorepos
```

## Agent chat for the future

Read **`agent/AGENTS.md`** and **`agent/PLAYBOOK.md`** before touching memory, Prisma, or “cleanup” on any Virender machine.

## Safety contract

1. No `del` / `rm` of Windows system paths, `%SystemRoot%`, Program Files, user profiles, or recovery folders.
2. No wiping Postgres/Redis volumes, `Account.storageState`, OTP JSON, or backups.
3. Pagefile script only turns **on** automatic managed paging — it does not shrink disks or wipe files.
4. Prefer refuse + instruct over thrashing the machine into a crash.

## Origin story (2026-09-14)

Diagnosed on Flipkart suite local runs: physical free looked fine (~3.5GB) while **commit free** was ~0.8GB because **PagingFiles was empty**. Blind `--max-old-space-size=8192` crashed the session. Fix = commit-aware guards + enable pagefile + never delete system files.
