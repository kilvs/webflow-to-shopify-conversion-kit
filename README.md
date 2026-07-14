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

Two paths — same first three steps, then choose whether you drive the judgement-call work by hand or hand it to an AI agent.

### Common setup (both paths)

Requires: **Node.js** (any modern version), **Git**, and either **Git Bash** (Windows) or a POSIX shell (macOS/Linux). No npm packages, no Ruby, no Shopify CLI needed.

```bash
# 1. Make a new project folder
mkdir my-brand-theme && cd my-brand-theme && git init

# 2. Drop this kit's contents in (clone or download)
git clone https://github.com/<your-org>/webflow-to-shopify-conversion-kit.git tmp
mv tmp/webflow-to-shopify-kit . && rm -rf tmp

# 3. Unzip your Webflow export into webflow-source/
unzip path/to/your-webflow-export.zip -d webflow-source/
```

### Path A — CLI only, no AI (~1–2 hours active time)

For when you want full control, or you don't have an AI agent handy, or you want to know exactly what the tooling is doing.

```bash
# 4. Run the orchestrator — one Node command, cross-platform.
#    Installs Shopify AI skills (skippable) → audits export → flattens
#    assets → bootstraps starter theme → extracts page content →
#    converts newsletter forms → verifies required files.
#    Continues on failure; prints a pass/fail summary at the end.
node webflow-to-shopify-kit/scripts/run.cjs

# 5. Fill <PLACEHOLDER> values in layout/theme.liquid + layout/password.liquid.
#    Open AUDIT.md (created in step 4) and paste the values:
#      <YOUR_WF_SITE_ID>       ← the data-wf-site constant
#      <WF_PAGE_*>             ← per-template data-wf-page IDs
#      <WEBFLOW_BUNDLE>.js     ← the JS bundle filename
#      site.css                ← rename to your brand's primary CSS
#    See CONVERSION_GUIDE.md §7 for details.

# 6. Build sections/header.liquid + sections/footer.liquid by hand.
#    Lift the <header class="component_header">…</header> and
#    <footer class="component_footer">…</footer> blocks verbatim from
#    webflow-source/index.html, rewrite images/*.X to {{ 'X' | asset_url }},
#    rewrite internal *.html links to {{ routes.* }}, wrap with {% schema %}.
#    See CONVERSION_GUIDE.md §8-9 for the full pattern + section-group
#    manifest files.

# 7. Wire commerce in sections/page-product.liquid + sections/page-collection.liquid.
#    Replace static product/collection markup with Liquid bindings:
#      static title      →  {{ product.title | default: 'static' }}
#      static price      →  {{ product.price | money }}
#      static variants   →  {% for variant in product.variants %}…{% endfor %}
#      Add to cart btn   →  wrap in {%- form 'product', product -%}…{%- endform -%}
#    See CONVERSION_GUIDE.md §E for the complete recipe with worked examples.

# 8. (Optional) Split the homepage into per-block sections so merchants can
#    reorder blocks in the theme editor.
grep -n "<section\|</section>" sections/page-index.liquid    # find boundaries
# Edit BOUNDARIES array in webflow-to-shopify-kit/scripts/split-page.cjs, then:
node webflow-to-shopify-kit/scripts/split-page.cjs
node webflow-to-shopify-kit/scripts/seed-template-blocks.cjs
rm sections/page-index.liquid

# 9. Verify + commit
bash webflow-to-shopify-kit/scripts/check-required-files.sh
git add -A && git commit -m "feat: initial Webflow to Shopify conversion"
```

Steps 5–7 are the manual work AI would otherwise do for you. First conversion is slow because you're learning the patterns; subsequent brands are much faster.

**When you need help but don't want AI running the whole thing:** `install-skills` (step 4) installs Shopify's official `shopify-dev` and `shopify-liquid` reference skills at `.agents/skills/`. Any editor or AI can read those files directly for Liquid filter references, theme architecture, section schema formats. Skills are pure documentation — no runtime dependency.

### Path B — with an AI agent (Claude Code, Cursor, Copilot, Cline, etc.) — ~20 min active time

For when you want the AI to handle steps 5–7 (placeholder filling, header/footer building, commerce wiring) and just ask you brand-specific questions.

```bash
# 4. Open in your AI agent
claude .

# 5. Paste as your first message:
#    "Convert this Webflow export to Shopify. Follow
#     webflow-to-shopify-kit/CONVERT_PROMPT.md."
```

The AI runs `run.cjs`, fills placeholders, builds header + footer, optionally splits the homepage, wires commerce, and reports back with any questions it needs answered (which Shopify collection feeds the product slider, subscription app details, etc.).

See [`CONVERT_PROMPT.md`](webflow-to-shopify-kit/CONVERT_PROMPT.md) for the exact brief the AI follows, and [`WORKING_WITH_AI.md`](WORKING_WITH_AI.md) for recommended follow-up prompts (per-page work, refinement, etc.).

### Both paths end the same way

```bash
git push origin main
```

Then in Shopify admin: **Online Store → Themes → Add theme → Connect from GitHub** → pick your repo → import products (CSV or admin UI) → **Publish**.

The manual step-by-step (with every gotcha we've hit on real projects) lives in [`CONVERSION_GUIDE.md`](webflow-to-shopify-kit/CONVERSION_GUIDE.md) — reference it whenever you're stuck in Path A, or hand it to your AI as context in Path B.

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
