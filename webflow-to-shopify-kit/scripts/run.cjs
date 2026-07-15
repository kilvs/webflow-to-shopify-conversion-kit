#!/usr/bin/env node
/**
 * All-in-one orchestrator for the Webflow → Shopify conversion.
 *
 * Runs every automatable step in sequence. Unlike convert-all.sh (which
 * aborts on the first error), this runner CONTINUES on failure so you
 * get a full pass/fail picture at the end.
 *
 * Preconditions:
 *   - webflow-source/ exists (unzipped Webflow export)
 *   - webflow-to-shopify-kit/ lives at the project root
 *   - node available on PATH
 *   - Git Bash (Windows) OR bash (macOS/Linux) OR pwsh/powershell (Windows fallback)
 *
 * Usage (from project root):
 *   node webflow-to-shopify-kit/scripts/run.cjs
 *
 * Re-run safety:
 *   Most steps are fully idempotent — safe to re-run after any failure.
 *   ONE nuance: the "Bootstrap starter theme" step SKIPS files that
 *   already exist at the destination, so it won't clobber your
 *   hand-edited layout/theme.liquid or sections/header.liquid on re-run.
 *   Fresh files (like a newly-added starter-theme snippet in a kit update)
 *   still get copied.
 *
 * Cross-platform notes:
 *   - macOS/Linux/WSL: uses /bin/bash for the .sh scripts.
 *   - Windows: prefers Git Bash. WSL bash is auto-detected and IGNORED
 *     (it can't resolve Windows-style paths). Falls back to pwsh 7+ or
 *     Windows PowerShell 5.x for the .ps1 versions.
 *   - Legacy Windows console (cmd.exe / powershell.exe 5.x without
 *     Windows Terminal): output uses ASCII glyphs to avoid mojibake
 *     from the CP-437/1252 codepage. Windows Terminal / macOS / Linux
 *     get the Unicode box-drawing glyphs.
 *
 * Exit codes:
 *   0 — every pipeline step passed or was skipped as an idempotent no-op.
 *       Informational check-required-files warnings do NOT trigger exit 1.
 *   1 — preflight failure OR one or more pipeline steps failed.
 *
 * Safe to delete after conversion — every step can also be run standalone
 * (see webflow-to-shopify-kit/scripts/*).
 */

const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const ROOT = process.cwd();
const KIT_NAME = 'webflow-to-shopify-kit';
const KIT = path.join(ROOT, KIT_NAME);

// ─────────────────────────────────────────────────────────────────────────
// Glyph mode — ASCII fallback for legacy Windows consoles
// Windows Terminal sets WT_SESSION; PowerShell 7+ inherits UTF-8 codepage.
// Legacy conhost / powershell.exe 5.x on stock Windows default to CP-437
// or CP-1252 and render box-drawing chars as `â•â•â•`.
// ─────────────────────────────────────────────────────────────────────────
const ON_WINDOWS = process.platform === 'win32';
const USE_ASCII = ON_WINDOWS && !process.env.WT_SESSION;

const G = USE_ASCII
  ? { hr: '=', hrLight: '-', arrow: '>>', ok: '[OK]  ', fail: '[FAIL]', skip: '[SKIP]', warn: '[WARN]' }
  : { hr: '═', hrLight: '─', arrow: '▶',  ok: '✓',      fail: '✗',      skip: '⊘',      warn: '⚠' };

const HR = G.hr.repeat(72);
const hr = G.hrLight.repeat(72);

// ─────────────────────────────────────────────────────────────────────────
// Preflight
// ─────────────────────────────────────────────────────────────────────────
function preflight() {
  const errors = [];
  if (!fs.existsSync(path.join(ROOT, 'webflow-source'))) {
    errors.push('webflow-source/ not found at project root. Unzip your Webflow export there first.');
  }
  if (!fs.existsSync(KIT)) {
    errors.push(`${KIT_NAME}/ not found at project root. Copy the kit folder in first.`);
  }
  return errors;
}

// ─────────────────────────────────────────────────────────────────────────
// Shell detection: prefer Git Bash / real bash; reject WSL bash on Windows;
// fall back to pwsh / powershell for .ps1 scripts.
// ─────────────────────────────────────────────────────────────────────────
function cmdReturnsZero(cmd, args) {
  try {
    const res = spawnSync(cmd, args, { stdio: 'ignore' });
    return res.status === 0;
  } catch {
    return false;
  }
}

function detectBash() {
  // Basic availability check
  if (!cmdReturnsZero('bash', ['--version'])) return false;

  // On Windows, we need to make sure this isn't WSL bash (which can't
  // execute Windows-path .sh scripts). Git Bash / MSYS bash reports
  // OSTYPE as msys/cygwin; WSL bash reports linux-gnu.
  if (ON_WINDOWS) {
    try {
      const res = spawnSync('bash', ['-c', 'echo "$OSTYPE"'], { encoding: 'utf8' });
      const ostype = (res.stdout || '').trim().toLowerCase();
      // Accept: msys, cygwin. Reject: linux-gnu (WSL) and anything unknown.
      if (!ostype.includes('msys') && !ostype.includes('cygwin')) {
        return false;
      }
    } catch {
      return false;
    }
  }
  return true;
}

function detectPwsh() {
  if (cmdReturnsZero('pwsh', ['-NoProfile', '-Command', '$true'])) return 'pwsh';
  if (cmdReturnsZero('powershell', ['-NoProfile', '-Command', '$true'])) return 'powershell';
  return null;
}

const HAS_BASH = detectBash();
const PWSH_CMD = HAS_BASH ? null : detectPwsh();

// ─────────────────────────────────────────────────────────────────────────
// Step runners
// ─────────────────────────────────────────────────────────────────────────
function runShellScript(baseName) {
  if (HAS_BASH) {
    const scriptPath = path.join(KIT, 'scripts', `${baseName}.sh`);
    if (!fs.existsSync(scriptPath)) {
      console.error(`  ${G.fail} script not found: ${scriptPath}`);
      return 127;
    }
    const res = spawnSync('bash', [scriptPath], { stdio: 'inherit', cwd: ROOT });
    return res.status ?? 1;
  }
  if (PWSH_CMD) {
    const scriptPath = path.join(KIT, 'scripts', `${baseName}.ps1`);
    if (!fs.existsSync(scriptPath)) {
      console.error(`  ${G.fail} script not found: ${scriptPath}`);
      return 127;
    }
    const res = spawnSync(PWSH_CMD, ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', scriptPath], {
      stdio: 'inherit', cwd: ROOT,
    });
    return res.status ?? 1;
  }
  console.error(`  ${G.fail} no shell available (neither Git Bash nor pwsh/powershell)`);
  return 127;
}

function runNodeScript(scriptRelPath) {
  const scriptPath = path.join(KIT, 'scripts', scriptRelPath);
  if (!fs.existsSync(scriptPath)) {
    console.error(`  ${G.fail} script not found: ${scriptPath}`);
    return 127;
  }
  const res = spawnSync(process.execPath, [scriptPath], { stdio: 'inherit', cwd: ROOT });
  return res.status ?? 1;
}

// ─────────────────────────────────────────────────────────────────────────
// Bootstrap starter theme — IDEMPOTENT: skips files that already exist at
// destination so hand-edited layout/theme.liquid, sections/header.liquid,
// etc. survive re-runs. Newly-added starter-theme files (from a kit
// update) still get copied.
// ─────────────────────────────────────────────────────────────────────────
function copyDirRecursivePreserve(src, dest, stats) {
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const sPath = path.join(src, entry.name);
    const dPath = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      copyDirRecursivePreserve(sPath, dPath, stats);
    } else if (entry.isFile()) {
      if (fs.existsSync(dPath)) {
        stats.skipped.push(path.relative(ROOT, dPath));
      } else {
        fs.copyFileSync(sPath, dPath);
        stats.added.push(path.relative(ROOT, dPath));
      }
    }
  }
}
function bootstrapStarterTheme() {
  const src = path.join(KIT, 'starter-theme');
  if (!fs.existsSync(src)) {
    console.error(`  ${G.fail} ${src} not found`);
    return 1;
  }
  const stats = { added: [], skipped: [] };
  try {
    copyDirRecursivePreserve(src, ROOT, stats);
  } catch (err) {
    console.error(`  ${G.fail} copy failed: ${err.message}`);
    return 1;
  }
  console.log(`  ${G.ok} ${stats.added.length} added, ${stats.skipped.length} skipped (already present).`);
  if (stats.added.length > 0 && stats.added.length <= 12) {
    for (const f of stats.added) console.log(`      + ${f}`);
  } else if (stats.added.length > 12) {
    for (const f of stats.added.slice(0, 8)) console.log(`      + ${f}`);
    console.log(`      + …and ${stats.added.length - 8} more`);
  }
  if (stats.skipped.length > 0) {
    console.log(`      (skipped files were preserved — bootstrap never overwrites your edits)`);
  }
  return 0;
}

// ─────────────────────────────────────────────────────────────────────────
// Required-files check — Node-native so it works on any platform without
// a shell script. Two categories:
//   HARD = must exist (pipeline should have produced these)
//   SOFT = expected to be built by hand/AI after this orchestrator; missing
//          is a warning, not a failure.
// ─────────────────────────────────────────────────────────────────────────
const HARD_REQUIRED = [
  'layout/theme.liquid',
  'layout/password.liquid',
  'templates/index.json',
  'templates/404.json',
  'templates/password.json',
  'templates/gift_card.liquid',
  'templates/list-collections.json',
  'templates/cart.json',
  'templates/search.json',
  'templates/customers/account.liquid',
  'templates/customers/activate_account.liquid',
  'templates/customers/addresses.liquid',
  'templates/customers/login.liquid',
  'templates/customers/order.liquid',
  'templates/customers/register.liquid',
  'templates/customers/reset_password.liquid',
  'config/settings_schema.json',
  'config/settings_data.json',
  'locales/en.default.json',
];
// Templates the human authors after the orchestrator finishes — missing
// on a first run is expected, not a failure.
const SOFT_REQUIRED = [
  'templates/product.json',
  'templates/collection.json',
  'templates/page.json',
  'templates/blog.json',
  'templates/article.json',
];
function checkRequiredFiles() {
  const missingHard = HARD_REQUIRED.filter(f => !fs.existsSync(path.join(ROOT, f)));
  const missingSoft = SOFT_REQUIRED.filter(f => !fs.existsSync(path.join(ROOT, f)));

  if (missingHard.length === 0 && missingSoft.length === 0) {
    console.log(`  ${G.ok} All Shopify-required files present.`);
    return { code: 0, softMissing: [] };
  }

  if (missingHard.length > 0) {
    console.log(`  ${G.fail} ${missingHard.length} required file(s) missing (pipeline should have produced these):`);
    for (const f of missingHard) console.log(`      MISSING: ${f}`);
  }
  if (missingSoft.length > 0) {
    console.log(`  ${G.warn} ${missingSoft.length} template(s) not yet built (expected on first run — see TODO below):`);
    for (const f of missingSoft) console.log(`      TODO: ${f}`);
  }
  // Hard-missing is a real failure; soft-only-missing is informational (exit 0).
  return { code: missingHard.length > 0 ? 1 : 0, softMissing: missingSoft };
}

// ─────────────────────────────────────────────────────────────────────────
// Skip predicates + form detection
// ─────────────────────────────────────────────────────────────────────────
function skillsAlreadyInstalled() {
  return fs.existsSync(path.join(ROOT, '.agents/skills/shopify-dev')) &&
         fs.existsSync(path.join(ROOT, '.agents/skills/shopify-liquid'));
}

// Scan sections/ for every wf-form-* ID (Newsletter, Subscribe, Contact,
// Signup, etc.). Return { hasAnyWfForm, hasNewsletter, otherIds }.
function detectWebflowForms() {
  const sectionsDir = path.join(ROOT, 'sections');
  if (!fs.existsSync(sectionsDir)) {
    return { hasAnyWfForm: false, hasNewsletter: false, otherIds: [] };
  }
  const files = fs.readdirSync(sectionsDir).filter(f => f.endsWith('.liquid'));
  const idPattern = /id="(wf-form-[A-Za-z0-9_-]+)"/g;
  const found = new Set();
  for (const f of files) {
    let content;
    try { content = fs.readFileSync(path.join(sectionsDir, f), 'utf8'); } catch { continue; }
    let m;
    while ((m = idPattern.exec(content)) !== null) found.add(m[1]);
  }
  const hasNewsletter = found.has('wf-form-Newsletter-Form');
  const otherIds = [...found].filter(id => id !== 'wf-form-Newsletter-Form');
  return { hasAnyWfForm: found.size > 0, hasNewsletter, otherIds };
}

// ─────────────────────────────────────────────────────────────────────────
// Step definitions
// ─────────────────────────────────────────────────────────────────────────
let formInfo = null;  // populated by the form step's skip check
const STEPS = [
  {
    label: 'Install Shopify AI skills',
    skip: skillsAlreadyInstalled,
    skipReason: 'already installed at .agents/skills/',
    run: () => runShellScript('install-skills'),
  },
  {
    label: 'Audit Webflow source → AUDIT.md',
    run: () => runShellScript('audit-source'),
  },
  {
    label: 'Flatten Webflow assets → assets/',
    run: () => runShellScript('flatten-assets'),
  },
  {
    label: 'Bootstrap starter theme (preserves your edits on re-run)',
    run: bootstrapStarterTheme,
  },
  {
    label: 'Extract page content → sections + templates',
    run: () => runNodeScript('convert.cjs'),
  },
  {
    label: 'Convert Webflow newsletter forms',
    skip: () => {
      formInfo = detectWebflowForms();
      return !formInfo.hasNewsletter;
    },
    skipReason: () => {
      if (!formInfo.hasAnyWfForm) return 'no wf-form-* IDs found in sections/';
      return `no wf-form-Newsletter-Form (but found ${formInfo.otherIds.join(', ')} — convert those manually or extend convert-forms.cjs)`;
    },
    run: () => runNodeScript('convert-forms.cjs'),
  },
  {
    label: 'Verify Shopify-required files',
    informational: true,       // soft-missing templates don't count as failure
    run: () => {
      const { code, softMissing } = checkRequiredFiles();
      // Stash soft-missing for the final TODO block
      formInfo && (formInfo._softMissing = softMissing);
      return code;
    },
  },
];

// ─────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────
const errs = preflight();
if (errs.length > 0) {
  console.error('');
  console.error('Preflight failed:');
  for (const e of errs) console.error(`  ${G.fail} ${e}`);
  console.error('');
  process.exit(1);
}
if (!HAS_BASH && !PWSH_CMD) {
  console.error('');
  console.error('No usable shell available.');
  console.error('  - On Windows: install Git for Windows (brings Git Bash) OR PowerShell 7+.');
  console.error('  - WSL bash on Windows is auto-detected and skipped (cannot resolve Windows paths).');
  console.error('  - On macOS/Linux: install bash if it is missing (it usually is not).');
  console.error('');
  process.exit(1);
}

const shellLabel = HAS_BASH ? 'bash (Git Bash / MSYS / native)' : PWSH_CMD;

console.log('');
console.log(HR);
console.log('  Webflow -> Shopify conversion');
console.log(HR);
console.log(`  Kit:   ${KIT_NAME}/`);
console.log(`  Shell: ${shellLabel}`);
console.log(`  Glyphs:${USE_ASCII ? ' ASCII (legacy Windows console)' : ' Unicode'}`);
console.log(`  Steps: ${STEPS.length}`);
console.log(HR);

const results = [];
const t0 = Date.now();

for (let i = 0; i < STEPS.length; i++) {
  const step = STEPS[i];
  const n = i + 1;
  console.log('');
  console.log(`${G.arrow} Step ${n}/${STEPS.length}: ${step.label}`);
  console.log(hr);

  let skipReason = null;
  try {
    if (step.skip && step.skip()) {
      skipReason = typeof step.skipReason === 'function' ? step.skipReason() : step.skipReason;
    }
  } catch (err) {
    console.error(`  ${G.fail} skip predicate threw: ${err.message}`);
    results.push({ label: step.label, status: 'failed', duration: 0, code: 1 });
    continue;
  }
  if (skipReason !== null) {
    console.log(`  ${G.skip} SKIPPED - ${skipReason}`);
    results.push({ label: step.label, status: 'skipped', duration: 0 });
    continue;
  }

  const start = Date.now();
  let code;
  try {
    code = step.run();
    if (typeof code !== 'number') code = 0;
  } catch (err) {
    console.error(`  ${G.fail} threw: ${err.message}`);
    code = 1;
  }
  const duration = Date.now() - start;
  let status;
  let symbol;
  if (code === 0) {
    status = 'ok';
    symbol = G.ok;
  } else if (step.informational) {
    status = 'warned';
    symbol = G.warn;
  } else {
    status = 'failed';
    symbol = G.fail;
  }
  console.log('');
  console.log(`  ${symbol} ${status.toUpperCase()} (exit ${code}, ${(duration / 1000).toFixed(1)}s)`);
  results.push({ label: step.label, status, duration, code, informational: !!step.informational });
}

// Summary
const totalDur = Date.now() - t0;
console.log('');
console.log(HR);
console.log('  Summary');
console.log(HR);
console.log('');
for (const r of results) {
  const sym = r.status === 'ok' ? G.ok
            : r.status === 'warned' ? G.warn
            : r.status === 'skipped' ? G.skip
            : G.fail;
  const time = r.duration > 0 ? ` (${(r.duration / 1000).toFixed(1)}s)` : '';
  const codePart = (r.status === 'failed' || r.status === 'warned') ? ` [exit ${r.code}]` : '';
  console.log(`  ${sym} ${r.label}${time}${codePart}`);
}
console.log('');

const okCount = results.filter(r => r.status === 'ok').length;
const failedCount = results.filter(r => r.status === 'failed').length;
const warnedCount = results.filter(r => r.status === 'warned').length;
const skippedCount = results.filter(r => r.status === 'skipped').length;
console.log(`  ${okCount} passed, ${failedCount} failed, ${warnedCount} warned, ${skippedCount} skipped. Total: ${(totalDur / 1000).toFixed(1)}s`);
console.log('');

// Hand-off — ALWAYS print if pipeline steps succeeded (even if verifier warned).
// A "failed" (non-informational) step still triggers the exit-1 path below.
if (failedCount === 0) {
  console.log('  ' + G.ok + ' Automated steps complete.');
  console.log('');
  console.log('  Still TODO (judgement calls — hand to Claude Code / another AI');
  console.log(`  agent using ${KIT_NAME}/CONVERT_PROMPT.md as the brief, or do by hand`);
  console.log('  per CONVERSION_GUIDE.md):');
  console.log('');
  console.log('  * Fill placeholders in layout/theme.liquid (paste values from AUDIT.md):');
  console.log('      <YOUR_WF_SITE_ID>       (data-wf-site constant)');
  console.log('      <WF_PAGE_*>             (per-template data-wf-page IDs)');
  console.log('      <WEBFLOW_BUNDLE>.js     (JS bundle filename)');
  console.log('      site.css                (rename to your primary CSS filename)');
  console.log('  * Build sections/header.liquid + sections/footer.liquid');
  console.log('      (lift markup from webflow-source/index.html, wrap with {% schema %})');
  console.log('  * Wire commerce in sections/page-product.liquid +');
  console.log('      sections/page-collection.liquid (see CONVERSION_GUIDE.md §E)');
  console.log('  * (Optional) Split homepage into per-block sections:');
  console.log(`      node ${KIT_NAME}/scripts/split-page.cjs`);
  if (warnedCount > 0) {
    console.log('');
    console.log('  Note: the verifier warned about missing templates (product.json,');
    console.log('  collection.json, page.json, blog.json, article.json). These are');
    console.log('  expected — they get built as part of the TODO above.');
  }
  console.log('');
  console.log('  Then: commit + push + connect Shopify + import products + publish.');
  console.log('');
  process.exit(0);
}

// Real failures — print actionable message
console.log('  ' + G.warn + ' One or more pipeline steps failed. Fix the underlying issue');
console.log('    (see logs above) and re-run — most steps are safely idempotent.');
console.log('    Bootstrap step preserves existing files so your hand edits are safe.');
console.log('');
process.exit(1);
