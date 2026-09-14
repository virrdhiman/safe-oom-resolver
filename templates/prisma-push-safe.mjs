#!/usr/bin/env node
/**
 * Memory-safe Prisma db push for low-RAM Windows (no pagefile / tight commit).
 * - Caps Node heap from free physical RAM (never blindly asks for 8GB)
 * - Skips push when schema.prisma hash matches last successful local stamp
 * - Never deletes DB volumes, backups, or system files
 *
 * Env:
 *   FORCE_PRISMA_PUSH=1  — always run push
 *   PRISMA_HEAP_MB=2048  — override heap cap
 */
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, "..");
const schemaPath = path.join(root, "packages", "database", "prisma", "schema.prisma");
const prismaJs = path.join(root, "node_modules", "prisma", "build", "index.js");
const stampDir = path.join(root, ".tmp");
const stampPath = path.join(stampDir, "prisma-push.stamp.json");

function fail(msg, code = 1) {
  console.error(`[prisma-push-safe] ERROR: ${msg}`);
  process.exit(code);
}

function info(msg) {
  console.log(`[prisma-push-safe] ${msg}`);
}

function freePhysMB() {
  return Math.floor(os.freemem() / (1024 * 1024));
}

function totalPhysMB() {
  return Math.floor(os.totalmem() / (1024 * 1024));
}

/**
 * On Windows with no pagefile, physical free can look fine while commit
 * headroom (FreeVirtualMemory) is near zero — that is what crashes the editor.
 */
function freeCommitMB() {
  if (process.platform !== "win32") return freePhysMB();
  try {
    const ps = spawnSync(
      "powershell.exe",
      [
        "-NoProfile",
        "-Command",
        "(Get-CimInstance Win32_OperatingSystem).FreeVirtualMemory",
      ],
      { encoding: "utf8", windowsHide: true, timeout: 8000 }
    );
    const n = Number(String(ps.stdout || "").trim());
    // FreeVirtualMemory is KB
    if (Number.isFinite(n) && n > 0) return Math.floor(n / 1024);
  } catch {
    /* fall through */
  }
  return freePhysMB();
}

/** Pick a heap that fits commit headroom; never request 8GB on a 16GB box with no pagefile. */
function pickHeapMB() {
  const override = Number(process.env.PRISMA_HEAP_MB || "");
  if (Number.isFinite(override) && override >= 512) {
    return Math.floor(override);
  }
  const freePhys = freePhysMB();
  const freeCommit = freeCommitMB();
  const free = Math.min(freePhys, freeCommit);
  const total = totalPhysMB();
  // Leave ~1.25GB for OS + editor + Postgres; floor 1024, soft 3072 on this class of machine.
  const softCap = total < 24576 ? 3072 : 4096;
  const target = Math.min(softCap, Math.max(768, free - 1280));
  return target;
}

function schemaHash() {
  if (!existsSync(schemaPath)) fail(`schema missing: ${schemaPath}`);
  return createHash("sha256").update(readFileSync(schemaPath)).digest("hex");
}

function dbFingerprint() {
  const url = process.env.DATABASE_URL || "";
  // Avoid storing password; hash host/db only when parseable.
  try {
    const u = new URL(url);
    return createHash("sha256")
      .update(`${u.protocol}//${u.hostname}:${u.port}${u.pathname}`)
      .digest("hex")
      .slice(0, 16);
  } catch {
    return createHash("sha256").update(url).digest("hex").slice(0, 16);
  }
}

function readStamp() {
  if (!existsSync(stampPath)) return null;
  try {
    return JSON.parse(readFileSync(stampPath, "utf8"));
  } catch {
    return null;
  }
}

function writeStamp(hash, dbFp, heapMB) {
  if (!existsSync(stampDir)) mkdirSync(stampDir, { recursive: true });
  writeFileSync(
    stampPath,
    JSON.stringify(
      {
        schemaSha256: hash,
        dbFp,
        heapMB,
        at: new Date().toISOString(),
      },
      null,
      2
    ),
    "utf8"
  );
}

function main() {
  if (!existsSync(prismaJs)) fail(`prisma CLI missing: ${prismaJs} (run npm install)`);

  const hash = schemaHash();
  const dbFp = dbFingerprint();
  const force = process.env.FORCE_PRISMA_PUSH === "1" || process.argv.includes("--force");
  const stamp = readStamp();

  if (
    !force &&
    stamp &&
    stamp.schemaSha256 === hash &&
    stamp.dbFp === dbFp
  ) {
    info(`schema unchanged (${hash.slice(0, 12)}…) — skipping db push`);
    info("set FORCE_PRISMA_PUSH=1 to force");
    process.exit(0);
  }

  const freePhys = freePhysMB();
  const freeCommit = freeCommitMB();
  const free = Math.min(freePhys, freeCommit);
  const heapMB = pickHeapMB();
  info(
    `physFree≈${freePhys}MB commitFree≈${freeCommit}MB total≈${totalPhysMB()}MB → Node heap=${heapMB}MB`
  );

  // Commit headroom is the real crash signal when pagefile is disabled.
  if (freeCommit < 1200 || free < 900) {
    fail(
      `only ~${freeCommit}MB commit / ~${freePhys}MB phys free — refusing push to avoid system crash. ` +
        `Close Chrome/extra editor windows, then retry. ` +
        `Enable pagefile (Admin once): powershell -File scripts\\enable-pagefile-safe.ps1 then reboot. ` +
        `No system files were / will be deleted.`
    );
  }

  if (heapMB < 1536 || freeCommit < 3072) {
    info(
      "WARN: low commit headroom. Enable Windows pagefile so commit limit > physical RAM."
    );
  }

  const args = [
    `--max-old-space-size=${heapMB}`,
    prismaJs,
    "db",
    "push",
    `--schema=${schemaPath}`,
    "--skip-generate",
  ];

  info(`running: node ${args.join(" ")}`);
  const result = spawnSync(process.execPath, args, {
    cwd: root,
    stdio: "inherit",
    env: process.env,
    windowsHide: true,
  });

  if (result.error) fail(result.error.message);
  if (result.status !== 0) {
    fail(
      `db push exited ${result.status}. If Allocation failed / OOM: close browsers, enable pagefile, retry. Do not delete system files.`,
      result.status || 1
    );
  }

  writeStamp(hash, dbFp, heapMB);
  info(`OK — stamped ${stampPath}`);
}

const isDirectRun = process.argv[1]
  ? path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
  : false;
if (isDirectRun) main();
