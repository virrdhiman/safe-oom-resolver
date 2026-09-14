# safe-oom-resolver

One-click, **data-safe** fix for Windows **and macOS** “Allocation failed / process out of memory” crashes that take down your editor, Node, Prisma `db:push`, and agent chats.

**Never deletes** system files, user data, DB volumes, backups, pagefile/swap contents, or agent transcripts.

## Quick run (Windows)

```bat
RUN.bat
```

If crashing / OOM pressure returns later:

```bat
IF-CRASH-AGAIN.bat
```

Or memory-only:

```bat
RELEASE-MEMORY.bat
```

Preview:

```bat
RUN-RELEASE-MEMORY-WHATIF.bat
```

That release path **stops only safe orphans** (leftover Prisma/`db:push` Node, Playwright Chromium; optional browsers if you say Y). It does **not** kill your editor, chats, desktop agents, OS, Postgres/Redis — and **never deletes** files.

## Quick run (macOS)

```bash
cd mac
chmod +x *.sh
./RUN.sh
```

If pressure returns:

```bash
./IF-CRASH-AGAIN.sh
```

Details: [`mac/README.md`](mac/README.md). macOS swap is automatic (no Windows-style pagefile enable). Scripts only diagnose + release safe orphans — same no-delete / protect-editor rules.

Admin once (Windows pagefile enable — **adds** virtual memory only):

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
RUN.bat / resolve.ps1              <- diagnose (+ auto safe release if commit low)
RUN-RELEASE-MEMORY.bat             <- if OOM returns: stop safe orphans only
RUN-RELEASE-MEMORY-WHATIF.bat      <- preview targets
RUN-ADMIN-PAGEFILE.bat             <- once: create C:\pagefile.sys (reboot)
scripts/                           <- diagnose, pagefile, release-safe-memory
agent/                             <- playbook + chat archive for future agents
templates/                         <- prisma-push-safe.mjs drop-in
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
