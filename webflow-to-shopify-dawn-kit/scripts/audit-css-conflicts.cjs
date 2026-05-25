#!/usr/bin/env node
/**
 * Reports CSS class selectors that appear in BOTH the Dawn and Webflow CSS
 * bundles. Informational only — cascade layers (declared in theme.liquid as
 * `@layer dawn, webflow;`) resolve conflicts automatically. This audit
 * surfaces the overlap so future "why does .button look weird on the cart
 * page" debugging has a starting point.
 *
 * How it works:
 *   1. Scans assets/*.css.
 *   2. Determines each file's layer by reading the leading
 *      `@layer dawn { ... }` or `@layer webflow { ... }` line (possibly
 *      after an `@charset` declaration).
 *      Files without a wrapping layer are reported as "unwrapped" and
 *      treated as Webflow-side (the kit's default — flatten-assets wraps
 *      Webflow CSS as part of its normal flow).
 *   3. Extracts class selectors via `\.classname` regex (CSS comments
 *      stripped first to avoid false positives).
 *   4. Computes the intersection.
 *   5. Writes / updates a `## CSS conflicts (Dawn ∩ Webflow)` section in
 *      AUDIT.md at the project root.
 *
 * Run AFTER flatten-assets.{sh,ps1} and merge-dawn-commerce.{sh,ps1} so that
 * every CSS file has its layer prefix in place.
 *
 * Usage (from project root):
 *   node webflow-to-shopify-dawn-kit/scripts/audit-css-conflicts.cjs
 *
 * Safe to delete after the conversion is finalized — re-runs only refresh
 * the AUDIT.md section.
 */
const fs = require('fs');
const path = require('path');

const ROOT = process.cwd();
const ASSETS = path.join(ROOT, 'assets');

if (!fs.existsSync(ASSETS)) {
  console.error('assets/ not found. Run flatten-assets + merge-dawn-commerce first.');
  process.exit(1);
}

function stripBom(s) {
  return s.charCodeAt(0) === 0xFEFF ? s.slice(1) : s;
}

function detectLayer(content) {
  // Allow optional BOM (already stripped) + optional @charset before the @layer
  const m = content.match(/^\s*(?:@charset\s+["'][^"']+["']\s*;\s*)?@layer\s+([a-zA-Z][\w-]*)\s*\{/);
  return m ? m[1] : null;
}

function classesInCSS(content) {
  // Strip block comments first
  const stripped = content.replace(/\/\*[\s\S]*?\*\//g, '');
  const out = new Set();
  const re = /\.([a-zA-Z_][\w-]*)/g;
  let m;
  while ((m = re.exec(stripped)) !== null) {
    out.add(m[1]);
  }
  return out;
}

const dawnClasses = new Set();
const webflowClasses = new Set();
const unwrappedFiles = [];

const cssFiles = fs.readdirSync(ASSETS).filter(f => f.toLowerCase().endsWith('.css'));

if (cssFiles.length === 0) {
  console.log('No .css files in assets/ — nothing to audit.');
  process.exit(0);
}

for (const f of cssFiles) {
  const content = stripBom(fs.readFileSync(path.join(ASSETS, f), 'utf8'));
  const layer = detectLayer(content);
  const classes = classesInCSS(content);

  if (layer === 'dawn') {
    for (const c of classes) dawnClasses.add(c);
  } else if (layer === 'webflow') {
    for (const c of classes) webflowClasses.add(c);
  } else {
    unwrappedFiles.push(f);
    // Treat unwrapped as Webflow by default (kit default for unflagged CSS)
    for (const c of classes) webflowClasses.add(c);
  }
}

const overlap = [...dawnClasses].filter(c => webflowClasses.has(c)).sort();

// Build report body
let report = '';
report += `_${cssFiles.length} CSS file(s) scanned in \`assets/\` — `;
report += `${dawnClasses.size} unique Dawn classes, ${webflowClasses.size} unique Webflow classes._\n\n`;

if (unwrappedFiles.length > 0) {
  report += `**Unwrapped files** (no \`@layer\` prefix — counted as Webflow):\n\n`;
  for (const u of unwrappedFiles) report += `- \`${u}\`\n`;
  report += `\nRun \`flatten-assets\` to wrap these in \`@layer webflow\`.\n\n`;
}

if (overlap.length === 0) {
  report += `**No overlapping class names.** Cascade layers have nothing to resolve.\n`;
} else {
  report += `**${overlap.length} overlapping class name(s).** Webflow's \`@layer webflow\` wins on these per the layer order declared in \`layout/theme.liquid\`. If a commerce page (Dawn) renders correctly but a brand page (Webflow) looks off — or vice versa — one of these may be the culprit.\n\n`;
  report += '```\n';
  for (const c of overlap) report += `.${c}\n`;
  report += '```\n';
}

// Splice into AUDIT.md
const auditPath = path.join(ROOT, 'AUDIT.md');
const sectionHeader = '## CSS conflicts (Dawn ∩ Webflow)';
let existing = '';
if (fs.existsSync(auditPath)) {
  existing = fs.readFileSync(auditPath, 'utf8');
  const startIdx = existing.indexOf(sectionHeader);
  if (startIdx !== -1) {
    // Remove the old section (header through start of next `## ` or EOF)
    const after = existing.slice(startIdx + sectionHeader.length);
    const nextSec = after.search(/\n##\s/);
    const endIdx = nextSec === -1 ? existing.length : startIdx + sectionHeader.length + nextSec;
    const before = existing.slice(0, startIdx).replace(/\s+$/, '');
    const afterRest = existing.slice(endIdx).replace(/^\s+/, '');
    existing = afterRest ? before + '\n\n' + afterRest : before;
  }
}

const newContent =
  (existing.trim() ? existing.trim() + '\n\n' : '# Audit\n\n') +
  sectionHeader + '\n\n' +
  report.trim() + '\n';

fs.writeFileSync(auditPath, newContent, 'utf8');

console.log(`✓ Wrote CSS conflict audit to AUDIT.md`);
console.log(`  Dawn classes: ${dawnClasses.size}`);
console.log(`  Webflow classes: ${webflowClasses.size}`);
console.log(`  Overlap: ${overlap.length}`);
if (unwrappedFiles.length > 0) {
  console.log(`  Unwrapped files: ${unwrappedFiles.length} (treated as Webflow)`);
}
