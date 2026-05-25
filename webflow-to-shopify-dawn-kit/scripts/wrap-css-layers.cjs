#!/usr/bin/env node
/**
 * Wraps every .css file in a directory inside `@layer <name> { ... }`.
 *
 * Used by:
 *   - flatten-assets.{sh,ps1}      → wraps Webflow CSS in @layer webflow
 *   - merge-dawn-commerce.{sh,ps1} → wraps Dawn CSS in @layer dawn
 *
 * The @layer order declared in layout/theme.liquid is `@layer dawn, webflow;`
 * which makes later layers win on conflict. So Webflow's brand styles override
 * Dawn's on any class that both define. (Dawn templates don't use Webflow
 * class names, so on commerce pages there's typically nothing to override.)
 *
 * Behavior:
 *   - Idempotent: skips files that already start with `@layer`.
 *   - Preserves `@charset` if present (it must remain at the very top of
 *     the file or browsers ignore it).
 *   - Preserves BOM (U+FEFF) if present (re-emits at top before @charset/@layer).
 *
 * Usage:
 *   node webflow-to-shopify-dawn-kit/scripts/wrap-css-layers.cjs <dir> <layer-name>
 *
 * Example:
 *   node webflow-to-shopify-dawn-kit/scripts/wrap-css-layers.cjs assets webflow
 *   node webflow-to-shopify-dawn-kit/scripts/wrap-css-layers.cjs assets dawn
 *
 * Safe to delete after the conversion is finalized — re-running is harmless
 * because of the idempotency check.
 */
const fs = require('fs');
const path = require('path');

const [, , targetDir, layerName] = process.argv;

if (!targetDir || !layerName) {
  console.error('Usage: wrap-css-layers.cjs <dir> <layer-name>');
  process.exit(1);
}

if (!/^[a-z][a-z0-9-]*$/.test(layerName)) {
  console.error(`Invalid layer name "${layerName}". Use lowercase letters/digits/hyphens.`);
  process.exit(1);
}

const ROOT = process.cwd();
const dir = path.isAbsolute(targetDir) ? targetDir : path.join(ROOT, targetDir);

if (!fs.existsSync(dir)) {
  console.error(`Directory not found: ${dir}`);
  process.exit(1);
}

const BOM = '﻿';

function wrapFile(filePath) {
  let raw = fs.readFileSync(filePath, 'utf8');

  // Detect + strip BOM
  let hasBom = false;
  if (raw.charCodeAt(0) === 0xFEFF) {
    hasBom = true;
    raw = raw.slice(1);
  }

  // Extract leading @charset if present (must stay at file top)
  let charset = '';
  const charsetMatch = raw.match(/^\s*@charset\s+["'][^"']+["']\s*;\s*/);
  if (charsetMatch) {
    charset = charsetMatch[0].trim() + '\n';
    raw = raw.slice(charsetMatch[0].length);
  }

  // Idempotency: if remaining content begins with @layer (any name), skip.
  // Run this AFTER stripping @charset so a file like:
  //   @charset "UTF-8";
  //   @layer webflow { ... }
  // is detected as already wrapped.
  if (/^\s*@layer\s+[A-Za-z0-9_-]+\s*\{/.test(raw)) {
    return { skipped: true, reason: 'already wrapped' };
  }

  const wrapped =
    (hasBom ? BOM : '') +
    charset +
    `@layer ${layerName} {\n` +
    raw +
    (raw.endsWith('\n') ? '' : '\n') +
    '}\n';

  fs.writeFileSync(filePath, wrapped, 'utf8');
  return { skipped: false };
}

const cssFiles = fs.readdirSync(dir)
  .filter(f => f.toLowerCase().endsWith('.css'))
  .map(f => path.join(dir, f));

if (cssFiles.length === 0) {
  console.log(`No .css files in ${dir} — nothing to wrap.`);
  process.exit(0);
}

let wrapped = 0;
let skipped = 0;
for (const file of cssFiles) {
  const result = wrapFile(file);
  if (result.skipped) {
    skipped++;
  } else {
    wrapped++;
    console.log(`  @layer ${layerName} { ... }   ${path.relative(ROOT, file)}`);
  }
}

console.log(`\nDone. ${wrapped} file(s) wrapped, ${skipped} skipped (already wrapped).`);
