#Requires -Version 5.1
<#
.SYNOPSIS
  Diagnose and safely remediate Windows OOM / editor crash conditions.
  NEVER deletes system files, user data, DB volumes, or agent chats.
#>
param(
  [switch]$SkipPagefileHint,
  [string]$ProjectRoot = ""
)

$ErrorActionPreference = "Continue"
$Root = $PSScriptRoot
Set-Location $Root

function Write-Step([string]$Message) {
  Write-Host "==> $Message" -ForegroundColor Cyan
}
function Write-Ok([string]$Message) {
  Write-Host "[OK] $Message" -ForegroundColor Green
}
function Write-Warn([string]$Message) {
  Write-Host "[WARN] $Message" -ForegroundColor Yellow
}
function Write-Err([string]$Message) {
  Write-Host "[ERROR] $Message" -ForegroundColor Red
}

Write-Step "Safety contract"
Write-Host "  - No system/user/DB/backup deletes"
Write-Host "  - No agent transcript deletes"
Write-Host "  - Pagefile enable only ADDS virtual memory"
Write-Host ""

& "$Root\scripts\diagnose.ps1"
$diagExit = $LASTEXITCODE

Write-Step "Commit pressure relief (report only - does not kill your browsers)"
& "$Root\scripts\report-memory-hogs.ps1"

$os = Get-CimInstance Win32_OperatingSystem
$freeCommitMB = [math]::Round($os.FreeVirtualMemory / 1024)
$totalVirtMB = [math]::Round($os.TotalVirtualMemorySize / 1024)
$totalPhysMB = [math]::Round($os.TotalVisibleMemorySize / 1024)
$hasPagefileHeadroom = $totalVirtMB -gt ($totalPhysMB + 512)

if (-not $hasPagefileHeadroom) {
  Write-Warn "Commit limit ~ physical RAM - Windows pagefile appears OFF/empty."
  Write-Warn "This is the usual root cause of editor/Prisma OOM crashes."
  if (-not $SkipPagefileHint) {
    Write-Host ""
    Write-Host "NEXT (required for permanent fix):" -ForegroundColor Yellow
    Write-Host "  1. Close extra Chrome / editor windows"
    Write-Host "  2. Right-click RUN-ADMIN-PAGEFILE.bat -> Run as administrator"
    Write-Host "  3. Reboot"
    Write-Host "  4. Re-run RUN.bat - commit free should be much higher"
  }
}

if ($ProjectRoot -and (Test-Path $ProjectRoot)) {
  Write-Step "Optional project check: $ProjectRoot"
  $scan = @(
    "package.json",
    "packages\database\package.json",
    "scripts\ensure-local-stack.ps1"
  )
  foreach ($rel in $scan) {
    $p = Join-Path $ProjectRoot $rel
    if (Test-Path $p) {
      $m = Select-String -Path $p -Pattern "max-old-space-size=8192" -SimpleMatch -ErrorAction SilentlyContinue
      if ($m) {
        Write-Warn "Found dangerous 8192MB heap pin in $rel"
        Write-Host "  Copy templates\prisma-push-safe.mjs into that repo and wire npm run db:push to it."
      }
    }
  }
}

Write-Step "Agent playbook location (for future chats)"
Write-Ok "agent\AGENTS.md + agent\PLAYBOOK.md - keep this repo; point future agents here"

if ($freeCommitMB -lt 1200) {
  Write-Err "Commit free ~${freeCommitMB}MB - still unsafe for Prisma/heavy Node."
  Write-Err "Close browsers and/or enable pagefile + reboot before retrying heavy work."
  exit 2
}

Write-Ok "Commit free ~${freeCommitMB}MB - safer for Node/Prisma/editor."
exit 0
