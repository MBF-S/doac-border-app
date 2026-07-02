# DOAC Border web app — design

## Goal

Replace the native Swift/AppKit DOAC Border Mac app with a static, client-side
web app hosted on GitHub Pages, so anyone can use it by opening a link — no
install, no code signing, no Gatekeeper "Apple could not verify..." dialog.

## Why

The native app is unsigned/ad-hoc (no Apple Developer account), so every
recipient hits Gatekeeper friction on first launch (see
`docs/2026-07-01-doac-border-app-design.md`, which explicitly declined
notarization). For a small internal utility, that friction outweighs the
benefit of a native app. All the actual work is 2D image/SVG compositing,
which browsers do natively via `<canvas>` — no native dependency is needed to
do this well.

## Scope

Faithful 1:1 port of current features:

- Choose/drag-drop a photo.
- Border template picker: V1, V2.
- Mode picker: Free size, A4, A5, Custom (with a cm ⇄ inch toggle).
- Orientation: portrait/landscape, auto-detected from the image, overridable.
- Drag to reposition, pinch/scroll-zoom to crop in, Reset button.
- Export → downloads a PNG named `<original>_<suffix>.png`.

Dropped: "Check for Updates" (meaningless on the web — the page is always the
latest version). Desktop browsers only (mouse + trackpad); mobile/touch is
out of scope for this pass.

Out of scope (unchanged from the original native-app design): batch
processing, editing the border artwork itself (still sourced from the two
vectorized SVGs; regenerate via `vectorize.py` if the source art changes).

## Architecture

New `web/` directory holds the entire app as plain static files — no
bundler, no `npm install`, no build step for the shipped app. Loaded via
`<script type="module">`, served as-is by GitHub Pages.

```
web/
  index.html
  style.css
  js/
    templateSpec.js     -- border margin specs (mirrors TemplateSpec.swift)
    positionState.js    -- pan/zoom containment math (mirrors PositionState.swift)
    frameLayout.js       -- page sizing/margins/orientation (mirrors FrameLayout.swift)
    frameRenderer.js     -- canvas compositing (mirrors FrameRenderer.swift)
    borderedImage.js     -- glue: photo+mode+template+position -> final canvas
    exporter.js           -- canvas -> PNG download (mirrors Exporter.swift)
    app.js                 -- DOM wiring: controls, drag/zoom gestures, cursor
  assets/
    template-v1.svg, template-v2.svg
  tests/
    positionState.test.js, frameLayout.test.js
```

Each JS module maps 1:1 to an existing Swift file so the port is a direct
translation of already-validated logic, not a redesign.

### Repo cleanup

Since the web app replaces the native app (not "both"):

- Delete `DOACBorderApp/` entirely (Swift source, tests, `build_app.sh`, its
  README). Git history retains it if ever needed.
- Move the design-source binaries (`Template border V1.png`, `Template
  border V2.png`, `Template border.psd`, `DOAC_Logo_W2.png`) into a new
  `design-source/` folder, for provenance / re-vectorizing if the source art
  changes.
- `vectorize.py` stays at repo root (the tool that regenerates the SVGs from
  the design-source art).
- Root `README.md` rewritten to describe the web app and link the live Pages
  URL, replacing the old Gatekeeper install instructions.
- `docs/2026-07-01-doac-border-app-design.md` and the native-app
  implementation plan stay as-is (historical record of why it was native
  first, and this doc explains why that changed).

## Rendering pipeline

Direct port of the existing render flow:

1. `frameLayout.make(mode, imageSize, spec, customSizeMM, orientation)`
   computes canvas size, hole rect, and per-side margins (corners/edges),
   exactly as `FrameLayout.swift` does today.
2. The photo is placed into the hole per `positionState` (contain-fit by
   default; drag+zoom overrides, same 0-4 zoom range and same clamp-to-both-
   axes-overflow logic already fixed and tested in the Swift version).
3. `frameRenderer.render(...)`:
   - Rasterizes the border SVG onto an *offscreen* canvas at
     `max(layout.scale, 1)` times its native size -- the same "never
     rasterize below native resolution" technique that fixed the wordmark
     pixelation in the native app, so thin borders never blur the logo.
   - Creates the final canvas at `canvasWidth x canvasHeight`.
   - Draws the placed photo into the hole rect.
   - Pastes the 4 corners + 4 edges from the rasterized border via
     `drawImage(source rect, dest rect)` -- a direct translation of the 8
     `paste()` calls in `FrameRenderer.swift`, including the wide
     bottom-right corner that protects the logo.
4. The final canvas doubles as the live preview (scaled down via CSS for
   on-screen display; export re-renders/reads back at full resolution).

## Interaction

- **Drag**: pointer events (`pointerdown`/`pointermove`/`pointerup`) update
  `panX`/`panY`, clamped exactly as `PositionState.swift` does.
- **Zoom**: trackpad pinch fires as `wheel` + `ctrlKey` in all major
  browsers -- that's the only zoom input, matching the native app (which
  only ever supported pinch, never a scroll/wheel zoom). Updates `zoom`
  additively (the same additive-not-multiplicative fix already validated
  for the native app's pinch-from-zero bug), clamped to the same 0-4 range.
  Plain scroll-wheel (no ctrlKey) is left alone -- no zoom side effect.
- **Cursor**: plain CSS (`cursor: grab` / `:active { cursor: grabbing }`) --
  simpler than the native `NSCursor` state juggling it replaces.
- **Reset button**: restores `position = auto` (default contain-fit).

## Custom sizing

Same model as `AppState.swift`: canonical size stored in millimeters, a
`cm`/`inch` unit toggle converts for display/input only, orientation is a
separate override on top of the numeric size.

## Testing

- `positionState.js` and `frameLayout.js` are pure math with no DOM/canvas
  dependency -- their existing Swift XCTest cases (`PositionStateTests`,
  `FrameLayoutTests`) port 1:1 to Node's built-in `node:test` +
  `node:assert`, run via `node --test web/tests/`. Zero added dependency,
  runs in CI on every PR.
- `frameRenderer.js`'s actual canvas/pixel output is verified manually in a
  real browser during implementation (load a photo, export, inspect the
  PNG) -- the same visual-verification approach used to confirm today's
  logo-crispness fix. No headless-canvas dependency is added solely for
  automated pixel tests, consistent with the zero-dependency goal.
- Before considering the port done: a real manual end-to-end pass in an
  actual browser -- drag-drop a photo, try both templates, all four modes,
  drag + trackpad-pinch reposition, Reset, export, and open the resulting
  PNG -- covering what the Swift test suite's `FrameRendererTests` /
  `BorderedImage` tests currently assert, plus the things only a live
  browser can show (gesture feel, cursor states, layout responsiveness).

## Error handling

- A failed/corrupt image load (bad file type, decode failure) shows an
  inline error message rather than silently leaving a blank/broken preview.
- The border SVGs are same-origin static assets bundled with the app, so
  they're expected to always load; if a fetch ever fails (e.g. a CDN hiccup
  on Pages), show an explicit error rather than exporting a photo with no
  border.

## Deployment

A GitHub Action (`.github/workflows/deploy.yml`) builds nothing (there's
nothing to build) and publishes the `web/` directory to GitHub Pages via
`actions/upload-pages-artifact` + `actions/deploy-pages` on every push to
`main` that touches `web/**`. A second, lightweight Action runs
`node --test web/tests/` on every PR. GitHub Pages needs to be switched to
"GitHub Actions" as its source once in repo settings (one-time, not
per-deploy).
