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

try {
  Log "==== pagefile enable start (SAFE - no deletes) ===="
  Log "Log file: $Log"

  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Not elevated. Right-click and Run as administrator."
  }
  Log "Elevated admin: YES"

  $mmPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
  $before = Get-ItemProperty -Path $mmPath
  Log ("Before registry AutomaticManagedPagefile={0} PagingFiles={1}" -f $before.AutomaticManagedPagefile, (($before.PagingFiles | Out-String).Trim()))

  $cs = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
  Log ("Before WMI AutomaticManagedPagefile={0}" -f $cs.AutomaticManagedPagefile)

  $cFreeGB = [math]::Round((Get-PSDrive C).Free / 1GB, 2)
  Log ("C: free space = {0} GB" -f $cFreeGB)
  if ($cFreeGB -lt 12) {
    throw "C: has only ${cFreeGB}GB free - need ~12GB+ for a safe pagefile. Free user-chosen files, then retry."
  }

  $ramMB = [int][math]::Round($cs.TotalPhysicalMemory / 1MB)
  $initialMB = [math]::Min(8192, [math]::Max(4096, $ramMB))
  $maximumMB = [math]::Min(24576, [math]::Max($initialMB + 4096, $ramMB * 2))
  Log ("RAM={0}MB -> pagefile Initial={1}MB Maximum={2}MB on C:\pagefile.sys" -f $ramMB, $initialMB, $maximumMB)

  # Step 1: turn off automatic via WMI (Put throws on failure; ignore return object shape)
  Log "Step 1: disable automatic managed pagefile (temporary)"
  $cs.AutomaticManagedPagefile = $false
  [void]$cs.Put()
  Log "Step 1 OK"

  # Step 2: remove broken/inactive settings (?:\pagefile.sys)
  Log "Step 2: remove existing Win32_PageFileSetting entries (config only)"
  Get-WmiObject Win32_PageFileSetting -ErrorAction SilentlyContinue | ForEach-Object {
    Log ("Removing PageFileSetting Name={0}" -f $_.Name)
    [void]$_.Delete()
  }
  Log "Step 2 OK"

  # Step 3: create explicit pagefile on C:
  Log "Step 3: create C:\pagefile.sys setting via WMI"
  [void](Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{
    Name        = "C:\pagefile.sys"
    InitialSize = [uint32]$initialMB
    MaximumSize = [uint32]$maximumMB
  })
  Log "Step 3 OK"

  # Step 4: registry mirror (what Windows reads at boot)
  $pfValue = "C:\pagefile.sys $initialMB $maximumMB"
  Log "Step 4: write registry PagingFiles=$pfValue"
  Set-ItemProperty -Path $mmPath -Name AutomaticManagedPagefile -Value 0 -Type DWord
  Set-ItemProperty -Path $mmPath -Name PagingFiles -Value ([string[]]@($pfValue))
  Log "Step 4 OK"

  $after = Get-ItemProperty -Path $mmPath
  Log ("After registry AutomaticManagedPagefile={0} PagingFiles={1}" -f $after.AutomaticManagedPagefile, (($after.PagingFiles | Out-String).Trim()))

  $settings = @(Get-WmiObject Win32_PageFileSetting -ErrorAction SilentlyContinue)
  if ($settings.Count -eq 0) {
    throw "PageFileSetting missing after create - elevation/WMI may be blocked."
  }
  foreach ($s in $settings) {
    Log ("After WMI PageFileSetting Name={0} Initial={1} Maximum={2}" -f $s.Name, $s.InitialSize, $s.MaximumSize)
  }

  Log "SUCCESS - REBOOT REQUIRED for pagefile to become active."
  Log "No system files deleted. No project/DB/agent data touched."
  Write-Host ""
  Write-Host "SUCCESS. Reboot this PC, then run RUN.bat to verify commit limit > RAM." -ForegroundColor Green
  Write-Host "Log: $Log" -ForegroundColor Cyan
  exit 0
}
catch {
  Log ("FAILED: " + $_.Exception.Message)
  Write-Host ""
  Write-Host ("FAILED: " + $_.Exception.Message) -ForegroundColor Red
  Write-Host "Log: $Log" -ForegroundColor Yellow
  exit 1
}
