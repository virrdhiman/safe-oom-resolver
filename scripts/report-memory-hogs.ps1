#Requires -Version 5.1
# Report top RAM consumers. Does NOT stop processes (avoids killing your work).
$ErrorActionPreference = "Continue"

Write-Host "Top processes by Working Set (MB) — informational only:" -ForegroundColor Cyan
Get-Process |
  Sort-Object WorkingSet64 -Descending |
  Select-Object -First 12 Name, Id, @{N='MB';E={[math]::Round($_.WorkingSet64/1MB)}} |
  Format-Table -AutoSize

Write-Host "Tip: closing unused Chrome tabs / extra editor windows frees commit without deleting files." -ForegroundColor DarkGray
