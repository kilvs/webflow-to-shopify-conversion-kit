# Webflow → Shopify Conversion Kit

> Convert any Webflow static-site export into a publishable Shopify Online Store 2.0 theme — without rewriting any styles or markup.

A self-contained kit that hands a coding agent (Claude Code, Cursor, Copilot, Cline, Amp, etc.) everything it needs to do the conversion mechanically: scripts that handle the boilerplate, a starter theme that ships every Shopify-required file, and a long-form recipe covering every gotcha I've hit on real projects.

**Two variants — pick one:**

| | **Pure Webflow** | **Dawn-augmented** |
|---|---|---|
| Folder | `webflow-to-shopify-kit/` | `webflow-to-shopify-dawn-kit/` |
| Goal | Byte-identical visual parity for every page | Brand pages stay Webflow; commerce uses Dawn |
| Product/collection/cart/search/customer pages | Hand-wired from Webflow markup (commerce wiring is judgement-heavy AI work) | **Auto-supplied by Dawn** — battle-tested commerce templates dropped in via `merge-dawn-commerce` |
| CSS strategy | Webflow CSS preserved verbatim | Both Webflow + Dawn CSS preserved; cascade layers (`@layer dawn, webflow;`) resolve conflicts |
| Visual consistency | One look across all pages | A visible seam between brand pages (Webflow) and shop pages (Dawn) — can be reskinned via theme tokens, see [`DAWN_INTEGRATION.md §5`](webflow-to-shopify-dawn-kit/DAWN_INTEGRATION.md) |
| Best for | Brand-led sites where the design is the product | Stores that want a fast path to modern commerce while keeping the brand homepage |
| Active AI time | ~20 min | ~25 min |
| Dawn version pin | n/a | `Shopify/dawn@v15.3.0` (update-checker script flags newer releases) |

---

## Which one should I pick?

```
Are you happy to hand-wire product / variant / cart / search /
customer-account templates from your Webflow markup, in exchange
for one consistent brand look across every page?
│
├─ Yes  →  webflow-to-shopify-kit/        (Pure Webflow)
│
└─ No, give me Dawn's commerce out of the box; I'll accept (or
   later restyle) the visual seam between brand and shop pages.
   →  webflow-to-shopify-dawn-kit/        (Dawn-augmented)
```

If you're unsure, **start with the Dawn-augmented kit** — you get Dawn's mature commerce flows without sacrificing your brand homepage, and the seam is usually small enough to skip styling work entirely.

---

## What you get

```
.
├── README.md                              # this file
├── CLAUDE.md                              # AI conventions / context shared by both kits
├── WORKING_WITH_AI.md                     # human-facing workflow + recommended prompts
│
├── webflow-to-shopify-kit/                # PURE WEBFLOW VARIANT
│   ├── CONVERSION_GUIDE.md                  # ~750-line recipe + every gotcha
│   ├── CONVERT_PROMPT.md                    # paste-into-AI brief
│   ├── scripts/
│   │   ├── convert-all.{sh,ps1}             # orchestrator
│   │   ├── audit-source / flatten-assets / convert / convert-forms /
│   │   │ split-page / seed-template-blocks / check-required-files
│   │   └── install-skills.{sh,ps1}
│   └── starter-theme/                       # universal Shopify-required files
│
└── webflow-to-shopify-dawn-kit/           # DAWN-AUGMENTED VARIANT
    ├── CONVERT_PROMPT.md                    # paste-into-AI brief (Dawn-aware)
    ├── DAWN_INTEGRATION.md                  # Dawn-specific rules, cascade layers,
    │                                        # cart bridge, version pin, seam handling
    ├── scripts/
    │   ├── convert-all.{sh,ps1}             # orchestrator (10 steps)
    │   ├── (same set as base kit, with modifications:)
    │   ├── convert.cjs                      # skips Dawn-owned page types
    │   ├── flatten-assets.{sh,ps1}          # wraps Webflow CSS in @layer webflow
    │   ├── pull-dawn.{sh,ps1}               # NEW: git clone Shopify/dawn @ pinned tag
    │   ├── merge-dawn-commerce.{sh,ps1}     # NEW: copies Dawn commerce files,
    │   │                                    # wraps Dawn CSS in @layer dawn
    │   ├── wrap-css-layers.cjs              # NEW: idempotent @layer wrapping helper
    │   ├── check-dawn-updates.{sh,ps1}      # NEW: compares pinned tag vs latest release
    │   └── audit-css-conflicts.cjs          # NEW: Dawn ∩ Webflow class overlap → AUDIT.md
    └── starter-theme/
        ├── layout/theme.liquid              # DUAL-LOADING: Webflow CSS/JS + Dawn runtime
        └── (universal files Dawn doesn't supply)
```

Brand-specific files (`header.liquid`, `footer.liquid`, `page-*.liquid`) come out of *your* source HTML via the scripts. Nothing brand-specific lives in the kit.

---

## Quick start

Same flow for both kits:

```bash
# 1. New project folder
mkdir my-brand-theme && cd my-brand-theme && git init

# 2. Drop the kit contents in (clone the whole repo, then delete the variant you didn't pick)
git clone https://github.com/<your-org>/webflow-to-shopify-conversion-kit.git tmp
mv tmp/* tmp/.* . 2>/dev/null; rm -rf tmp
# Optional: rm -rf webflow-to-shopify-kit/  (or the Dawn variant — keep only the one you'll use)

# 3. Unzip your Webflow export
unzip path/to/your-webflow-export.zip -d webflow-source/

# 4. Open in Claude Code (or any AI agent)
claude .

# 5. Paste as your first message:
#    Pure Webflow:    "Convert this Webflow export to Shopify. Follow webflow-to-shopify-kit/CONVERT_PROMPT.md."
#    Dawn-augmented:  "Convert this Webflow export to Shopify using the Dawn variant. Follow webflow-to-shopify-dawn-kit/CONVERT_PROMPT.md."
```

The AI runs the orchestrator, fills the theme.liquid placeholders, builds header + footer, and reports what still needs human judgement (commerce wiring for the pure kit; cart-drawer JS bridge for the Dawn kit; brand-page content settings for both).

**Your total active time:** ~20 min (pure) or ~25 min (Dawn). Drop files in, review the diff, commit, connect Shopify, import products, publish.

For manual step-by-step (no AI), see the kit's `CONVERSION_GUIDE.md` (pure) or `DAWN_INTEGRATION.md` (Dawn).

For more recommended AI prompts (homepage first, product page, etc.), see [`WORKING_WITH_AI.md`](WORKING_WITH_AI.md).

---

## What both kits do NOT do

- Re-style anything. Webflow CSS ships as-is (and so does Dawn's, in the Dawn variant).
- Touch the JS bundles (`*-dev.js` from Webflow; `global.js`/`cart.js`/etc. from Dawn).
- Migrate Webflow CMS collections to Shopify metafields.
- Wire Klaviyo / Mailchimp newsletter sync.
- Auto-generate header/footer sections (logos and nav are unique per brand).
- Generate the brand's `data-wf-page` table (you provide these from the audit).

---

## Contributing

Found a Webflow gotcha not covered in `webflow-to-shopify-kit/CONVERSION_GUIDE.md §13`? PR welcome. Add a one-paragraph gotcha to the list with the failure mode and the fix.

Found a Dawn integration edge case not covered in `webflow-to-shopify-dawn-kit/DAWN_INTEGRATION.md`? Same — PR welcome.

Found a project filename Webflow uses that the kit's scripts don't recognize (e.g. `convert.cjs PAGES` defaults missing your page)? PR welcome — extend the `PAGES`/`HREF_MAP` defaults.

Dawn version is older than what your project needs? Run the checker, bump deliberately per [`DAWN_INTEGRATION.md §3`](webflow-to-shopify-dawn-kit/DAWN_INTEGRATION.md), and PR the new tag.

## License

MIT
