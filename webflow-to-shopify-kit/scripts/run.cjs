#!/usr/bin/env node
/**
 * All-in-one orchestrator for the Webflow → Shopify conversion.
 *
 * Runs every automatable step in sequence. Unlike convert-all.sh (which
 * aborts on the first error), this runner CONTINUES on failure so you
 * get a full pass/fail picture at the end — not "step 3 died, no idea
 * about the rest." Every step is idempotent, so re-running after fixing
 * the underlying issue is safe.
 *
 * Preconditions:
 *   - webflow-source/ exists (unzipped Webflow export)
 *   - webflow-to-shopify-kit/ lives at the project root
 *   - node available on PATH
 *   - bash available (Git Bash on Windows) OR pwsh/powershell available
 *
 * Usage (from project root):
 *   node webflow-to-shopify-kit/scripts/run.cjs
 *
 * Cross-platform notes:
 *   - macOS/Linux: uses /bin/bash for the .sh scripts.
 *   - Windows: uses Git Bash if `bash` is on PATH (comes with Git for
 *     Windows). If not, falls back to invoking the .ps1 versions via
 *     `pwsh` (PowerShell 7+) or `powershell` (Windows PowerShell 5.x).
 *
 * Exit codes:
 *   0 — every step passed or was skipped as an idempotent no-op.
 *   1 — preflight failure OR one or more steps failed. Summary at end
 *       shows which.
 *
 * Safe to delete after conversion — every step can also be run
 * standalone (see webflow-to-shopify-kit/scripts/*).
 */

const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const ROOT = process.cwd();
const KIT_NAME = 'webflow-to-shopify-kit';
const KIT = path.join(ROOT, KIT_NAME);

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
  const nodeCheck = spawnSync(process.execPath, ['--version'], { stdio: 'ignore' });
  if (nodeCheck.status !== 0) {
    errors.push('node binary check failed (very unusual — this script itself is node).');
  }
  return errors;
}

// ─────────────────────────────────────────────────────────────────────────
// Shell detection: bash preferred, PowerShell fallback
// ─────────────────────────────────────────────────────────────────────────
function cmdAvailable(cmd, args) {
  try {
    const res = spawnSync(cmd, args, { stdio: 'ignore' });
    return res.status === 0;
  } catch {
    return false;
  }
}
const HAS_BASH = cmdAvailable('bash', ['--version']);
let PWSH_CMD = null;
if (!HAS_BASH) {
  if (cmdAvailable('pwsh', ['-NoProfile', '-Command', '$true'])) PWSH_CMD = 'pwsh';
  else if (cmdAvailable('powershell', ['-NoProfile', '-Command', '$true'])) PWSH_CMD = 'powershell';
}

// ─────────────────────────────────────────────────────────────────────────
// Step runners
// ─────────────────────────────────────────────────────────────────────────
function runShellScript(baseName) {
  // baseName = 'install-skills' → picks .sh via bash OR .ps1 via powershell
  if (HAS_BASH) {
    const scriptPath = path.join(KIT, 'scripts', `${baseName}.sh`);
    if (!fs.existsSync(scriptPath)) {
      console.error(`  ✗ script not found: ${scriptPath}`);
      return 127;
    }
    const res = spawnSync('bash', [scriptPath], { stdio: 'inherit', cwd: ROOT });
    return res.status ?? 1;
  }
  if (PWSH_CMD) {
    const scriptPath = path.join(KIT, 'scripts', `${baseName}.ps1`);
    if (!fs.existsSync(scriptPath)) {
      console.error(`  ✗ script not found: ${scriptPath}`);
      return 127;
    }
    const res = spawnSync(PWSH_CMD, ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', scriptPath], {
      stdio: 'inherit', cwd: ROOT,
    });
    return res.status ?? 1;
  }
  console.error('  ✗ no shell available (neither bash nor pwsh/powershell)');
  return 127;
}

function runNodeScript(scriptRelPath) {
  const scriptPath = path.join(KIT, 'scripts', scriptRelPath);
  if (!fs.existsSync(scriptPath)) {
    console.error(`  ✗ script not found: ${scriptPath}`);
    return 127;
  }
  const res = spawnSync(process.execPath, [scriptPath], { stdio: 'inherit', cwd: ROOT });
  return res.status ?? 1;
}

// Bootstrap starter theme — Node-native recursive copy so we don't need
// cp / robocopy / xcopy across platforms
function copyDirRecursive(src, dest) {
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const sPath = path.join(src, entry.name);
    const dPath = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      copyDirRecursive(sPath, dPath);
    } else if (entry.isFile()) {
      fs.copyFileSync(sPath, dPath);
    }
  }
}
function bootstrapStarterTheme() {
  const src = path.join(KIT, 'starter-theme');
  if (!fs.existsSync(src)) {
    console.error(`  ✗ ${src} not found`);
    return 1;
  }
  try {
    copyDirRecursive(src, ROOT);
    console.log(`  ✓ starter-theme/ copied into project root`);
    return 0;
  } catch (err) {
    console.error(`  ✗ copy failed: ${err.message}`);
    return 1;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Skip predicates
// ─────────────────────────────────────────────────────────────────────────
function skillsAlreadyInstalled() {
  return fs.existsSync(path.join(ROOT, '.agents/skills/shopify-dev')) &&
         fs.existsSync(path.join(ROOT, '.agents/skills/shopify-liquid'));
}
function hasNewsletterForm() {
  const sectionsDir = path.join(ROOT, 'sections');
  if (!fs.existsSync(sectionsDir)) return false;
  const files = fs.readdirSync(sectionsDir).filter(f => f.endsWith('.liquid'));
  return files.some(f => {
    try {
      const content = fs.readFileSync(path.join(sectionsDir, f), 'utf8');
      return content.includes('wf-form-Newsletter-Form');
    } catch {
      return false;
    }
  });
}

// ─────────────────────────────────────────────────────────────────────────
// Step definitions
// ─────────────────────────────────────────────────────────────────────────
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
    label: 'Bootstrap starter theme',
    run: bootstrapStarterTheme,
  },
  {
    label: 'Extract page content → sections + templates',
    run: () => runNodeScript('convert.cjs'),
  },
  {
    label: 'Convert Webflow newsletter forms',
    skip: () => !hasNewsletterForm(),
    skipReason: 'no wf-form-Newsletter-Form found in sections/',
    run: () => runNodeScript('convert-forms.cjs'),
  },
  {
    label: 'Verify Shopify-required files',
    run: () => runShellScript('check-required-files'),
  },
];

// ─────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────
const HR = '═'.repeat(72);
const hr = '─'.repeat(72);

const errs = preflight();
if (errs.length > 0) {
  console.error('');
  console.error('Preflight failed:');
  for (const e of errs) console.error(`  ✗ ${e}`);
  console.error('');
  process.exit(1);
}
if (!HAS_BASH && !PWSH_CMD) {
  console.error('');
  console.error('No shell available. Install Git for Windows (which brings Git Bash)');
  console.error('or PowerShell (pwsh 7+ or powershell 5.x). Then re-run.');
  console.error('');
  process.exit(1);
}

const shellLabel = HAS_BASH ? 'bash' : PWSH_CMD;

console.log('');
console.log(HR);
console.log('  Webflow → Shopify conversion');
console.log(HR);
console.log(`  Kit:   ${KIT_NAME}/`);
console.log(`  Shell: ${shellLabel}`);
console.log(`  Steps: ${STEPS.length}`);
console.log(HR);

const results = [];
const t0 = Date.now();

for (let i = 0; i < STEPS.length; i++) {
  const step = STEPS[i];
  const n = i + 1;
  console.log('');
  console.log(`▶ Step ${n}/${STEPS.length}: ${step.label}`);
  console.log(hr);

  if (step.skip && step.skip()) {
    console.log(`  ⊘ SKIPPED — ${step.skipReason}`);
    results.push({ label: step.label, status: 'skipped', duration: 0 });
    continue;
  }

  const start = Date.now();
  let code;
  try {
    code = step.run();
    if (typeof code !== 'number') code = 0;
  } catch (err) {
    console.error(`  ✗ threw: ${err.message}`);
    code = 1;
  }
  const duration = Date.now() - start;
  const status = code === 0 ? 'ok' : 'failed';
  const symbol = code === 0 ? '✓' : '✗';
  console.log('');
  console.log(`  ${symbol} ${status.toUpperCase()} (exit ${code}, ${(duration / 1000).toFixed(1)}s)`);
  results.push({ label: step.label, status, duration, code });
}

// Summary
const totalDur = Date.now() - t0;
console.log('');
console.log(HR);
console.log('  Summary');
console.log(HR);
console.log('');
for (const r of results) {
  const sym = r.status === 'ok' ? '✓' : r.status === 'skipped' ? '⊘' : '✗';
  const time = r.duration > 0 ? ` (${(r.duration / 1000).toFixed(1)}s)` : '';
  const codePart = r.status === 'failed' ? ` [exit ${r.code}]` : '';
  console.log(`  ${sym} ${r.label}${time}${codePart}`);
}
console.log('');

const ok = results.filter(r => r.status === 'ok').length;
const failed = results.filter(r => r.status === 'failed').length;
const skipped = results.filter(r => r.status === 'skipped').length;
console.log(`  ${ok} passed, ${failed} failed, ${skipped} skipped. Total: ${(totalDur / 1000).toFixed(1)}s`);
console.log('');

if (failed > 0) {
  console.log('  ⚠ One or more steps failed. Fix the underlying issue (see logs above)');
  console.log('    and re-run — every step is idempotent so re-runs are safe.');
  console.log('');
  process.exit(1);
}

// Success — surface follow-up work
console.log('  ✓ Automated steps complete.');
console.log('');
console.log('  Still TODO (judgement calls — hand to Claude Code / other AI agent');
console.log(`  with ${KIT_NAME}/CONVERT_PROMPT.md as the brief):`);
console.log('');
console.log('  • Fill placeholders in layout/theme.liquid (paste values from AUDIT.md)');
console.log('  • Build sections/header.liquid + sections/footer.liquid');
console.log('    (lift from webflow-source/index.html, wrap with schema)');
console.log('  • Wire commerce in sections/page-product.liquid +');
console.log('    sections/page-collection.liquid');
console.log('  • (Optional) Split homepage into per-block sections via');
console.log(`    node ${KIT_NAME}/scripts/split-page.cjs`);
console.log('');
console.log('  Then: commit + push + connect Shopify + import products + publish.');
console.log('');
