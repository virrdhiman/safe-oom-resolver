# Playbook — Windows OOM / editor crash (no data loss)

## Symptoms

- Editor agent stops mid-turn / “keeps crashing”
- Node: `FATAL ERROR: Reached heap limit` or `Allocation failed - process out of memory`
- Prisma `db:push` dies even when Postgres password is fine
- Machine feels fine at first (physical RAM free) then freezes

## Diagnosis checklist

1. Physical free vs **virtual/commit free**
   - `Get-CimInstance Win32_OperatingSystem | select FreePhysicalMemory,FreeVirtualMemory,TotalVisibleMemorySize,TotalVirtualMemorySize`
2. Pagefile
   - Registry: `HKLM\...\Memory Management` → `PagingFiles` empty + commit limit == RAM ⇒ **no pagefile**
3. Dangerous scripts
   - Search for `--max-old-space-size=8192` in monorepo bats/ps1/package.json

## Remediation order (safe)

1. Close unused Chrome / extra editor windows (user-driven; do not force-kill without asking).
2. Run `RUN.bat` from this repo (diagnose + guidance).
3. If pressure returns later: `RUN-RELEASE-MEMORY.bat` (or `-WHATIF` first).
   - Stops only orphan Prisma/Node `db:push` leftovers and Playwright Chromium.
   - Never kills the editor, chats, desktop agents, OS, DB, or normal Chrome.
   - Never deletes files or transcripts.
4. Admin once: `RUN-ADMIN-PAGEFILE.bat` → **reboot**.
5. Replace blind 8GB Prisma heap with commit-aware push (see `templates/prisma-push-safe.mjs`).
6. Skip redundant `db:push` when schema hash unchanged.

## Forbidden “fixes”

- Deleting WinSxS, System32, pagefile.sys manually, user Documents “to free space”
- `docker volume rm` / wiping `postgres/data` / OTP JSON
- Disk Cleanup of unknown folders without explicit user approval
- Raising heap above available **commit** headroom

## Verify success

After reboot:

```powershell
Get-Counter '\Memory\Commit Limit'
# Should be meaningfully > physical RAM (e.g. 20–30GB on a 16GB machine)
```

Then re-run project `db:push` / agent work.
