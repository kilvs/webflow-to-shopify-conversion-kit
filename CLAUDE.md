# Claude / AI assistant guide

> **Before doing anything, read these:**
>
> 1. [`CONVERSION_GUIDE.md`](CONVERSION_GUIDE.md) — the full ~750-line recipe with every gotcha worth knowing.
> 2. [`CONVERT_PROMPT.md`](CONVERT_PROMPT.md) — the hands-off conversion brief (steps, conventions, what NOT to do).
>
> They're ~40 KB combined. Reading them first means you won't re-invent the dark-mode bug, the `{% liquid %}` semicolon trap, the `"tag": null` rendering bug, or the "missing layout/theme.liquid" rabbit hole. If this is a fresh Webflow conversion, follow `CONVERT_PROMPT.md` end-to-end. If it's maintenance, the guide is your reference.

---

## Critical rules (these cause real bugs if violated)

1. **Don't modify Webflow CSS or JS.** `assets/*.css` and the `*-dev.js` bundle are preserved verbatim. Style overrides go in theme settings → Custom CSS, or in a new layered CSS file loaded AFTER the Webflow files.
2. **Don't rename a Webflow class.** Class names are load-bearing for CSS AND for the bundled JS.
3. **Don't strip `data-wf-*` attributes** from any element. Webflow's interactions key off them.
4. **Inside `{% liquid %}` tags: one statement per line.** Semicolons are NOT valid separators — they cause silent parse failure that Shopify reports as the misleading "missing required file layout/theme.liquid" error.
5. **Section schema `tag` must be a valid value.** Allowed: `article`, `aside`, `div`, `footer`, `header`, `section`, or property omitted. `null` silently kills rendering — Shopify drops the section with no error. Always grep `"tag":\s*null` before pushing.
6. **`{% sections %}` (plural) ≠ `{% section %}` (singular).** Plural loads a section GROUP via `sections/<name>.json` manifest. Singular renders a single section file `sections/<name>.liquid` directly. AI assistants regularly swap them. Verify the file extension (.json vs .liquid) at the path being called.
7. **Every block-based section needs an `{% else %}` fallback** inside its `{% for block in section.blocks %}` loop, with the original Webflow markup verbatim. Pair with running `scripts/seed-template-blocks.cjs` to seed block instances into the template JSONs. Both are required — missing either causes blank sections.
8. **Color settings should not have `default` values** unless verified against the actual CSS — wrong defaults override the dark-theme Webflow CSS and make text invisible.
9. **Check AUDIT.md** before configuring scripts. Page filenames (`product-page.html` vs `product-template.html`), form IDs (`wf-form-Subscribe-Form` vs `wf-form-Newsletter-Form`), Webflow JS bundle name, primary CSS filename all vary per export. The kit scripts have defaults that won't match every project.

---

## Conventions you must follow

- **Commit messages**: Conventional Commits (`type(scope): summary`). Keep summary ≤ 72 chars; body explains *why*. No `git add` instructions — just the message body in a copyable block.
- **Don't bundle unrelated changes** into one commit. Asset re-flattening and template edits are independent; split them.
- **Surface flagged-out-of-scope work** (gotchas the user might miss) rather than silently fixing everything.
- **Don't ask permission to read** `CONVERSION_GUIDE.md` / `CONVERT_PROMPT.md` / installed Shopify AI skills — read them when relevant.
- **Always run the validators** before reporting a task done:

      bash scripts/check-required-files.sh
      node -e "const fs=require('fs');for(const f of fs.readdirSync('sections').filter(x=>x.endsWith('.liquid'))){const c=fs.readFileSync('sections/'+f,'utf8');const m=c.match(/\{%\s*schema\s*%\}([\s\S]*?)\{%\s*endschema\s*%\}/);if(m){try{JSON.parse(m[1])}catch(e){console.log(f+': '+e.message)}}}"

---

## What to do when unsure

1. Re-read the relevant section of `CONVERSION_GUIDE.md`.
2. Check the Shopify AI skills installed in `.agents/skills/` (run `bash scripts/install-skills.sh` if missing).
3. **Surface the question to the user** rather than guess. Real examples: "Which collection should the product slider source from?" / "Are subscriptions live on this store?" / "Where do swatch hex colors come from — metafield or app?"

---

## Repo layout reminder

| Path | Purpose |
|---|---|
| `CONVERSION_GUIDE.md` | Long-form recipe + every gotcha |
| `CONVERT_PROMPT.md` | The hands-off brief to follow on a fresh conversion |
| `WORKING_WITH_AI.md` | What the human will paste at you + how to respond |
| `scripts/` | Automated mechanical steps |
| `starter-theme/` | Universal Shopify-required files to copy into the target repo |
