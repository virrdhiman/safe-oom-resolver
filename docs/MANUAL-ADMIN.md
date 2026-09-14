# Manual Admin fallback (if RUN-ADMIN-PAGEFILE.bat UAC fails)
#
# 1. Start Menu -> type PowerShell -> right-click Windows PowerShell -> Run as administrator
# 2. Paste:
#
#    powershell -ExecutionPolicy Bypass -File "D:\pers\safe-oom-resolver\scripts\enable-pagefile-safe.ps1"
#
# 3. Read logs\pagefile-enable.log
# 4. Reboot
# 5. Run RUN.bat - commit limit should be > physical RAM
#
# This only creates/configures C:\pagefile.sys. It does not delete OS/user/DB data.
