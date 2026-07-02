# DOAC Border

A small web app that adds the DOAC branded border/frame around any photo, so
it's ready to print. Open the link, drop in a photo, pick a template and page
size, optionally reposition it, then export a bordered PNG.

**Use it:** https://mbf-s.github.io/doac-border-app/

No install, no account, nothing to download — it runs entirely in your
browser and never uploads your photo anywhere.

## Repo layout

- `web/` — the app itself (static HTML/CSS/JS, no build step). See
  `web/js/` for the rendering logic, `web/tests/` for its unit tests.
- `design-source/` — original design art (PSD, PNGs, the vectorized logo)
  that the border SVGs and wordmark were produced from.
- `vectorize.py` — regenerates a vector SVG from flattened design art (see
  its docstring for usage), if the source art ever changes.
- `docs/` — design specs and implementation plans.

## Developing

Everything in `web/` is plain ES modules, no bundler:

```
cd web && python3 -m http.server 8000
```

then open `http://localhost:8000`. Run the unit tests with:

```
node --test web/tests/
```

Pushes to `main` that touch `web/**` auto-deploy to GitHub Pages via
`.github/workflows/deploy.yml`.
