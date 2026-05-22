# Working with an AI on the conversion

How to use this kit with Claude Code, Cursor, Copilot, Cline, Amp, or any other AI coding agent. The kit is designed so that ~80% of the work is mechanical scripts and 20% is judgement calls — the AI handles both, you review.

---

## Prerequisites

1. A new local folder, `git init`'d.
2. This kit copied into the folder (`README.md`, `CONVERSION_GUIDE.md`, `scripts/`, `starter-theme/` at the root).
3. Your Webflow export unzipped into `webflow-source/`:

       my-brand-theme/
       ├── webflow-source/         ← unzipped Webflow export goes here
       │   ├── index.html
       │   ├── product-template.html (or product-page.html, depends on export)
       │   ├── css/  js/  images/  fonts/  videos/  documents/
       └── (kit files at root)

4. AI agent open in this folder (`claude .` for Claude Code, etc.).

---

## Recommended starting prompts

### A. End-to-end conversion (biggest scope)

> Convert this Webflow export to Shopify. Follow `CONVERT_PROMPT.md` step by step. Ask me before doing anything that needs my input (which collection feeds the product slider, are subscriptions live, etc.).

The AI runs all scripts, builds header + footer, splits homepage, runs the seeder, and wires what it can. Expect 30–60 minutes of agent activity; you mostly answer clarifying questions.

### B. Homepage first (recommended — validates the pipeline)

> Convert the homepage first. Run the orchestrator, fill the theme.liquid placeholders, build header + footer, split `index.html` into per-block sections, enrich each section's schema with editable defaults per §6.1, seed template blocks, and verify swiper/splide carousels work.

The AI focuses on the homepage stack only. Other pages remain as stubs so the theme passes publish-validation. Iterate from there.

### C. Product page

> Convert the product page from `webflow-source/product-template.html`. Use the multi-section split pattern: separate buy box, reviews, FAQs, related-products sections. Implement all 15 features from `CONVERT_PROMPT.md §4` as toggleable section settings. Match section attributes to the design.

The AI will ask which of items 1–15 are in scope (subscriptions, line item properties, recommendations source, sticky add-to-cart, etc.) before starting.

### D. Just one section / fix

> The navbar disappeared after I changed `<setting>`. Diagnose and fix.

> Make the cart drawer use the brand accent and add a free-shipping progress bar capped at $80.

> Sync the theme with the latest Webflow export — re-flatten assets, check what changed in `index.html`, update the affected sections, leave the unrelated pages alone.

Targeted asks are fine. The AI scopes accordingly.

---

## What the AI will do on its own (automatic)

- Run `scripts/install-skills.{sh,ps1}` to fetch Shopify AI skills
- Run `scripts/audit-source.{sh,ps1}` → writes `AUDIT.md`
- Run `scripts/flatten-assets.{sh,ps1}` → flat `assets/`
- Copy `starter-theme/*` into the project root
- Edit `scripts/convert.cjs` PAGES + HREF_MAP to match your export's filenames (different brands rename pages)
- Run `scripts/convert.cjs` → page extraction
- Run `scripts/convert-forms.cjs <FORM_ID>` (form ID from AUDIT.md)
- Run `scripts/split-page.cjs` → per-block sections
- Run `scripts/seed-template-blocks.cjs` → populate template JSONs
- Run `scripts/check-required-files.sh` → pre-push verify
- Validate JSON schemas + Liquid balance
- Draft a Conventional Commits message after each meaningful change

## What the AI will ask you about

- Which Webflow page filenames match which Shopify route (`product-page.html` vs `product-template.html` — depends on export)
- The Webflow form ID for the newsletter form (vary by export)
- Collection picker for the homepage product slider
- Whether subscriptions / line item properties / reviews app integration are in scope
- Swatch color source (metafield, app, or option name)
- The dark-navbar variant class hash from your CSS (if your Webflow design uses Variants)
- Theme settings to expose (the kit defaults to a minimal 5-group baseline — Brand identity / Custom CSS / Social / Currency / Cart)

## How to review what the AI did

1. `git status` to see what was added.
2. `git diff` to see edits to existing files (`theme.liquid` placeholders, `convert.cjs` PAGES, etc.).
3. `shopify theme dev --store <store>.myshopify.com` to preview locally.
4. Spot-check: visit `/`, `/products/<test>`, `/collections/all`, `/cart`, `/search`, `/404`, `/password`, `/account/login`. Compare to the original Webflow pages side-by-side.
5. Open Shopify Admin → Themes → Customize. Confirm Header + Footer groups are editable. Click each homepage section and confirm settings render.

## Common gotchas to flag back to the AI if you spot them

- **Navbar disappears on every template** → `"tag": null` in the section schema. AI should grep `"tag":\s*null` in `sections/*.liquid`.
- **Sticky navbar doesn't stick** → needs a CSS override making the Shopify wrapper sticky too (see kit `CONVERSION_GUIDE.md §13`).
- **Homepage section renders empty band** → the section uses `schema.blocks` but `templates/index.json` doesn't seed the blocks. AI should run `node scripts/seed-template-blocks.cjs`.
- **Carousels (swiper/splide) not initializing** → check `theme.liquid` head loads ALL the libraries the export uses (Splide auto-scroll extension is separate from Splide core; Swiper version may need bumping to v12).
- **Section settings exist in schema but invisible in theme editor** → if header/footer rendered via direct `{% section %}` instead of section groups, the editor won't surface them reliably. Switch back to section groups.

When you spot one, just describe it: "X is broken — fix it." The AI knows where to look from `CLAUDE.md` and `CONVERSION_GUIDE.md §13`.

---

## After the conversion

The AI will leave you with:
- A clean working tree (modulo the conversion's deliberate changes)
- A drafted commit message ready to paste
- A summary of what's done vs what's deferred (commerce wiring, other static pages, etc.)

Your turn:
1. Stage + commit using the AI's message
2. Connect to a Shopify dev store: `shopify theme dev --store ...`
3. Import products
4. Wire menus in admin → Navigation
5. Publish
