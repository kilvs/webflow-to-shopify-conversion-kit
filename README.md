# Webflow → Shopify Conversion Kit

> Convert any Webflow static-site export into a publishable Shopify Online Store 2.0 theme — without rewriting any styles or markup.

A self-contained kit that hands a coding agent (Claude Code, Cursor, Copilot, Cline, Amp, etc.) everything it needs to do the conversion mechanically: scripts that handle the boilerplate, a starter theme that ships every Shopify-required file, and a long-form recipe covering every gotcha I've hit on real projects.

The goal: **byte-identical visual parity**. Only the rendering engine changes (static HTML → Liquid). Webflow's CSS, JS bundle, class names, and `data-wf-*` attributes are preserved verbatim.

---

## What you get

```
.
├── CONVERSION_GUIDE.md          # ~750-line recipe with every step + gotcha
├── CONVERT_PROMPT.md            # paste-into-AI brief for hands-off conversion
├── CLAUDE.md                    # AI conventions / context for Claude Code et al.
├── WORKING_WITH_AI.md           # human-facing workflow + recommended prompts
├── scripts/
│   ├── convert-all.{sh,ps1}        # orchestrator: runs every automatable step
│   ├── install-skills.{sh,ps1}     # installs shopify-dev + shopify-liquid AI skills
│   ├── audit-source.{sh,ps1}       # writes AUDIT.md with data-wf-* IDs + components
│   ├── flatten-assets.{sh,ps1}     # copies + rewrites webflow-source/ into flat assets/
│   ├── convert.cjs                 # bulk page-content extractor (HTML → sections + templates)
│   ├── convert-forms.cjs           # Webflow newsletter → Shopify {% form %} (configurable ID)
│   ├── split-page.cjs              # splits monolithic page section into per-block sections
│   ├── seed-template-blocks.cjs    # seeds JSON templates with section preset blocks
│   └── check-required-files.sh    # pre-push verifier
└── starter-theme/                  # universal theme files to copy verbatim
    ├── assets/      cart-ajax.js, cart-drawer.css
    ├── config/      settings_schema.json, settings_data.json
    ├── layout/      theme.liquid (with placeholders), password.liquid
    ├── locales/     en.default.json
    ├── sections/    main-cart, main-search, main-404, main-password, main-list-collections
    ├── snippets/    cart-drawer, social-icon, wf-form-states, theme-variables
    ├── templates/   401/404/cart/search/password/list-collections JSON + gift_card + customers/
    └── .shopifyignore
```

Brand-specific files (`header.liquid`, `footer.liquid`, `page-*.liquid`) come out of *your* source HTML via the scripts. Nothing brand-specific lives in the kit.

---

## Quick start

```bash
# 1. Make a new project folder
mkdir my-brand-theme && cd my-brand-theme && git init

# 2. Drop this kit's contents in (clone or download)
git clone https://github.com/<your-org>/webflow-to-shopify-conversion-kit.git tmp
mv tmp/* tmp/.* . 2>/dev/null; rm -rf tmp

# 3. Unzip your Webflow export into webflow-source/
unzip path/to/your-webflow-export.zip -d webflow-source/

# 4. Open in Claude Code (or any AI coding agent)
claude .

# 5. Paste this as your first message:
#    "Convert this Webflow export to Shopify. Follow CONVERT_PROMPT.md."
```

The AI runs the orchestrator (`bash scripts/convert-all.sh`), fills the theme.liquid placeholders, builds header + footer, splits the homepage into per-block sections, runs the seed-template-blocks helper, and reports what still needs human judgement (commerce wiring on product/collection, contact form, etc.).

**Your total active time: ~20 minutes** — drop files in, review the diff, commit, connect Shopify, import products, publish.

For a manual step-by-step (no AI), see [`CONVERSION_GUIDE.md`](CONVERSION_GUIDE.md).

For more recommended AI prompts (homepage first, product page, etc.), see [`WORKING_WITH_AI.md`](WORKING_WITH_AI.md).

---

## What this kit does NOT do

- Re-style anything. Webflow CSS ships as-is.
- Touch the JS bundle (`*-dev.js` from the export).
- Migrate Webflow CMS collections to Shopify metafields.
- Wire Klaviyo / Mailchimp newsletter sync.
- Auto-generate header/footer sections (logos and nav are unique per brand).
- Generate the brand's `data-wf-page` table (you provide these from the audit).

---

## Contributing

Found a Webflow gotcha not covered in `CONVERSION_GUIDE.md §13`? PR welcome. Add a one-paragraph gotcha to the list with the specific failure mode and the fix.

Found a project filename Webflow uses that the kit's scripts don't recognize (e.g. `convert.cjs PAGES` defaults missing your page)? PR welcome — extend the `PAGES`/`HREF_MAP` defaults.

## License

MIT
