{%- comment -%}
After bootstrapping a new project from this kit, edit the PLACEHOLDERS in
this file (search for `<...>` brackets) so AI assistants — Claude Code,
GitHub Copilot, Cursor, Cline, Amp, Codex — write commits in this project's
voice.

Loaded automatically by Claude Code; most other AI tools also surface root
markdown files as project context.
{%- endcomment -%}

# Claude project guide (Dawn-augmented Webflow conversion)

> **AI assistants — read these once before answering anything else:**
>
> 1. `webflow-to-shopify-dawn-kit/CONVERSION_GUIDE.md` — the full Webflow → Shopify recipe (every Webflow gotcha)
> 2. `webflow-to-shopify-dawn-kit/DAWN_INTEGRATION.md` — Dawn-specific rules, cascade-layer behavior, version pin, the visual seam
> 3. `webflow-to-shopify-dawn-kit/CONVERT_PROMPT.md` — the hands-off conversion brief (steps, conventions, what NOT to do)
>
> If this is a fresh conversion, follow `CONVERT_PROMPT.md` end-to-end. If it's maintenance, the two reference docs above are your sources of truth.

This file gives AI assistants the context they need to write good commit messages and PRs for this repo.

---

## The architectural split (read first)

This is a **hybrid** Shopify Online Store 2.0 theme:

| Pages | Source | Why |
|---|---|---|
| Homepage, about, contact, `/pages/*`, blog, articles, 404, password | **Webflow** (preserve verbatim) | Brand design + interactions live in Webflow's CSS/JS bundle. |
| Header, footer | **Webflow** (shared everywhere) | One header/footer across both brand and commerce, so brand identity continues into the shop. |
| Product, collection, cart, search, customer account | **Dawn** (`Shopify/dawn` at the pinned tag) | Battle-tested commerce templates. Pulling Dawn beats rebuilding variant pickers, faceted filters, customer flows. |

**CSS conflicts between Dawn and Webflow are resolved by cascade layers** declared in `layout/theme.liquid`:

```css
@layer dawn, webflow;
```

Webflow wins on shared selectors (e.g. if both define `.button`, Webflow's rules apply everywhere). See `DAWN_INTEGRATION.md` for the full mechanics.

---

## User preferences

- **Commit messages**: don't prefix with `git add ...` instructions — just the message body in a copyable block. The user runs `git add` themselves.
- **Conventional Commits** format: `type(scope): summary` (see "Commit conventions" below).
- **Don't ask permission to read** the kit's guide / prompt / integration doc / shopify-liquid skill — read them when relevant.
- **Surface flagged-out-of-scope work** rather than silently fixing everything.

---

## What this repo is

A **hybrid Shopify Online Store 2.0 theme** converted from a Webflow export for **<BRAND>**, augmented with Dawn's commerce templates. Shopify theme files (assets/, config/, layout/, sections/, snippets/, templates/) live at the repo root.

- The original Webflow export lives in `webflow-source/` (reference; never deployed).
- Dawn's source lives in `dawn-source/` (checked-out at the pinned tag; never deployed).
- Both are excluded from theme deploys via `.shopifyignore`.

The conversion is **visual-parity first for brand pages, modern-commerce first for shop pages**. Webflow CSS/JS/class names/`data-wf-*` attributes are preserved verbatim. Dawn sections/snippets/CSS/JS are preserved verbatim. They coexist via cascade layers — see `DAWN_INTEGRATION.md`.

Bootstrapped from [webflow-to-shopify-dawn-kit](https://github.com/<your-org>/webflow-to-shopify-conversion-kit/tree/main/webflow-to-shopify-dawn-kit).

---

## Critical rules (cause real bugs if violated)

1. **Don't modify Webflow CSS or JS.** Style overrides go in theme settings → Custom CSS, or in a new layered CSS file loaded AFTER the Webflow files.
2. **Don't modify Dawn CSS or JS** for the same reason — Dawn's web components are tightly coupled to specific class names and JS event names.
3. **The cascade-layer wrapping IS a narrow, documented exception.** Each Webflow CSS file has `@layer webflow { ... }` wrapping; each Dawn CSS file has `@layer dawn { ... }`. This wrapping is mechanical and lossless — re-running `flatten-assets` or `merge-dawn-commerce` is idempotent. Don't unwrap manually.
4. **Don't rename a Webflow or Dawn class.** Class names are load-bearing for CSS AND for both bundled JS runtimes.
5. **Don't strip `data-wf-*` attributes** from any element. Webflow's JS keys off them.
6. **Don't rename Dawn's web component custom elements** (`<cart-drawer>`, `<product-form>`, `<variant-radios>`, `<predictive-search>`, etc.) — they're registered globally in `global.js`.
7. **Inside `{% liquid %}` tags: one statement per line.** Semicolons are NOT valid separators — silent parse failure → Shopify reports the misleading "missing required file layout/theme.liquid".
8. **Section schema `tag` must be valid.** Allowed: `article`, `aside`, `div`, `footer`, `header`, `section`, or omitted. `null` silently kills rendering.
9. **`{% sections %}` (plural) ≠ `{% section %}` (singular).** Plural loads a section GROUP via `sections/<name>.json`. Singular renders `sections/<name>.liquid`. Verify file extension at the path being called.
10. **Color settings shouldn't have `default` values** unless verified against the actual CSS.
11. **Check AUDIT.md** before configuring scripts. Per-export filename / form-ID variation is real.

---

## Repo layout

**Shopify theme files** (at repo root — picked up by Shopify CLI / GitHub integration):

| Path | What lives here |
|---|---|
| `assets/` | Flat folder. **Both** Webflow's brand CSS/JS (wrapped in `@layer webflow`) and Dawn's `component-*.css` / `section-*.css` / web-component JS (wrapped in `@layer dawn`). Shopify forbids subdirs. |
| `config/` | `settings_schema.json` + `settings_data.json`. Started from the kit's minimal schema; Dawn's much larger schema is NOT merged automatically — see `DAWN_INTEGRATION.md` if you want to bring it in. |
| `layout/` | `theme.liquid` (dual-loading: Webflow CSS/JS + Dawn runtime) + `password.liquid`. |
| `locales/` | i18n strings. Supplied by `merge-dawn-commerce` from Dawn's `en.default.json` — extensive commerce vocabulary out of the box. |
| `sections/` | Mixed: `header.liquid`, `footer.liquid`, `home-*` / `component-*` / `page-*` from Webflow; `main-product*`, `main-collection-*`, `main-cart-*`, `main-search`, `main-account`, `main-login`, `main-register`, `main-addresses`, `main-order`, `cart-drawer`, `predictive-search`, etc. from Dawn. |
| `snippets/` | Mixed: `wf-form-states.liquid`, `social-icon.liquid`, `theme-variables.liquid` from kit; most other `*.liquid` from Dawn (`card-product`, `price`, `quantity-input`, `icon-*`, `pagination`, `facets`, ...). |
| `templates/` | Brand templates (`index.json`, `page.json`, `blog.json`, `article.json`, `404.json`, `password.json`) come from Webflow conversion + kit. Commerce templates (`product.json`, `collection.json`, `cart.json`, `search.json`, `list-collections.json`, `gift_card.liquid`, `customers/*.liquid`) come from Dawn. |
| `.shopifyignore` | Excludes `webflow-source/`, `dawn-source/`, kit folders, conversion scripts, and root docs. |

**Source + tooling** (excluded from theme deploys):

| Path | What lives here |
|---|---|
| `webflow-source/` | Original Webflow export — never deployed. |
| `dawn-source/` | `Shopify/dawn` git checkout at the pinned tag (see `webflow-to-shopify-dawn-kit/scripts/pull-dawn.sh`). Never deployed. |
| `.agents/skills/` | Shopify's official AI-assistant skills (shopify-dev, shopify-liquid). |
| `webflow-to-shopify-dawn-kit/` | The conversion kit itself (scripts, starter-theme, docs). |
| `CLAUDE.md` | This file. |

---

## Commit message conventions

Use **Conventional Commits**: `type(scope): short imperative summary`. Keep the summary ≤ 72 chars; add a body only when the *why* needs explaining.

### Types

| Type | When to use |
|---|---|
| `feat` | New section, new template, new merchant-editable setting. |
| `fix` | Broken layout, missing asset, wrong Liquid output, form submitting incorrectly. |
| `style` | CSS-level adjustments only (rare — most styles come from Webflow or Dawn CSS, both untouched). |
| `refactor` | Restructure sections, extract snippets, rename schema settings without changing output. |
| `chore` | Asset re-flattening, Dawn pin bump, dependency bumps, `.shopifyignore` edits. |
| `docs` | Updates to guides / `CLAUDE.md` / inline comments. |
| `content` | Default copy/image swaps in section schemas. |
| `perf` | Image format swaps, lazy-load tweaks, removing unused JS. |

### Scopes

Pick the narrowest scope that fits.

- `theme` — `layout/theme.liquid`, `layout/password.liquid`
- `header`, `footer` — header/footer sections + section groups (Webflow-side)
- `home`, `blog`, `article`, `404` — Webflow-side templates
- `product`, `collection`, `cart`, `search`, `account` — Dawn-side templates
- `page-<name>` — static Webflow pages
- `component-<name>` — reusable cross-page Webflow sections
- `forms` — newsletter / contact / password form wiring
- `assets` — anything inside `assets/`
- `config` — settings schema / data
- `locales` — translation files
- `snippets` — `snippets/*.liquid`
- `webflow-bridge` — preserving Webflow JS / `data-wf-*` / `w-mod-*`
- `dawn-bridge` — Dawn web component wiring, cart drawer integration with brand pages
- `cascade-layers` — anything touching `@layer dawn, webflow;` declarations or wrapping behavior
- `guide` — kit docs

### Examples

```
feat(home): split hero into its own section so merchants can swap the image
fix(product): wire variant picker to Dawn's <variant-radios> custom element
fix(dawn-bridge): trigger cart-drawer open from Webflow "Add to cart" button
chore(dawn-pin): bump Shopify/dawn to v15.4.1
refactor(footer): move social SVGs into snippets/social-icon
fix(cascade-layers): unwrap stray ../components.css that wasn't @layered
docs(guide): document the visual-seam token-reskin pattern
```

### When NOT to bundle

- Don't mix a new section with a footer fix — split into two commits.
- Don't bundle asset re-flattening with template edits.
- Don't bundle a Dawn pin bump with Webflow-side work.

---

## Things to check before committing

1. **CSS edits**: if the diff touches `assets/*.css`, double-check — the rule is **don't modify Webflow or Dawn CSS**. Style adjustments belong in Custom CSS (theme settings → `theme-variables.liquid` emits it) or a new layered CSS file you load after.
2. **`@layer` wrapping**: every `assets/*.css` should start with either `@layer webflow {` or `@layer dawn {`. The audit script reports unwrapped files:
   ```
   node webflow-to-shopify-dawn-kit/scripts/audit-css-conflicts.cjs
   ```
3. **`data-wf-*` attributes + Dawn custom elements**: never strip from any element.
4. **Class names**: don't rename in either set. Both runtimes key off them.
5. **Schema JSON validity**: bulk-validator one-liner:
   ```bash
   node -e "const fs=require('fs');for(const f of fs.readdirSync('sections').filter(x=>x.endsWith('.liquid'))){const c=fs.readFileSync('sections/'+f,'utf8');const m=c.match(/\\{%\\s*schema\\s*%\\}([\\s\\S]*?)\\{%\\s*endschema\\s*%\\}/);if(m){try{JSON.parse(m[1])}catch(e){console.log(f+': '+e.message)}}}"
   ```
6. **`{% liquid %}` tags**: one statement per line.
7. **Liquid tag balance**: `{% form %}` / `{% endform %}`, `{% if %}` / `{% endif %}`, etc.
8. **Asset references**: new images in `assets/` (flat). `{{ 'filename.ext' | asset_url }}` — never hard-coded paths.
9. **Routes**: `{{ routes.* }}` — never hard-code `/cart`, `/collections/all`, etc. Dawn's web components key off `Shopify.routes` populated in `theme.liquid`.
10. **Theme settings with defaults**: `{% if settings.X != blank %}…{% endif %}` so empty values never override the design.
11. **Required Shopify files**: before publishing, run:
    ```bash
    bash webflow-to-shopify-dawn-kit/scripts/check-required-files.sh
    ```
12. **Dawn pin currency**: occasionally run:
    ```bash
    bash webflow-to-shopify-dawn-kit/scripts/check-dawn-updates.sh
    ```
    Newer Dawn releases may bring improvements or breaking changes — bump deliberately.

---

## PR / multi-commit guidance

When grouping commits into a PR, the title follows the same convention as the strongest individual commit. The description should call out:

- What user-facing thing changed (or didn't — visual parity)
- Whether Webflow or Dawn markup was touched, and which (different review checklists per side)
- Any new schema settings merchants will see
- Verification: which routes were spot-checked — **always check at least one brand page AND one commerce page**, since the dual-runtime can surface bugs that only show up on one side.

If unsure whether something deserves its own commit, ask: "would I want to revert this change independently?" If yes → own commit.
