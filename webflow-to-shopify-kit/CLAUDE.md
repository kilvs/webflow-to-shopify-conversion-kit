# AI briefing — Webflow → Shopify conversion kit

> **You (Claude Code, Cursor, Cline, Copilot, etc.) opened the kit folder.** This file orients you in ~2 minutes. Read it end-to-end before doing anything.

## What this kit is (one paragraph)

A toolkit that turns a Webflow static-site export into a publishable Shopify Online Store 2.0 theme. **Byte-identical visual parity** is the goal — Webflow's CSS, JS bundle, class names, and `data-wf-*` attributes ship verbatim; only the rendering engine changes (static HTML → Liquid). The kit is fully usable **without any AI** (`node scripts/run.cjs` handles ~90% mechanically), and also has a hands-off AI brief (`CONVERT_PROMPT.md`) if the user wants you to drive.

## The three key files (memorize)

| File | When to read it |
|---|---|
| [`CONVERT_PROMPT.md`](CONVERT_PROMPT.md) | User asked you to run a conversion. This is the step-by-step brief — follow it end-to-end. |
| [`CONVERSION_GUIDE.md`](CONVERSION_GUIDE.md) | You're stuck / need reference. ~750 lines with every Webflow gotcha. Search it before guessing. |
| [`scripts/run.cjs`](scripts/run.cjs) | The Node orchestrator. Runs 7 automated steps in sequence. Continues on failure. Cross-platform. |

## Am I supposed to drive the conversion, or just help?

**Check what the user typed.**

- *"Convert this Webflow export"* / *"Follow CONVERT_PROMPT.md"* → **You drive.** Read `CONVERT_PROMPT.md` and execute step-by-step.
- *"Help me with X"* / *"Fix the header"* / *"Debug this section"* → **You assist.** Read `CONVERSION_GUIDE.md` for the relevant recipe, don't restart the whole flow.
- *"How does this kit work?"* → **You explain.** This file + `README.md` at repo root.

## The two conversion paths (what the human sees)

- **Path A (CLI-only, no AI):** `node scripts/run.cjs` does the mechanical work; human fills placeholders + builds header/footer + wires commerce by hand using `CONVERSION_GUIDE.md`. Total: ~1–2 hours.
- **Path B (AI-driven):** Human pastes `CONVERT_PROMPT.md` at you; you run `run.cjs`, fill placeholders, build header/footer, wire commerce, and ask brand-specific questions. Total: ~20 min active human time.

Both paths run `run.cjs` — the AI path is `run.cjs` + judgement-call steps done by you.

## Critical rules (violating these creates real bugs)

1. **Never modify `assets/*.css` or `assets/*-dev.js`** — Webflow's CSS + JS bundle are preserved verbatim. Style overrides go in theme settings → Custom CSS, or a new asset file loaded after.
2. **Never rename a Webflow class** (`.component_header`, `.hero_section`, etc.) — the JS bundle and CSS both key off them.
3. **Never strip `data-wf-*` attributes** from any element — Webflow's interactions runtime needs them.
4. **Inside `{% liquid %}` tags: one statement per line.** Semicolons are NOT valid separators. Silent parse failure → Shopify reports cryptic "missing required file layout/theme.liquid" error.
5. **Section schema `tag` must be a valid value** — allowed: `article`, `aside`, `div`, `footer`, `header`, `section`, or omitted. `null` silently drops the section from the page with no error. Grep `"tag":\s*null` before pushing.
6. **`{% sections %}` (plural) ≠ `{% section %}` (singular).** Plural loads a section GROUP via `sections/<name>.json` manifest. Singular renders `sections/<name>.liquid` directly. Verify the extension at the path being called.
7. **Every block-based section needs an `{% else %}` fallback** inside its `{% for block in section.blocks %}` loop, with the original Webflow markup. Pair with running `scripts/seed-template-blocks.cjs` so blocks seed into template JSONs.
8. **Color settings must not have `default` values** unless verified against actual CSS. Wrong defaults override the dark-theme Webflow CSS and make text invisible.
9. **Check `AUDIT.md` before configuring scripts** — page filenames, form IDs, JS bundle name, primary CSS filename vary per Webflow export. The kit's script defaults won't match every project.
10. **Bootstrap step preserves existing files on re-run** — `scripts/run.cjs` step 4 skips any file that already exists at the destination. Safe to re-run without clobbering user edits to `layout/theme.liquid`, `sections/header.liquid`, etc.

## Layout of this kit folder

```
webflow-to-shopify-kit/
├── CLAUDE.md                    # this file — quick AI orientation
├── CONVERT_PROMPT.md            # hands-off AI brief (Path B)
├── CONVERSION_GUIDE.md          # ~750-line recipe with every gotcha
├── scripts/
│   ├── run.cjs                  # THE orchestrator (recommended entry point)
│   ├── convert-all.{sh,ps1}     # older shell orchestrator (aborts on error — use run.cjs instead)
│   ├── audit-source.{sh,ps1}    # writes AUDIT.md with data-wf-* IDs, JS bundle name, etc.
│   ├── flatten-assets.{sh,ps1}  # copies webflow-source/{css,js,images,fonts}/ into assets/
│   ├── convert.cjs              # extracts <main> content from source HTML → sections + templates
│   ├── convert-forms.cjs        # Webflow newsletter form → Shopify {% form 'customer' %}
│   ├── split-page.cjs           # splits monolithic page section into per-block sections
│   ├── seed-template-blocks.cjs # seeds JSON templates with each section's preset blocks
│   ├── check-required-files.sh  # verifies Shopify's required files exist (also built into run.cjs)
│   └── install-skills.{sh,ps1}  # installs Shopify's shopify-dev + shopify-liquid AI skills
└── starter-theme/               # universal Shopify files copied into the brand project
    ├── CLAUDE.md                # for the target brand project (NOT this file)
    ├── layout/                  # theme.liquid + password.liquid with <PLACEHOLDER> slots
    ├── sections/                # main-404, main-cart, main-search, main-password, main-list-collections
    ├── snippets/                # cart-drawer, social-icon, wf-form-states, theme-variables
    ├── templates/               # 404/cart/search/password/list-collections JSON + customers/*.liquid + gift_card.liquid
    ├── config/                  # settings_schema.json + settings_data.json
    ├── locales/                 # en.default.json
    ├── assets/                  # cart-ajax.js + cart-drawer.css
    └── .shopifyignore
```

## Running from within the kit vs from the brand project

- **From the brand project root** (typical): `node webflow-to-shopify-kit/scripts/run.cjs`. This is what `CONVERT_PROMPT.md` assumes.
- **From this kit folder**: don't. The scripts write output relative to `process.cwd()`, so running them from inside the kit would write into the kit itself. If you're here (Claude opened the kit folder), the user probably wants you to explain or edit the kit — not run it.

## When you're stuck

1. **Search `CONVERSION_GUIDE.md`** — it likely has the answer with a worked example. Common section anchors: §4.3 (asset+link rewriting), §6.1 (splitting sections into editable blocks), §8-9 (header/footer + section groups), §13 (gotchas / bug catalog), §14 (cart wiring), §E (commerce wiring for product/collection).
2. **Check the Shopify AI skills** at `.agents/skills/shopify-dev` and `.agents/skills/shopify-liquid` (if installed). These are Shopify's own reference docs for Liquid filters, theme architecture, section schemas. Install via `scripts/install-skills.{sh,ps1}`.
3. **Ask the user** — "Which Shopify collection feeds the product slider?" / "Are subscriptions live?" / "Where do swatch hex colors come from — metafield or app?" are all real judgement calls that need brand context. Don't guess.

## Commit conventions (if you're making commits)

Conventional Commits: `type(scope): summary` (≤72 chars). Body explains *why*.

- `feat` new section/template/setting · `fix` broken layout/asset/form · `chore` asset re-flatten, config edit, kit-script tweak · `docs` guide/comments · `refactor` structural change with no output change · `perf` bundle size/lazy load
- Common scopes: `theme`, `header`, `footer`, `home`, `product`, `collection`, `blog`, `article`, `cart`, `search`, `404`, `page-<name>`, `component-<name>`, `forms`, `assets`, `config`, `locales`, `snippets`, `webflow-bridge`, `guide`
- Don't bundle unrelated changes (asset re-flattening + template edits should be split)
- No `git add` instructions in the message — just the body in a copyable block

## What NOT to do

- **Don't run `convert-all.sh` when `run.cjs` is available.** `run.cjs` is newer, cross-platform, continues on failure, and gives a proper summary. `convert-all.sh` aborts on first error and hides later failures.
- **Don't rewrite the Webflow markup you extracted.** The whole point of the kit is preservation — the AI's job is to WRAP static markup in Liquid conditionals (e.g. `{% if product %}...{% else %}static fallback{% endif %}`), not to rebuild it.
- **Don't blindly copy from Dawn or other Shopify starter themes.** This kit is designed around Webflow's specific class conventions and its JS bundle's expectations. Dawn's `.button` and Webflow's `.button-primary` are different beasts.
- **Don't skip `AUDIT.md`.** Every Webflow export is slightly different (file names, form IDs, page IDs). Reading AUDIT.md before configuring scripts is faster than debugging why the defaults don't match.
