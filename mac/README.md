# macOS (same safety contract as Windows)

## Quick run

```bash
cd /path/to/safe-oom-resolver/mac
chmod +x *.sh    # first time only
./RUN.sh
```

If crashing / OOM pressure returns:

```bash
./IF-CRASH-AGAIN.sh
```

Memory only:

```bash
./RELEASE-MEMORY.sh
./RELEASE-MEMORY-WHATIF.sh   # preview
```

Swap check (macOS usually needs **no** pagefile-style enable):

```bash
./ensure-swap-safe.sh
```

## Windows vs Mac

| | Windows | macOS |
|--|---------|--------|
| Virtual memory | Pagefile (`RUN-ADMIN-PAGEFILE.bat` once + reboot) | Automatic swap (`ensure-swap-safe.sh` only checks) |
| If crash returns | `IF-CRASH-AGAIN.bat` | `mac/IF-CRASH-AGAIN.sh` |
| Never | Delete system/user/DB/chats | Same |

## Safety

Same as Windows: never deletes data/chats; never kills the editor or desktop agents; only safe orphans (Prisma/`db:push` leftovers, Playwright Chromium; optional browsers if you opt in).
