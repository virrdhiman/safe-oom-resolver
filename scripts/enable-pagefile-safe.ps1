# Enable a REAL Windows pagefile safely (adds virtual memory only).
# Does NOT delete system files, user data, DB volumes, backups, or chats.
#
# Run elevated:
#   powershell -ExecutionPolicy Bypass -File scripts\enable-pagefile-safe.ps1
# Or: RUN-ADMIN-PAGEFILE.bat

#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$LogDir = Join-Path $Root "logs"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }
$Log = Join-Path $LogDir "pagefile-enable.log"

function Log([string]$Message) {
  $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
  Add-Content -Path $Log -Value $line
  Write-Host $line
}

Log "==== pagefile enable start (SAFE - no deletes) ===="
Log "Log file: $Log"

$mmPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
$before = Get-ItemProperty -Path $mmPath
Log ("Before registry AutomaticManagedPagefile={0} PagingFiles={1}" -f $before.AutomaticManagedPagefile, (($before.PagingFiles | Out-String).Trim()))

$cs = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
Log ("Before WMI AutomaticManagedPagefile={0}" -f $cs.AutomaticManagedPagefile)

# Disk check - we only create pagefile on C: if enough free space
$cFreeGB = [math]::Round((Get-PSDrive C).Free / 1GB, 2)
Log ("C: free space = {0} GB" -f $cFreeGB)
if ($cFreeGB -lt 12) {
  throw "C: has only ${cFreeGB}GB free - need ~12GB+ to create a safe pagefile. Free some disk (user files you choose), then retry. No system deletes performed."
}

$ramMB = [int][math]::Round($cs.TotalPhysicalMemory / 1MB)
# Conservative sizes: initial ~RAM (capped), max ~2x RAM (capped 24GB)
$initialMB = [math]::Min(8192, [math]::Max(4096, $ramMB))
$maximumMB = [math]::Min(24576, [math]::Max($initialMB + 4096, $ramMB * 2))
Log ("RAM={0}MB -> pagefile Initial={1}MB Maximum={2}MB on C:\pagefile.sys" -f $ramMB, $initialMB, $maximumMB)

# 1) Turn OFF automatic so we can set an explicit healthy pagefile
Log "Step 1: disable automatic managed pagefile (temporary)"
$cs.AutomaticManagedPagefile = $false
$put1 = $cs.Put()
Log ("Put(disable auto) ReturnValue={0}" -f $put1.ReturnValue)
if ($put1.ReturnValue -ne 0) { throw "Failed to disable automatic pagefile. ReturnValue=$($put1.ReturnValue)" }

# 2) Remove broken/empty pagefile settings (?:\pagefile.sys often means inactive)
Log "Step 2: remove existing Win32_PageFileSetting entries (config only, not your documents)"
Get-WmiObject Win32_PageFileSetting -ErrorAction SilentlyContinue | ForEach-Object {
  Log ("Removing PageFileSetting Name={0}" -f $_.Name)
  $_.Delete() | Out-Null
}

# 3) Create explicit pagefile on C:
Log "Step 3: create C:\pagefile.sys setting"
$null = Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{
  Name        = "C:\pagefile.sys"
  InitialSize = [uint32]$initialMB
  MaximumSize = [uint32]$maximumMB
}

# Also write registry multi-string for consistency
$pfValue = "C:\pagefile.sys $initialMB $maximumMB"
Set-ItemProperty -Path $mmPath -Name PagingFiles -Value @($pfValue)
Set-ItemProperty -Path $mmPath -Name AutomaticManagedPagefile -Value 0 -Type DWord
Log "Registry PagingFiles set to: $pfValue"

$after = Get-ItemProperty -Path $mmPath
$settings = Get-WmiObject Win32_PageFileSetting -ErrorAction SilentlyContinue
Log ("After registry AutomaticManagedPagefile={0} PagingFiles={1}" -f $after.AutomaticManagedPagefile, (($after.PagingFiles | Out-String).Trim()))
if ($settings) {
  foreach ($s in @($settings)) {
    Log ("After WMI PageFileSetting Name={0} Initial={1} Maximum={2}" -f $s.Name, $s.InitialSize, $s.MaximumSize)
  }
} else {
  Log "WARN: Win32_PageFileSetting empty after set - reboot may still apply registry"
}

Log "SUCCESS - REBOOT REQUIRED for pagefile to become active."
Log "No system files deleted. No project/DB/agent data touched."
Write-Host ""
Write-Host "SUCCESS. Reboot this PC, then run RUN.bat to verify commit limit > RAM." -ForegroundColor Green
Write-Host "Log: $Log" -ForegroundColor Cyan
exit 0
