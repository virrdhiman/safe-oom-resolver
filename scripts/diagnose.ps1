#Requires -Version 5.1
# Read-only memory / pagefile diagnosis. No deletes. No mutations.
$ErrorActionPreference = "Continue"

$os = Get-CimInstance Win32_OperatingSystem
$freePhysMB = [math]::Round($os.FreePhysicalMemory / 1024)
$totalPhysMB = [math]::Round($os.TotalVisibleMemorySize / 1024)
$freeVirtMB = [math]::Round($os.FreeVirtualMemory / 1024)
$totalVirtMB = [math]::Round($os.TotalVirtualMemorySize / 1024)

Write-Host "=== Memory ===" -ForegroundColor Cyan
Write-Host ("Physical free/total : {0} / {1} MB" -f $freePhysMB, $totalPhysMB)
Write-Host ("Virtual  free/total : {0} / {1} MB  (commit headroom = free virtual)" -f $freeVirtMB, $totalVirtMB)

try {
  Get-Counter '\Memory\Committed Bytes','\Memory\Commit Limit' -ErrorAction Stop |
    ForEach-Object {
      $_.CounterSamples | ForEach-Object {
        Write-Host ("{0} = {1:N2} GB" -f $_.Path, ($_.CookedValue / 1GB))
      }
    }
} catch { }

Write-Host ""
Write-Host "=== Pagefile ===" -ForegroundColor Cyan
$mm = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -ErrorAction SilentlyContinue
if ($mm) {
  Write-Host ("AutomaticManagedPagefile = {0}" -f $mm.AutomaticManagedPagefile)
  Write-Host ("PagingFiles = {0}" -f (($mm.PagingFiles | Out-String).Trim()))
} else {
  Write-Host "Could not read Memory Management key (permissions?)"
}

$pf = Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue
if ($pf) {
  $pf | Format-Table Name, AllocatedBaseSize, CurrentUsage, PeakUsage -AutoSize
} else {
  Write-Host "No Win32_PageFileUsage entries (often means pagefile disabled)." -ForegroundColor Yellow
}

$unsafe = ($totalVirtMB -le ($totalPhysMB + 512)) -or ($freeVirtMB -lt 1200)
if ($unsafe) {
  Write-Host ""
  Write-Host "VERDICT: UNSAFE for Prisma db:push / large Node heaps / heavy editor agents." -ForegroundColor Red
  exit 2
}

Write-Host ""
Write-Host "VERDICT: OK — commit headroom looks usable." -ForegroundColor Green
exit 0
