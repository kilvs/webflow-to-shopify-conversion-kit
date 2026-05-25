# Dawn integration: rules, behavior, and gotchas

This doc covers everything specific to the Dawn-augmented variant of the kit. If you're working on the pure Webflow variant, this file doesn't apply — read `webflow-to-shopify-kit/CONVERSION_GUIDE.md` instead.

For shared Webflow-side gotchas (the `{% liquid %}` semicolon trap, `"tag": null` bug, etc.), see `webflow-to-shopify-kit/CONVERSION_GUIDE.md §13`. They apply identically here.

---

## 1. The architectural split

| Pages | Source | Notes |
|---|---|---|
| Homepage, about, contact, `/pages/*`, blog, articles, 404, password | Webflow | Brand visuals preserved verbatim. Webflow CSS bundle + Webflow JS bundle + jQuery + GSAP all load on these pages. |
| Header, footer | Webflow | Shared across both brand and commerce pages. Built by you/AI from `webflow-source/index.html`. |
| Product, collection, cart, search, customer account | Dawn | Dawn's `sections/main-product*`, `main-collection-*`, `main-cart-*`, `main-search`, `main-account`/`main-login`/`main-register`/etc. handle these templates natively. |

**Cart drawer** is Dawn-owned but rendered globally by `layout/theme.liquid`, so brand-page "Add to cart" buttons can trigger it via the JS bridge in §5 below.

---

## 2. Cascade layers (how Dawn and Webflow CSS coexist)

The kit wraps every `assets/*.css` file in a CSS cascade layer at copy time:
- `flatten-assets` wraps Webflow files in `@layer webflow { ... }`.
- `merge-dawn-commerce` wraps Dawn files in `@layer dawn { ... }`.

`layout/theme.liquid` declares the layer order in `<head>`:

```html
<style>@layer dawn, webflow;</style>
```

Per the CSS spec: **later-declared layers win** on conflict, regardless of selector specificity. So:
- A Dawn `.button { padding: 0.5rem 1rem; }` rule and a Webflow `.button { padding: 1rem; }` rule both match → Webflow's `padding: 1rem` wins on every page.
- Dawn templates (product, collection, etc.) don't use Webflow's class names, so on those pages there's nothing to override — Dawn's styles apply normally because no Webflow rule competes.

### What about the `theme-variables.liquid` snippet?

Merchant-pasted Custom CSS is emitted **outside** both layers (after both layered loads). Unlayered styles have **higher precedence than any layer**, so Custom CSS always wins. Use it for harmonizing the visual seam between Webflow and Dawn pages.

### The narrow exception to "don't modify Webflow/Dawn CSS"

Wrapping a file in `@layer NAME { ... }` IS a modification — it adds one line at the top and `}` at the bottom. This is a deliberate, mechanical, lossless transformation applied uniformly by the kit's scripts. **Treat it like minification or asset-URL rewriting, not like editing rules.** The wrapping is:
- **Idempotent**: `wrap-css-layers.cjs` skips files that already start with `@layer`.
- **`@charset`-aware**: preserves `@charset "UTF-8";` at the file top (where the spec requires it).
- **Reversible**: removing the top/bottom lines restores the original.

Don't unwrap manually. If a file needs to escape its layer for some reason (e.g. a fragment of CSS that genuinely *must* win over everything), put that fragment in a new unlayered CSS file loaded by a separate `{{ '…' | asset_url | stylesheet_tag }}` after the layered loads.

### What if a file ends up unwrapped?

`audit-css-conflicts.cjs` reports any unwrapped `.css` files in its output. Run it after the conversion:

```bash
node webflow-to-shopify-dawn-kit/scripts/audit-css-conflicts.cjs
# → AUDIT.md gets a "## CSS conflicts (Dawn ∩ Webflow)" section
# → Unwrapped files are listed there
```

Fix by re-running `flatten-assets` or `merge-dawn-commerce` (whichever owns that file).

---

## 3. Dawn version pinning

The pinned tag lives in **two places** (kept manually in sync):

- `webflow-to-shopify-dawn-kit/scripts/pull-dawn.sh` (line ~16: `DAWN_TAG="v15.3.0"`)
- `webflow-to-shopify-dawn-kit/scripts/check-dawn-updates.sh` (line ~22: same)

(PowerShell `.ps1` versions of each script have the same constant.)

### When to bump

Run the checker periodically:

```bash
bash webflow-to-shopify-dawn-kit/scripts/check-dawn-updates.sh
```

It hits GitHub's Releases API and reports whether a newer Dawn tag exists. Exit code 1 = newer release available.

**Bump deliberately.** Dawn ships breaking changes regularly — renamed sections, deleted snippets, schema restructures. The `merge-dawn-commerce.sh` whitelist (in the script itself) may need updating to match new Dawn file names.

### Bump procedure

1. Read the release notes at `https://github.com/Shopify/dawn/releases`. Note any renamed sections/snippets that intersect the kit's whitelist.
2. Edit `DAWN_TAG` in both `pull-dawn.sh` AND `check-dawn-updates.sh` (and the `.ps1` equivalents if you support Windows).
3. Delete `dawn-source/`:
   ```bash
   rm -rf dawn-source/
   ```
4. Re-run pull + merge:
   ```bash
   bash webflow-to-shopify-dawn-kit/scripts/pull-dawn.sh
   bash webflow-to-shopify-dawn-kit/scripts/merge-dawn-commerce.sh
   ```
5. Test commerce pages (product, collection, cart, search, login) in a Shopify dev store. Fix any markup that broke.
6. Commit: `chore(dawn-pin): bump Shopify/dawn to vX.Y.Z`.

---

## 4. Cart drawer integration with Webflow brand pages

Dawn's `<cart-drawer>` web component is rendered globally by `layout/theme.liquid` via `{% section 'cart-drawer' %}`. It listens for a `cart:open` custom event and adds the `active` class to open the drawer.

### The JS bridge

Webflow brand pages (homepage product slider, collection teaser, etc.) usually have "Add to cart" buttons. To wire them to Dawn's cart drawer, paste the following into `layout/theme.liquid` before `</body>` (or a new `snippets/dawn-cart-bridge.liquid` rendered there):

```liquid
<script>
(function() {
  function attachCartHandlers() {
    document.querySelectorAll('[data-product-add], [data-cart-quick-add]').forEach(function(btn) {
      if (btn.dataset.dawnBridgeAttached) return;
      btn.dataset.dawnBridgeAttached = '1';
      btn.addEventListener('click', async function(e) {
        e.preventDefault();
        e.stopPropagation();
        // Variant ID can come from button data attribute or a sibling form field
        var id = btn.dataset.cartQuickAdd
          || btn.closest('form')?.querySelector('[name="id"]')?.value
          || btn.dataset.productAdd;
        var qty = btn.closest('form')?.querySelector('[name="quantity"]')?.value || 1;
        if (!id) { console.warn('No variant id found for', btn); return; }
        try {
          var res = await fetch(window.Shopify.routes.cart_add_url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Accept': 'application/javascript' },
            body: JSON.stringify({ id: id, quantity: qty })
          });
          if (!res.ok) throw new Error('cart_add failed: ' + res.status);

          // Refresh cart count badges
          var cartRes = await fetch(window.Shopify.routes.cart_url + '.js');
          var cart = await cartRes.json();
          document.querySelectorAll('[data-cart-count], .cart-count-bubble').forEach(function(el) {
            el.textContent = cart.item_count;
          });

          // Open Dawn's cart drawer
          var drawer = document.querySelector('cart-drawer');
          if (drawer) {
            drawer.classList.add('animate', 'active');
            // Trigger Dawn's refresh-from-Shopify pattern
            drawer.dispatchEvent(new CustomEvent('cart:open', { bubbles: true }));
          }
        } catch (err) {
          console.error('Cart bridge:', err);
        }
      });
    });
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', attachCartHandlers);
  } else {
    attachCartHandlers();
  }
  // Re-scan after Webflow interactions (which may inject new DOM)
  setTimeout(attachCartHandlers, 1500);
})();
</script>
```

### Conventions for Webflow buttons

To use this bridge, add either:
- `data-cart-quick-add="{{ variant.id }}"` — simple one-tap add (quick-add button on a collection card)
- `data-product-add` plus a sibling form with `[name="id"]` and optional `[name="quantity"]` — product page add-to-cart

The bridge handles both. If a Webflow button doesn't use these attributes, it won't fire — that's intentional (so vanilla anchors keep working).

### Cart count badges

Anywhere you want the live cart item count, use either:
- `<span data-cart-count>{{ cart.item_count }}</span>` (kit convention — Webflow-friendly class names)
- `<span class="cart-count-bubble">{{ cart.item_count }}</span>` (Dawn convention — picks up Dawn's `component-cart-icon.css` styling)

The bridge updates both.

---

## 5. The visual seam

A shopper clicking from your Webflow-styled homepage into a Dawn-styled product page will see a visual jump:
- Different typography (Webflow's brand fonts vs Dawn's defaults)
- Different button shapes / spacing
- Different color treatments

**Three ways to handle it:**

### Option A: Accept the seam (default — what the kit ships)
Brand pages look like the brand; shop pages look like Dawn. Cheap. Works for many brands, especially if the visual gap isn't jarring (e.g. brand is already minimalist + Dawn defaults are clean).

### Option B: Reskin Dawn with Webflow tokens (medium effort)
Extract Webflow's design tokens (colors, fonts, spacing, border-radius) and paste them into theme settings → Custom CSS as `:root { --color-X: …; }` overrides. Dawn's CSS uses CSS custom properties extensively, so a small set of variable overrides can make commerce pages adopt the brand look without touching Dawn's selectors.

Example pasted into Custom CSS:
```css
:root {
  --font-body-family: 'YourBrandFont', sans-serif;
  --font-heading-family: 'YourBrandHeading', serif;
  --color-foreground: 18, 18, 18;          /* Dawn uses rgb triplets */
  --color-background: 255, 255, 255;
  --color-button: 18, 18, 18;
  --color-button-text: 255, 255, 255;
  --buttons-radius: 0;                      /* if your brand is sharp-cornered */
  --buttons-border-width: 1px;
}
```

The full list of Dawn CSS custom properties: `dawn-source/assets/base.css` (search for `--color-`, `--font-`, `--buttons-`, etc.). 30-ish variables cover the bulk of Dawn's visual identity.

### Option C: Fully restyle Dawn to match Webflow (expensive)
Don't. At that point you're rebuilding Dawn from Webflow scratch — defeats the kit's purpose. Pick Option A or B.

---

## 6. Locale handling

`merge-dawn-commerce` copies Dawn's `locales/en.default.json` into the theme, but **only if the file doesn't already exist**. This protects merchant customizations from re-runs.

If you re-pull Dawn after the locale file is already in place (e.g. a Dawn version bump), Dawn's new strings won't merge in automatically. Two options:

**Easy** — manually diff Dawn's `dawn-source/locales/en.default.json` against your `locales/en.default.json` and copy across any new keys. Especially relevant when Dawn adds new commerce features.

**Thorough** — back up your customizations, delete `locales/en.default.json`, re-run `merge-dawn-commerce.sh`, then port your customizations back in.

The kit deliberately doesn't auto-deep-merge JSON because that's surprisingly fragile (translation keys evolve in structure, not just content).

---

## 7. Settings schema (Dawn's vs the kit's)

The kit ships a minimal `config/settings_schema.json` with brand identity, custom CSS, and social links. Dawn ships a much larger schema (~200 lines) with typography scales, color schemes, layout density, animation toggles, spacing tokens, etc. — all designed to drive Dawn's commerce sections.

**The kit does NOT auto-merge Dawn's settings schema.** Reasons:
- Many of Dawn's settings target Dawn-specific CSS variables; they'd be no-ops on Webflow brand pages.
- Dawn's color schemes (`scheme-1`, `scheme-2`, etc.) require Dawn's `color-schemes.liquid` snippet and a specific markup pattern — opt-in.
- Merging would balloon the settings UI for a kit user who just wants Webflow-style brand controls.

### If you want to bring in Dawn settings

**Section-by-section**: copy the relevant settings from `dawn-source/sections/main-product.liquid` (the schema at the bottom of the file) into the matching section's schema. Same for other commerce sections.

**Globally**: if you want Dawn's full theme-level settings (color schemes, type system, spacing) to drive commerce pages, copy the relevant top-level entries from `dawn-source/config/settings_schema.json` into your `config/settings_schema.json`. Test thoroughly — some entries reference snippets/CSS the kit doesn't ship. Don't blindly copy the whole file.

---

## 8. Common gotchas

### Dawn's `<cart-drawer>` shows the wrong items after a brand-page add

The bridge fires `fetch(cart_add_url)` then refreshes the cart count. Dawn's cart-drawer re-fetches its own contents when opened — but only if it's been initialized. If you see a stale drawer:
- Ensure `global.js` loaded (check the network tab — `defer="defer"` means it loads after parse).
- Ensure the bridge's `setTimeout(attachCartHandlers, 1500)` is firing (Webflow interactions can re-render the homepage product slider DOM, so we re-scan).
- Try dispatching `cart:refresh` instead of/before `cart:open`.

### "Translation missing: en.sections.cart.headers.cart"

`merge-dawn-commerce` didn't run (no Dawn strings in `locales/en.default.json`), OR a kit user manually customized the locale file and missed a Dawn key. Diff against `dawn-source/locales/en.default.json` to find missing keys.

### Brand-page sections look weird when previewed in the Shopify theme editor

Theme editor renders sections in an iframe with its own chrome. Webflow's interaction JS sometimes fails to initialize inside the iframe. This isn't kit-specific — affects pure Webflow conversions too. Workaround: ignore the editor preview for Webflow sections; verify on the live preview URL.

### Dawn's product page renders but Add-to-cart does nothing

Open browser devtools. Common causes:
- `global.js` blocked / 404'd (check the network tab)
- Dawn's `<product-form>` custom element didn't register (look for "ProductForm" in console errors)
- Variant ID missing — usually means `templates/product.json` has unexpected blocks. Reset via `cp dawn-source/templates/product.json templates/product.json`.

### Cascade layers don't apply on Safari < 15.4 or Chrome < 99 or Firefox < 97

These are 2022 versions. If your audience uses anything modern, no concern. Shopify's analytics will tell you if any users hit unlayered fallback. If they do, the experience degrades to "Dawn's styles override Webflow's" — ugly but not broken.

---

## 9. Files the Dawn kit owns vs Webflow owns

For maintenance, here's the canonical list:

| Path pattern | Owner | Notes |
|---|---|---|
| `assets/component-*.css`, `assets/section-*.css`, `assets/base.css` | Dawn | Wrapped in `@layer dawn`. |
| `assets/*-dev.css`, `assets/normalize.css`, `assets/components.css`, brand CSS | Webflow | Wrapped in `@layer webflow`. Filenames vary per export. |
| `assets/global.js`, `assets/cart.js`, `assets/product-form.js`, `assets/quantity-input.js`, `assets/predictive-search.js`, etc. | Dawn | Web component runtime. Don't modify. |
| `assets/<brand>-dev.js`, jQuery, GSAP CDN | Webflow | Loaded at end of body. Don't modify. |
| `sections/main-product*.liquid`, `main-collection-*.liquid`, `main-cart-*.liquid`, `main-search.liquid`, `cart-drawer.liquid`, `predictive-search.liquid`, `main-account.liquid`, `main-login.liquid`, etc. | Dawn | Don't rename custom elements. |
| `sections/header.liquid`, `sections/footer.liquid`, `sections/page-*.liquid`, `sections/home-*.liquid`, `sections/component-*.liquid` | Webflow | Built by you/AI from `webflow-source/`. |
| `snippets/card-product.liquid`, `price.liquid`, `quantity-input.liquid`, `icon-*.liquid`, `pagination.liquid`, `facets.liquid`, etc. | Dawn | Most Dawn snippets except header/nav ones. |
| `snippets/wf-form-states.liquid`, `social-icon.liquid`, `theme-variables.liquid` | Kit | Webflow-style form states, brand-friendly social SVGs, custom-CSS bridge. |
| `templates/product.json`, `collection.json`, `cart.json`, `search.json`, `list-collections.json`, `gift_card.liquid`, `customers/*.liquid` | Dawn | Don't rewrite these from scratch. |
| `templates/index.json`, `page.json`, `page.*.json`, `blog.json`, `article.json`, `404.json`, `password.json` | Webflow (via kit) | Generated by `convert.cjs`. |
| `layout/theme.liquid`, `layout/password.liquid` | Kit (dual-loader) | Customize the placeholders, otherwise leave structure intact. |
| `config/settings_schema.json`, `config/settings_data.json` | Kit (minimal) | Dawn's bigger schema is opt-in (§7). |
| `locales/en.default.json` | Dawn | Only auto-supplied if missing — see §6. |
