#Requires -Version 5.1
<#
.SYNOPSIS
  Free commit/RAM pressure by stopping extra absorbing processes ONLY.
  NEVER deletes files, chats, DB data, or OS components.
  NEVER kills the editor (protects agent chats) or Windows system processes.

.PARAMETER IncludeBrowsers
  Also stop Chrome / Edge / Brave / Firefox (tabs close; browsing data is kept on disk).

.PARAMETER IncludeChatApps
  Also stop Discord / Slack / Teams desktop apps (not the editor).

.PARAMETER WhatIf
  Show what would be stopped; do not stop anything.

.PARAMETER MinMB
  Only consider processes using at least this many MB (default 80).
#>
param(
  [switch]$IncludeBrowsers,
  [switch]$IncludeChatApps,
  [switch]$WhatIf,
  [int]$MinMB = 80
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

function Get-CommitSnapshot {
  $os = Get-CimInstance Win32_OperatingSystem
  [pscustomobject]@{
    FreePhysMB   = [int][math]::Round($os.FreePhysicalMemory / 1024)
    FreeCommitMB = [int][math]::Round($os.FreeVirtualMemory / 1024)
    TotalPhysMB  = [int][math]::Round($os.TotalVisibleMemorySize / 1024)
    TotalVirtMB  = [int][math]::Round($os.TotalVirtualMemorySize / 1024)
  }
}

function Get-CmdLine([int]$ProcessId) {
  try {
    return (Get-CimInstance Win32_Process -Filter "ProcessId=$ProcessId" -ErrorAction Stop).CommandLine
  } catch {
    return $null
  }
}

function Test-IsProtectedProcess($proc) {
  $n = $proc.ProcessName
  # Windows / security / shell - never touch
  $never = @(
    'Idle', 'System', 'Registry', 'smss', 'csrss', 'wininit', 'services', 'lsass',
    'winlogon', 'fontdrvhost', 'dwm', 'Memory Compression', 'Secure System',
    'MsMpEng', 'NisSrv', 'SecurityHealthService', 'explorer', 'sihost', 'taskhostw',
    'RuntimeBroker', 'StartMenuExperienceHost', 'SearchHost', 'ShellExperienceHost',
    'TextInputHost', 'ctfmon', 'conhost', 'dllhost', 'svchost', 'SystemSettings',
    'ApplicationFrameHost', 'UserOOBEBroker', 'LockApp', 'LogonUI'
  )
  if ($never -contains $n) { return $true }

  # Protect THIS PowerShell and its parent chain lightly via name/path
  if ($proc.Id -eq $PID) { return $true }
  try {
    if ($proc.Id -eq (Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId) { return $true }
  } catch { }

  # Protect the editor entirely - agent chats / IDE
  if ($n -match '^(Cursor|Cursor Helper)') { return $true }
  if ($proc.Path -and ($proc.Path -match '[\\/]Cursor[\\/]|Programs\\cursor|cursor-agent')) { return $true }

  $cmd = Get-CmdLine $proc.Id
  if ($cmd -and ($cmd -match '[\\/]Cursor[\\/]|cursor-agent|Cursor\.exe')) { return $true }

  # Protect Windows system directories by path
  if ($proc.Path -and ($proc.Path -match '\\Windows\\System32\\|\\Windows\\SysWOW64\\|\\Windows\\SystemApps\\')) {
    return $true
  }

  return $false
}

function Test-IsReleaseCandidate($proc) {
  if (Test-IsProtectedProcess $proc) { return $false }

  $n = $proc.ProcessName.ToLowerInvariant()
  $cmd = Get-CmdLine $proc.Id
  $path = if ($proc.Path) { $proc.Path } else { '' }

  # Leftover Node / Bun / Playwright Chromium - but not editor-owned
  $isNodeFamily = ($n -in @('node', 'nodejs', 'bun', 'prisma')) -or
    ($n -match '^(chrome|chromium)$' -and ($cmd -match 'playwright|puppeteer|ms-playwright|flipkart|automation'))

  if ($isNodeFamily) {
    if ($cmd -match '[\\/]Cursor[\\/]|cursor-agent') { return $false }
    if ($path -match '[\\/]Cursor[\\/]') { return $false }
    return $true
  }

  if ($IncludeBrowsers) {
    if ($n -in @('chrome', 'msedge', 'msedgewebview2', 'brave', 'firefox', 'opera', 'vivaldi')) {
      # Keep Edge WebView if it looks like a system shell host - still usually safe to skip WebView2
      if ($n -eq 'msedgewebview2') { return $false }
      return $true
    }
  }

  if ($IncludeChatApps) {
    if ($n -in @('discord', 'slack', 'teams', 'ms-teams')) { return $true }
  }

  return $false
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " SAFE MEMORY RELEASE - no deletes, no OS damage, keep chats" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Protects: editor (agent chats), Windows system, Explorer, Defender"
Write-Host " May stop: leftover Node/Bun/Playwright; optional browsers"
Write-Host " Log: $Log"
Write-Host ""

$before = Get-CommitSnapshot
Log ("BEFORE freePhys={0}MB freeCommit={1}MB totalVirt={2}MB" -f $before.FreePhysMB, $before.FreeCommitMB, $before.TotalVirtMB)

$targets = @()
Get-Process -ErrorAction SilentlyContinue | ForEach-Object {
  $mb = [int][math]::Round($_.WorkingSet64 / 1MB)
  if ($mb -lt $MinMB) { return }
  if (-not (Test-IsReleaseCandidate $_)) { return }
  $targets += [pscustomobject]@{
    Name = $_.ProcessName
    Id   = $_.Id
    MB   = $mb
    Path = $_.Path
  }
}

$targets = $targets | Sort-Object MB -Descending

if ($targets.Count -eq 0) {
  Log "No safe release candidates found (MinMB=$MinMB). Editor/system left untouched."
  Write-Host "Nothing safe to stop. Close unused tabs manually if still low on memory." -ForegroundColor Yellow
  exit 0
}

Write-Host "Will stop these absorbing processes (safe list):" -ForegroundColor Yellow
$targets | Format-Table Name, Id, MB -AutoSize

$freedEstimate = ($targets | Measure-Object -Property MB -Sum).Sum
Log ("Candidates={0} estimatedWS~{1}MB IncludeBrowsers={2} IncludeChatApps={3} WhatIf={4}" -f $targets.Count, $freedEstimate, [bool]$IncludeBrowsers, [bool]$IncludeChatApps, [bool]$WhatIf)

if ($WhatIf) {
  Log "WhatIf only - no processes stopped."
  exit 0
}

$stopped = 0
$failed = 0
foreach ($t in $targets) {
  try {
    Stop-Process -Id $t.Id -Force -ErrorAction Stop
    Log ("STOPPED {0} pid={1} ~{2}MB" -f $t.Name, $t.Id, $t.MB)
    $stopped++
  } catch {
    Log ("SKIP {0} pid={1}: {2}" -f $t.Name, $t.Id, $_.Exception.Message)
    $failed++
  }
}

Start-Sleep -Seconds 2
$after = Get-CommitSnapshot
Log ("AFTER  freePhys={0}MB freeCommit={1}MB (was commit {2}MB)" -f $after.FreePhysMB, $after.FreeCommitMB, $before.FreeCommitMB)
Log ("Stopped={0} Failed={1}" -f $stopped, $failed)

Write-Host ""
Write-Host ("Stopped {0} process(es). Commit free: {1}MB -> {2}MB" -f $stopped, $before.FreeCommitMB, $after.FreeCommitMB) -ForegroundColor Green
Write-Host "Editor / agent chats / OS system processes were NOT touched." -ForegroundColor Green
Write-Host "No files deleted." -ForegroundColor Green

if ($after.FreeCommitMB -lt 1200) {
  Write-Host ""
  Write-Host "Still low commit. Next:" -ForegroundColor Yellow
  Write-Host "  1) Re-run with browsers:  RELEASE-MEMORY.bat  (choose Y for browsers)"
  Write-Host "  2) Confirm pagefile:     RUN.bat then RUN-ADMIN-PAGEFILE.bat if needed"
  Write-Host "  3) Reboot if pagefile was just enabled"
  exit 2
}

exit 0
