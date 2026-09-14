# Enable Windows automatic pagefile safely.
# WHY: With PagingFiles empty, commit limit == physical RAM. Prisma/Node then
# OOMs and can crash the editor + agent chats. This ADDS virtual memory; it does NOT
# delete system files, user data, DB volumes, backups, or transcripts.
#
# Run once elevated, then reboot:
#   powershell -ExecutionPolicy Bypass -File scripts\enable-pagefile-safe.ps1
# Or: RUN-ADMIN-PAGEFILE.bat

#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

Write-Host "==> Enabling Windows automatic managed pagefile (SAFE - no deletes)" -ForegroundColor Cyan

$mmPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
$before = Get-ItemProperty -Path $mmPath
Write-Host "Before: AutomaticManagedPagefile=$($before.AutomaticManagedPagefile) PagingFiles=$($before.PagingFiles)"

try {
  $cs = Get-CimInstance Win32_ComputerSystem
  $null = Invoke-CimMethod -InputObject $cs -MethodName Set -Arguments @{ AutomaticManagedPagefile = $true }
} catch {
  $sys = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
  $sys.AutomaticManagedPagefile = $true
  $result = $sys.Put()
  if ($result.ReturnValue -ne 0) {
    throw "Win32_ComputerSystem.Put failed with ReturnValue=$($result.ReturnValue)"
  }
}

Set-ItemProperty -Path $mmPath -Name AutomaticManagedPagefile -Value 1 -Type DWord -ErrorAction SilentlyContinue

$after = Get-ItemProperty -Path $mmPath
Write-Host "After: AutomaticManagedPagefile=$($after.AutomaticManagedPagefile) PagingFiles=$($after.PagingFiles)" -ForegroundColor Green
Write-Host ""
Write-Host "REBOOT REQUIRED for pagefile to take effect." -ForegroundColor Yellow
Write-Host "After reboot, commit limit should be > physical RAM."
Write-Host "No system files were deleted. Agent chats / project data untouched."
