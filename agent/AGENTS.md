# Agent guide — safe-oom-resolver

**Start here** before “fixing crashes”, “freeing disk”, or running Prisma/`db:push` on Virender Windows machines.

Full playbook: [`PLAYBOOK.md`](PLAYBOOK.md)  
Chat archive (this incident): [`CHAT-ARCHIVE-2026-09-14.md`](CHAT-ARCHIVE-2026-09-14.md)

## Hard rules

1. **Never delete system files**, recovery folders, pagefile, user profiles, or “to free space” OS trees. Data recovery took **10+ days** once — do not repeat.
2. **Never wipe** Postgres/Redis volumes, OTP JSON, `Account.storageState`, backups, or `.env`.
3. Treat editor/agent aborts + Prisma `Allocation failed` as **commit exhaustion**, not “corrupt install”.
4. Prefer `D:\pers\safe-oom-resolver\RUN.bat` (Windows) or `.../mac/RUN.sh` (macOS) before inventing cleanup scripts.
5. If OOM returns: `IF-CRASH-AGAIN.bat` / `mac/IF-CRASH-AGAIN.sh` only — never kill the editor/desktop agents; never delete chats/data.
6. Do not pin Node `--max-old-space-size=8192` on ≤16GB machines without working swap/pagefile.

## Quick diagnose

```powershell
powershell -ExecutionPolicy Bypass -File D:\pers\safe-oom-resolver\scripts\diagnose.ps1
```

If virtual free ≪ physical free, or commit limit ≈ RAM → enable pagefile (Admin) + reboot.

## Related project fix

Flipkart suite already has `scripts/prisma-push-safe.mjs` pattern — also copied under `templates/` in this repo.
