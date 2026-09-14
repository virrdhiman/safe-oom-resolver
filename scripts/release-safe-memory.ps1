#Requires -Version 5.1
<#
.SYNOPSIS
  If OOM pressure returns: free commit by stopping ONLY safe orphan absorbers.
  NEVER kills the editor, desktop agents, chats, browsers you are using for work,
  or OS/system processes. NEVER deletes files/data.

.PARAMETER WhatIf
  List targets only; do not stop anything.

.PARAMETER AlsoTrimWorkingSets
  Soft-trim working sets of non-protected apps (does not close them).
#>
param(
  [switch]$WhatIf,
  [switch]$AlsoTrimWorkingSets
)

$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent $PSScriptRoot
$LogDir = Join-Path $Root "logs"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }
$Log = Join-Path $LogDir "release-memory.log"

function Log([string]$Message) {
  $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
  Add-Content -Path $Log -Value $line
  Write-Host $line
}

function Get-CommitFreeMB {
  $os = Get-CimInstance Win32_OperatingSystem
  return [int][math]::Round($os.FreeVirtualMemory / 1024)
}

# Paths / names we NEVER touch (editor chats + desktop agents + OS)
$ProtectedNameExact = @(
  'Cursor', 'Code', 'Code - Insiders',
  'explorer', 'dwm', 'csrss', 'winlogon', 'services', 'lsass', 'svchost',
  'System', 'Registry', 'Memory Compression', 'MsMpEng', 'NisSrv',
  'Secure System', 'Idle', 'fontdrvhost', 'sihost', 'taskhostw',
  'SearchHost', 'StartMenuExperienceHost', 'ShellExperienceHost',
  'OneDrive', 'Docker Desktop', 'com.docker.backend', 'vpnkit',
  'postgres', 'redis-server', 'Memurai', 'memurai'
)

$ProtectedPathSubstrings = @(
  '\Cursor\',
  '\Programs\cursor\',
  '\Desktop Agent\',
  '\desktop-agent\',
  '\Windows\System32\',
  '\Windows\SysWOW64\',
  '\Windows\SystemApps\',
  '\Windows Defender\',
  '\Microsoft Security Client\'
)

# Safe to stop ONLY when command line / path looks like orphan automation/build leftovers
$KillNameAllow = @('node', 'nodejs', 'prisma', 'chrome', 'chromium', 'msedge')

function Test-IsProtected([System.Diagnostics.Process]$Proc, [string]$Path, [string]$Cmd) {
  $name = $Proc.ProcessName
  foreach ($n in $ProtectedNameExact) {
    if ($name -ieq $n) { return $true }
  }
  if ($Path) {
    foreach ($s in $ProtectedPathSubstrings) {
      if ($Path -like ("*" + $s + "*")) { return $true }
    }
  }
  # Editor helper nodes / Electron
  if ($Cmd -match '(?i)\\Cursor\\|Cursor\.exe|cursor-agent|desktop.?agent') { return $true }
  if ($Path -match '(?i)\\Cursor\\') { return $true }
  # Never kill interactive user Chrome/Edge unless playwright/headless markers present
  return $false
}

function Get-CimCmdLine([int]$Pid) {
  try {
    $c = Get-CimInstance Win32_Process -Filter ("ProcessId={0}" -f $Pid) -ErrorAction Stop
    return @{ Path = $c.ExecutablePath; CommandLine = $c.CommandLine }
  } catch {
    return @{ Path = $null; CommandLine = $null }
  }
}

function Test-IsSafeOrphan([string]$Name, [string]$Path, [string]$Cmd) {
  $n = $Name.ToLowerInvariant()
  $cmd = if ($Cmd) { $Cmd } else { "" }
  $path = if ($Path) { $Path } else { "" }

  # Prisma CLI leftovers
  if ($n -eq 'node' -or $n -eq 'nodejs') {
    if ($cmd -match '(?i)prisma|db push|db:push|ensure-local-stack|prisma-push-safe') { return $true }
    if ($cmd -match '(?i)tsc -w|typescript.*--watch') { return $true }
    # Stray node with no window and huge heap flags from bad scripts
    if ($cmd -match '(?i)max-old-space-size=(8192|16384)') { return $true }
    # node in temp crash dumps tooling - still leave generic node alone
    return $false
  }

  if ($n -eq 'prisma') { return $true }

  # Playwright / Puppeteer Chromium only (not normal Chrome browsing)
  if ($n -eq 'chrome' -or $n -eq 'chromium' -or $n -eq 'msedge') {
    if ($cmd -match '(?i)playwright|puppeteer|headless|user-data-dir=.*(flipkart|pw-|playwright|tmp\\\\|\\\\tmp\\\\)') {
      return $true
    }
    if ($path -match '(?i)\\playwright\\|\\puppeteer\\|\\.cache\\ms-playwright\\') {
      return $true
    }
    return $false
  }

  return $false
}

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class WsTrim {
  [DllImport("psapi.dll")]
  public static extern bool EmptyWorkingSet(IntPtr hProcess);
}
"@ -ErrorAction SilentlyContinue

function Trim-WorkingSetSafe([System.Diagnostics.Process]$Proc) {
  try {
    $Proc.Refresh()
    [void][WsTrim]::EmptyWorkingSet($Proc.Handle)
    return $true
  } catch {
    return $false
  }
}

# --- main ---
$before = Get-CommitFreeMB
Log "==== release-safe-memory start (no deletes, protect editor/chats/agents) ===="
Log ("Commit free before: {0} MB" -f $before)
Log ("Mode: WhatIf={0} AlsoTrimWorkingSets={1}" -f $WhatIf.IsPresent, $AlsoTrimWorkingSets.IsPresent)

$stopped = @()
$skipped = @()
$trimmed = @()

Get-Process -ErrorAction SilentlyContinue | ForEach-Object {
  $p = $_
  $meta = Get-CimCmdLine -Pid $p.Id
  $path = $meta.Path
  $cmd = $meta.CommandLine

  if (Test-IsProtected -Proc $p -Path $path -Cmd $cmd) {
    return
  }

  $name = $p.ProcessName
  if ($KillNameAllow -notcontains $name) {
    # Optional soft trim for large non-protected apps (e.g. leftover tools) - never kill
    if ($AlsoTrimWorkingSets -and $p.WorkingSet64 -gt 300MB) {
      if (-not $WhatIf) {
        if (Trim-WorkingSetSafe $p) { $trimmed += ("{0} pid={1}" -f $name, $p.Id) }
      } else {
        $trimmed += ("(whatif trim) {0} pid={1}" -f $name, $p.Id)
      }
    }
    return
  }

  if (-not (Test-IsSafeOrphan -Name $name -Path $path -Cmd $cmd)) {
    $skipped += ("keep {0} pid={1} (not a safe orphan)" -f $name, $p.Id)
    return
  }

  $mb = [math]::Round($p.WorkingSet64 / 1MB)
  $desc = "{0} pid={1} ~{2}MB" -f $name, $p.Id, $mb
  if ($WhatIf) {
    Log ("WOULD STOP: {0}" -f $desc)
    $stopped += ("(whatif) " + $desc)
    return
  }

  try {
    Stop-Process -Id $p.Id -Force -ErrorAction Stop
    Log ("STOPPED: {0}" -f $desc)
    $stopped += $desc
  } catch {
    Log ("FAILED stop {0}: {1}" -f $desc, $_.Exception.Message)
  }
}

Start-Sleep -Seconds 2
$after = Get-CommitFreeMB
Log ("Stopped count: {0}" -f $stopped.Count)
Log ("Commit free after: {0} MB (was {1} MB)" -f $after, $before)

if ($stopped.Count -eq 0) {
  Write-Host ""
  Write-Host "No safe orphan absorbers found to stop." -ForegroundColor Yellow
  Write-Host "Protected on purpose: editor, chats, desktop agents, OS, Postgres/Redis, normal Chrome." -ForegroundColor DarkGray
  Write-Host "If still tight after reboot: close unused Chrome tabs yourself (script will not)." -ForegroundColor DarkGray
} else {
  Write-Host ""
  Write-Host ("Released {0} safe orphan process(es). Commit free {1}MB -> {2}MB" -f $stopped.Count, $before, $after) -ForegroundColor Green
}

Write-Host "Log: $Log" -ForegroundColor Cyan
Write-Host "Editor / desktop agents / chats / user data: untouched." -ForegroundColor Green

# Exit 0 even if nothing stopped - this is a helper, not a hard failure
exit 0
