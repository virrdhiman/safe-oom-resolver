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

### Windows
1. Close unused Chrome / extra editor windows (user-driven).
2. `RUN.bat` then if needed `IF-CRASH-AGAIN.bat` / `RELEASE-MEMORY.bat`.
3. Admin once: `RUN-ADMIN-PAGEFILE.bat` → reboot.
4. Use `templates/prisma-push-safe.mjs` instead of blind 8GB heaps.

### macOS
1. Close unused Chrome / extra editor windows (user-driven).
2. `mac/RUN.sh` then if needed `mac/IF-CRASH-AGAIN.sh`.
3. `mac/ensure-swap-safe.sh` — swap is automatic; free disk on `/` if low (never delete System folders).
4. Same Prisma safe template.

Release scripts stop only orphan Prisma/Node `db:push` leftovers and Playwright Chromium (optional browsers if you opt in). Never the editor, chats, desktop agents, OS, DB. Never delete files.

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
