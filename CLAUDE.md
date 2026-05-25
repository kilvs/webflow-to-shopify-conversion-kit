# Claude / AI assistant guide (kit-maintainer repo)

This is the repo for **two** sibling conversion kits that turn Webflow exports into Shopify themes. AI assistants working on this repo are usually doing one of:

1. **Maintaining a kit** — fixing bugs, adding scripts, refining docs
2. **Using a kit on a real project** — running the conversion end-to-end for a brand

For #2, read the kit's own `CONVERT_PROMPT.md`, not this file. This file is for #1 — the kit-maintenance use case.

> **Before doing anything, know which kit you're working on:**
>
> - **Pure Webflow** (`webflow-to-shopify-kit/`) — byte-identical visual parity for every page. Read [`webflow-to-shopify-kit/CONVERSION_GUIDE.md`](webflow-to-shopify-kit/CONVERSION_GUIDE.md) and [`webflow-to-shopify-kit/CONVERT_PROMPT.md`](webflow-to-shopify-kit/CONVERT_PROMPT.md).
> - **Dawn-augmented** (`webflow-to-shopify-dawn-kit/`) — Webflow for brand pages, Dawn for commerce. Read [`webflow-to-shopify-dawn-kit/DAWN_INTEGRATION.md`](webflow-to-shopify-dawn-kit/DAWN_INTEGRATION.md) and [`webflow-to-shopify-dawn-kit/CONVERT_PROMPT.md`](webflow-to-shopify-dawn-kit/CONVERT_PROMPT.md).
>
> If the question is about the Webflow-side mechanics (assets flattening, page extraction, form conversion, Shopify schema gotchas), both kits share the same recipe — `webflow-to-shopify-kit/CONVERSION_GUIDE.md` is canonical. The Dawn kit adds a thin layer of integration logic documented in `DAWN_INTEGRATION.md`.

---

## Critical rules (cause real bugs if violated)

These apply to **both kits** unless flagged otherwise.

1. **Don't modify Webflow CSS or JS.** `assets/*.css` and the `*-dev.js` bundle are preserved verbatim. Style overrides go in theme settings → Custom CSS, or in a new layered CSS file loaded AFTER the Webflow files.
2. **Don't modify Dawn CSS or JS** (Dawn-augmented kit only). Same reasoning — Dawn's web components are tightly coupled to specific class names and event names.
3. **The cascade-layer wrapping IS a narrow, documented exception** (Dawn-augmented kit only). Each Webflow CSS file is wrapped in `@layer webflow { ... }`; each Dawn CSS file in `@layer dawn { ... }`. Applied mechanically by the scripts. Don't unwrap manually.
4. **Don't rename a Webflow class.** Class names are load-bearing for CSS AND for the bundled JS. (Same for Dawn classes in the Dawn variant.)
5. **Don't strip `data-wf-*` attributes** from any element. Webflow's interactions key off them. (Dawn-augmented kit: don't rename Dawn's web component tags either — `<cart-drawer>`, `<product-form>`, `<variant-radios>`, `<predictive-search>`.)
6. **Inside `{% liquid %}` tags: one statement per line.** Semicolons are NOT valid separators — they cause silent parse failure that Shopify reports as the misleading "missing required file layout/theme.liquid" error.
7. **Section schema `tag` must be a valid value.** Allowed: `article`, `aside`, `div`, `footer`, `header`, `section`, or property omitted. `null` silently kills rendering — Shopify drops the section with no error. Always grep `"tag":\s*null` before pushing.
8. **`{% sections %}` (plural) ≠ `{% section %}` (singular).** Plural loads a section GROUP via `sections/<name>.json` manifest. Singular renders a single section file `sections/<name>.liquid` directly. AI assistants regularly swap them. Verify the file extension (.json vs .liquid) at the path being called.
9. **Every block-based section needs an `{% else %}` fallback** inside its `{% for block in section.blocks %}` loop, with the original Webflow markup verbatim. Pair with running `scripts/seed-template-blocks.cjs` to seed block instances into the template JSONs. Both are required — missing either causes blank sections.
10. **Color settings should not have `default` values** unless verified against the actual CSS — wrong defaults override the dark-theme Webflow CSS and make text invisible.
11. **Check AUDIT.md** before configuring scripts. Page filenames (`product-page.html` vs `product-template.html`), form IDs (`wf-form-Subscribe-Form` vs `wf-form-Newsletter-Form`), Webflow JS bundle name, primary CSS filename all vary per export. The kit scripts have defaults that won't match every project.
12. **Dawn version pin lives in two places** (Dawn-augmented kit only): `pull-dawn.{sh,ps1}` and `check-dawn-updates.{sh,ps1}`. Keep in sync when bumping. Bump deliberately — Dawn ships breaking changes.

---

## Conventions you must follow

- **Commit messages**: Conventional Commits (`type(scope): summary`). Keep summary ≤ 72 chars; body explains *why*. No `git add` instructions — just the message body in a copyable block.
- **Don't bundle unrelated changes** into one commit. Asset re-flattening and template edits are independent; split them. (Dawn kit: don't bundle a Dawn pin bump with Webflow-side work either.)
- **Surface flagged-out-of-scope work** (gotchas the user might miss) rather than silently fixing everything.
- **Don't ask permission to read** `CONVERSION_GUIDE.md` / `CONVERT_PROMPT.md` / `DAWN_INTEGRATION.md` / installed Shopify AI skills — read them when relevant.
- **Always run the validators** before reporting a task done:

      bash <kit-folder>/scripts/check-required-files.sh
      node -e "const fs=require('fs');for(const f of fs.readdirSync('sections').filter(x=>x.endsWith('.liquid'))){const c=fs.readFileSync('sections/'+f,'utf8');const m=c.match(/\{%\s*schema\s*%\}([\s\S]*?)\{%\s*endschema\s*%\}/);if(m){try{JSON.parse(m[1])}catch(e){console.log(f+': '+e.message)}}}"

  Dawn kit also runs:

      node webflow-to-shopify-dawn-kit/scripts/audit-css-conflicts.cjs
      bash webflow-to-shopify-dawn-kit/scripts/check-dawn-updates.sh  # informational

---

## What to do when unsure

1. Re-read the relevant section of the kit's guide:
   - Pure Webflow: `webflow-to-shopify-kit/CONVERSION_GUIDE.md`
   - Dawn-augmented: `webflow-to-shopify-dawn-kit/DAWN_INTEGRATION.md`
2. Check the Shopify AI skills installed in `.agents/skills/` (run `bash <kit-folder>/scripts/install-skills.sh` if missing).
3. **Surface the question to the user** rather than guess. Real examples: "Which collection should the product slider source from?" / "Are subscriptions live on this store?" / "Where do swatch hex colors come from — metafield or app?" / (Dawn variant) "Should we bump the Dawn pin before this work, or after?"

---

## Repo layout reminder

| Path | Purpose |
|---|---|
| `README.md` | Two-kit overview + decision tree |
| `CLAUDE.md` | This file |
| `WORKING_WITH_AI.md` | What the human will paste at you + how to respond |
| `webflow-to-shopify-kit/` | **Pure Webflow variant** |
| ├ `CONVERSION_GUIDE.md` | Long-form recipe + every Webflow gotcha (canonical for both kits' Webflow-side work) |
| ├ `CONVERT_PROMPT.md` | Hands-off brief for the pure variant |
| ├ `scripts/` | Automated mechanical steps |
| └ `starter-theme/` | Universal Shopify-required files |
| `webflow-to-shopify-dawn-kit/` | **Dawn-augmented variant** |
| ├ `CONVERT_PROMPT.md` | Hands-off brief for the Dawn variant |
| ├ `DAWN_INTEGRATION.md` | Dawn-specific rules: cascade layers, cart-drawer bridge, version pin, seam |
| ├ `scripts/` | Same set as base + `pull-dawn`, `merge-dawn-commerce`, `wrap-css-layers`, `check-dawn-updates`, `audit-css-conflicts` |
| └ `starter-theme/` | Universal files Dawn doesn't supply; dual-loading `theme.liquid` |
