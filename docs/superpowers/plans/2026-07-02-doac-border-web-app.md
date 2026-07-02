# DOAC Border web app Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the native Swift/AppKit DOAC Border Mac app with a static, client-side web app (`web/`) hosted on GitHub Pages, so anyone can use it via a link with no install and no Gatekeeper friction.

**Architecture:** Plain ES modules under `web/js/`, each a direct 1:1 port of an existing (already-validated) Swift file. Canvas 2D handles SVG rasterization and 9-slice border compositing. No bundler, no `npm install` for the shipped app — GitHub Pages serves `web/` as-is. Pure-logic modules get Node-based unit tests (`node --test`); canvas/DOM behavior is verified manually in a real browser.

**Tech Stack:** Vanilla HTML/CSS/JavaScript (ES modules), Node's built-in test runner (`node:test`), GitHub Actions (test + Pages deploy).

**Reference spec:** `docs/superpowers/specs/2026-07-02-doac-border-web-app-design.md`

## Global Constraints

- No build step for the shipped `web/` app — plain ES modules loaded via `<script type="module">`, no bundler, no runtime npm dependencies.
- Desktop browsers only (mouse + trackpad). No mobile/touch optimization.
- **Canvas 2D is natively top-left-origin, y-down.** Do NOT port the Swift version's `flipDst`/context-flip logic — that existed only to compensate for CoreGraphics' bottom-left-origin default and has no equivalent need in a browser `<canvas>`. All rects in this port are plain top-left-origin `{x, y, width, height}`.
- Zoom range is `0` to `MAX_ZOOM = 4`. Zoom updates are **additive**, never multiplicative (mirrors the native app's validated pinch-from-zero fix: `newZoom = clamp(startZoom + delta, 0, 4)`, not `startZoom * factor`).
- Custom page size's canonical unit is millimeters. `cm`/`inch` are display-only conversions: `cm→mm: v*10`, `mm→cm: v/10`; `inch→mm: v*25.4`, `mm→inch: v/25.4`.
- Page layout constants (defaults, matching `FrameLayout.swift`): `pct = 0.08`, `minPx = 60`, `dpi = 300`.
- Template margins in SVG pixels (native SVG canvas is 1999×1545 for both, read from the loaded SVG image itself at render time — never hardcode native width/height, see Task 5):
  - **V1**: `left=203, top=190, right=235, bottom=210, bottomRight=380`
  - **V2**: `left=99, top=107, right=99, bottom=107, bottomRight=325`
- Border rasterization must never go below native SVG resolution: `renderScale = max(layout.scale, 1)`, so thin borders never blur the DOAC wordmark.
- Shared type shapes used across every module (keep these exact across all tasks):
  - **Size**: `{ width, height }`
  - **Rect**: `{ x, y, width, height }` (top-left origin)
  - **Position**: `{ zoom, panX, panY }`
  - **Spec**: `{ name, svgFilename, left, top, right, bottom, bottomRight }`
  - **Layout**: `{ scale, left, top, right, bottom, bottomRight, canvasWidth, canvasHeight, holeWidth, holeHeight }`
- File layout: everything lives under `web/` (`web/js/`, `web/assets/`, `web/tests/`), per the design spec.

---

## Task graph (for maximum parallel execution)

```
Task 1 (scaffold web/ + copy assets)
   |
   +--> Task 2  templateSpec.js          -\
   +--> Task 3  positionState.js + tests   |  Lane A -- fully parallel,
   +--> Task 4  frameLayout.js + tests     |  file-disjoint, no cross-imports
   +--> Task 5  frameRenderer.js           |
   +--> Task 6  exporter.js              -/
   +--> Task 7  retire native Swift app        (Lane B -- disjoint from web/js/*)
   +--> Task 8  CI workflows (test + deploy)   (Lane C -- disjoint YAML files)
                    |
   (needs 3, 4, 5) -+--> Task 9  borderedImage.js
                              |
        (needs 2, 6, 9)     -+--> Task 10  index.html + style.css + app.js
                                        |
        (needs 7, 8, 10)     ---------+--> Task 11  final verification + deploy
```

Tasks 2–8 have no file overlap and no import relationships between each other — they can all run as parallel subagents once Task 1 completes.

---

### Task 1: Scaffold `web/` and extract the border SVG assets

**Files:**
- Create: `web/assets/template-v1.svg` (copied from `DOACBorderApp/Resources/Template border V1.svg`)
- Create: `web/assets/template-v2.svg` (copied from `DOACBorderApp/Resources/Template border V2.svg`)
- Create: `web/package.json`
- Create directories: `web/js/`, `web/tests/`

**Interfaces:**
- Produces: `web/assets/template-v1.svg`, `web/assets/template-v2.svg` — the authoritative, already-fixed (crisp wordmark) SVG border templates every later task depends on. Produces `web/js/` and `web/tests/` as the homes for all subsequent module/test files. Produces `web/package.json` with `"type": "module"` so Node's test runner treats `.js` files under `web/` as ES modules.

This task must run before anything else — it is the sole prerequisite for every other task in this plan (Lane A needs `web/js/` and `web/tests/` to exist; Task 5 needs the real SVGs for its manual check; Task 7 needs the SVGs safely copied out *before* it deletes `DOACBorderApp/`).

- [ ] **Step 1: Create the directories and copy the SVGs**

```bash
cd "/Users/matthew.bellars/Documents/Research Team Projects/DOAC Graphs:Photos"
mkdir -p web/js web/assets web/tests
cp "DOACBorderApp/Resources/Template border V1.svg" "web/assets/template-v1.svg"
cp "DOACBorderApp/Resources/Template border V2.svg" "web/assets/template-v2.svg"
```

- [ ] **Step 2: Verify the copies are byte-identical to the source**

```bash
diff "DOACBorderApp/Resources/Template border V1.svg" "web/assets/template-v1.svg" && echo "V1 OK"
diff "DOACBorderApp/Resources/Template border V2.svg" "web/assets/template-v2.svg" && echo "V2 OK"
```

Expected: both print `diff` with no output followed by `V1 OK` / `V2 OK` (empty diff = identical).

- [ ] **Step 3: Create `web/package.json`**

```json
{
  "name": "doac-border-web",
  "private": true,
  "type": "module"
}
```

- [ ] **Step 4: Commit**

```bash
git add web/assets/template-v1.svg web/assets/template-v2.svg web/package.json
git commit -m "chore: scaffold web/ and extract the border SVG assets"
```

---

### Task 2: `templateSpec.js`

**Files:**
- Create: `web/js/templateSpec.js`

**Interfaces:**
- Produces: `TEMPLATE_SPECS` — an object keyed `v1`/`v2`, each a **Spec** (`{ name, svgFilename, left, top, right, bottom, bottomRight }`, see Global Constraints). Consumed by `app.js` (Task 10, to populate the template picker and look up `svgFilename`) and passed through as the `spec` parameter to `frameLayout.js` (Task 4) and `frameRenderer.js` (Task 5) — those two never import this module, they just receive a plain object matching the Spec shape.

No native-image-size field is included (the Swift version's `TemplateSpec.nativeSize` is dead code — `FrameRenderer.swift` actually reads the SVG's own parsed size, not that field — see Task 5).

- [ ] **Step 1: Write the module**

```js
// web/js/templateSpec.js
export const TEMPLATE_SPECS = {
  v1: {
    name: 'V1',
    svgFilename: 'template-v1.svg',
    left: 203,
    top: 190,
    right: 235,
    bottom: 210,
    bottomRight: 380,
  },
  v2: {
    name: 'V2',
    svgFilename: 'template-v2.svg',
    left: 99,
    top: 107,
    right: 99,
    bottom: 107,
    bottomRight: 325,
  },
};
```

- [ ] **Step 2: Sanity-check it loads under Node**

```bash
cd "/Users/matthew.bellars/Documents/Research Team Projects/DOAC Graphs:Photos"
node --input-type=module -e "import { TEMPLATE_SPECS } from './web/js/templateSpec.js'; console.log(TEMPLATE_SPECS.v1.bottomRight, TEMPLATE_SPECS.v2.bottomRight);"
```

Expected: `380 325`

- [ ] **Step 3: Commit**

```bash
git add web/js/templateSpec.js
git commit -m "feat(web): add template border margin specs"
```

---

### Task 3: `positionState.js` + tests

**Files:**
- Create: `web/js/positionState.js`
- Create: `web/tests/positionState.test.js`

**Interfaces:**
- Produces: `MAX_ZOOM` (number, `4`), `defaultPosition()` → **Position** (`{ zoom: 0, panX: 0.5, panY: 0.5 }`), `placement(position, imageSize, holeSize)` → **Rect**. Direct port of `PositionState.swift`'s `placement(imageSize:holeSize:)`. Consumed by `borderedImage.js` (Task 9) and `app.js` (Task 10, for drag/pinch state updates).
- Consumes: nothing (no imports).

This is a pure port of `DOACBorderApp/Sources/DOACBorderApp/PositionState.swift`. Same containment math, same clamp range, same "additive zoom" semantics (the caller, not this module, is responsible for doing the addition — this module just clamps whatever `zoom` it's given to `[0, MAX_ZOOM]`).

- [ ] **Step 1: Write the failing tests**

```js
// web/tests/positionState.test.js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { defaultPosition, placement } from '../js/positionState.js';

function approxEqual(actual, expected, tolerance, message) {
  assert.ok(
    Math.abs(actual - expected) <= tolerance,
    message || `expected ${actual} to be within ${tolerance} of ${expected}`
  );
}

test('default zoom contains whole image centered', () => {
  // 600x400 image (1.5 aspect) into a 500x500 hole (1.0 aspect):
  // contain scale = min(500/600, 500/400) = min(0.833, 1.25) = 0.833
  // drawWidth = 500, drawHeight = 333.3 -> centered vertically, no horizontal gap.
  const rect = placement(defaultPosition(), { width: 600, height: 400 }, { width: 500, height: 500 });
  approxEqual(rect.width, 500, 0.5);
  approxEqual(rect.height, 333.33, 0.5);
  approxEqual(rect.x, 0, 0.5);
  approxEqual(rect.y, (500 - 333.33) / 2, 0.5);
});

test('full zoom covers hole with no gutter', () => {
  const position = { ...defaultPosition(), zoom: 1 };
  // cover scale = max(500/600, 500/400) = max(0.833, 1.25) = 1.25
  const rect = placement(position, { width: 600, height: 400 }, { width: 500, height: 500 });
  approxEqual(rect.width, 750, 0.5); // 600*1.25
  approxEqual(rect.height, 500, 0.5); // 400*1.25, fills exactly
});

test('pan clamped within overflow range', () => {
  const position = { ...defaultPosition(), zoom: 1, panX: 0 };
  // overflow = 750 - 500 = 250; panX=0 -> offset 0 (left-aligned)
  const rect = placement(position, { width: 600, height: 400 }, { width: 500, height: 500 });
  approxEqual(rect.x, 0, 0.5);
});

test('zoom past cover allows panning both axes', () => {
  // At zoom<=1 a non-square image only overflows on one axis, so the other
  // axis can't pan. Past cover (zoom>1) both axes must overflow and respond.
  const imageSize = { width: 600, height: 400 };
  const holeSize = { width: 500, height: 500 };
  const atStart = placement({ zoom: 2, panX: 0, panY: 0 }, imageSize, holeSize);
  const atEnd = placement({ zoom: 2, panX: 1, panY: 1 }, imageSize, holeSize);
  assert.notEqual(atStart.x, atEnd.x, 'panX should move the image once zoomed past cover');
  assert.notEqual(atStart.y, atEnd.y, 'panY should move the image once zoomed past cover');
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd "/Users/matthew.bellars/Documents/Research Team Projects/DOAC Graphs:Photos"
node --test web/tests/positionState.test.js
```

Expected: FAIL — `Cannot find module '../js/positionState.js'`

- [ ] **Step 3: Write the implementation**

```js
// web/js/positionState.js
export const MAX_ZOOM = 4;

export function defaultPosition() {
  return { zoom: 0, panX: 0.5, panY: 0.5 };
}

// Rect (top-left origin, in hole pixel space) to draw the full source image
// into, given the hole size and the image's own native size.
export function placement(position, imageSize, holeSize) {
  if (imageSize.width <= 0 || imageSize.height <= 0) {
    return { x: 0, y: 0, width: 0, height: 0 };
  }

  const containScale = Math.min(holeSize.width / imageSize.width, holeSize.height / imageSize.height);
  const coverScale = Math.max(holeSize.width / imageSize.width, holeSize.height / imageSize.height);
  const zoom = Math.min(Math.max(position.zoom, 0), MAX_ZOOM);
  const scale = containScale + (coverScale - containScale) * zoom;

  const drawWidth = imageSize.width * scale;
  const drawHeight = imageSize.height * scale;

  const maxOffsetX = Math.max(0, drawWidth - holeSize.width);
  const maxOffsetY = Math.max(0, drawHeight - holeSize.height);
  const panX = Math.min(Math.max(position.panX, 0), 1);
  const panY = Math.min(Math.max(position.panY, 0), 1);

  const x = maxOffsetX > 0 ? -maxOffsetX * panX : (holeSize.width - drawWidth) / 2;
  const y = maxOffsetY > 0 ? -maxOffsetY * panY : (holeSize.height - drawHeight) / 2;

  return { x, y, width: drawWidth, height: drawHeight };
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
node --test web/tests/positionState.test.js
```

Expected: PASS — `# tests 4`, `# pass 4`, `# fail 0`

- [ ] **Step 5: Commit**

```bash
git add web/js/positionState.js web/tests/positionState.test.js
git commit -m "feat(web): port PositionState pan/zoom containment math"
```

---

### Task 4: `frameLayout.js` + tests

**Files:**
- Create: `web/js/frameLayout.js`
- Create: `web/tests/frameLayout.test.js`

**Interfaces:**
- Produces: `makeLayout(mode, imageSize, spec, opts)` → **Layout**. `mode` is one of `'free' | 'a4' | 'a5' | 'custom'`. `opts` is `{ customSizeMM, orientation, pct, minPx, dpi }`, all optional (defaults: `customSizeMM: {width:210,height:297}`, `orientation: 'auto'`, `pct: 0.08`, `minPx: 60`, `dpi: 300`). `orientation` is one of `'auto' | 'portrait' | 'landscape'`. Consumed by `borderedImage.js` (Task 9) and `app.js` (Task 10).
- Consumes: nothing (no imports; `spec` is a duck-typed **Spec** shape, no import of `templateSpec.js` needed).

Direct port of `FrameLayout.swift`'s `make(mode:imageSize:spec:customSizeMM:orientation:pct:minPx:dpi:)` and its private `freeForm` helper. Swift's `.rounded()` (round-half-away-from-zero) and JS's `Math.round()` (round-half-up) agree for all positive inputs, which is every value here — verified against the ported test values below.

- [ ] **Step 1: Write the failing tests**

```js
// web/tests/frameLayout.test.js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { makeLayout } from '../js/frameLayout.js';

const specV1 = { left: 203, top: 190, right: 235, bottom: 210, bottomRight: 380 };

test('free mode matches validated output', () => {
  // Same inputs as the native app's validated test: 836x534 image, V1, defaults.
  const layout = makeLayout('free', { width: 836, height: 534 }, specV1);
  assert.equal(layout.left, 60);
  assert.equal(layout.top, 56);
  assert.equal(layout.right, 69);
  assert.equal(layout.bottom, 62);
  assert.equal(layout.bottomRight, 112);
  assert.equal(layout.canvasWidth, 965);
  assert.equal(layout.canvasHeight, 652);
  assert.equal(layout.holeWidth, 836);
  assert.equal(layout.holeHeight, 534);
});

test('a4 landscape matches validated output', () => {
  // Same inputs as the native app's validated A4 test: 600x400 landscape image, V1, 300dpi.
  const layout = makeLayout('a4', { width: 600, height: 400 }, specV1);
  assert.equal(layout.canvasWidth, 3508);
  assert.equal(layout.canvasHeight, 2480);
  assert.equal(layout.left, 198);
  assert.equal(layout.top, 186);
  assert.equal(layout.right, 230);
  assert.equal(layout.bottom, 205);
  assert.equal(layout.bottomRight, 371);
  assert.equal(layout.holeWidth, 3080);
  assert.equal(layout.holeHeight, 2089);
});

test('minPx floor protects small images', () => {
  // 250x180 image: 8% of 180 = 14.4, well under the 60px floor.
  const layout = makeLayout('free', { width: 250, height: 180 }, specV1);
  assert.equal(layout.left, 60);
});

test('custom size uses provided millimeters', () => {
  // 100x150mm at 300dpi: 100/25.4*300 = 1181.1 -> 1181, 150/25.4*300 = 1771.65 -> 1772.
  const layout = makeLayout('custom', { width: 600, height: 400 }, specV1, {
    customSizeMM: { width: 100, height: 150 },
    orientation: 'portrait',
  });
  assert.equal(layout.canvasWidth, 1181);
  assert.equal(layout.canvasHeight, 1772);
});

test('explicit orientation overrides image aspect', () => {
  // A portrait-shaped image would auto-orient the page portrait; an explicit
  // 'landscape' orientation must force the page landscape regardless.
  const layout = makeLayout('a4', { width: 300, height: 600 }, specV1, { orientation: 'landscape' });
  assert.equal(layout.canvasWidth, 3508);
  assert.equal(layout.canvasHeight, 2480);
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd "/Users/matthew.bellars/Documents/Research Team Projects/DOAC Graphs:Photos"
node --test web/tests/frameLayout.test.js
```

Expected: FAIL — `Cannot find module '../js/frameLayout.js'`

- [ ] **Step 3: Write the implementation**

```js
// web/js/frameLayout.js
const DEFAULT_CUSTOM_SIZE_MM = { width: 210, height: 297 };

export function makeLayout(mode, imageSize, spec, opts = {}) {
  const {
    customSizeMM = DEFAULT_CUSTOM_SIZE_MM,
    orientation = 'auto',
    pct = 0.08,
    minPx = 60,
    dpi = 300,
  } = opts;

  if (mode === 'free') {
    return freeForm(imageSize, spec, pct, minPx);
  }

  let mm;
  if (mode === 'a4') mm = { width: 210, height: 297 };
  else if (mode === 'a5') mm = { width: 148, height: 210 };
  else if (mode === 'custom') mm = customSizeMM;
  else throw new Error(`Unknown page mode: ${mode}`);

  let mmW = mm.width;
  let mmH = mm.height;
  if (orientation === 'auto') {
    if (imageSize.width > imageSize.height) [mmW, mmH] = [mmH, mmW];
  } else if (orientation === 'portrait') {
    if (mmW > mmH) [mmW, mmH] = [mmH, mmW];
  } else if (orientation === 'landscape') {
    if (mmH > mmW) [mmW, mmH] = [mmH, mmW];
  }

  const canvasWidth = Math.round((mmW / 25.4) * dpi);
  const canvasHeight = Math.round((mmH / 25.4) * dpi);

  const scale = Math.max(pct * Math.min(canvasWidth, canvasHeight), minPx) / spec.left;
  const left = Math.round(spec.left * scale);
  const top = Math.round(spec.top * scale);
  const right = Math.round(spec.right * scale);
  const bottom = Math.round(spec.bottom * scale);
  const bottomRight = Math.round(spec.bottomRight * scale);

  return {
    scale, left, top, right, bottom, bottomRight,
    canvasWidth, canvasHeight,
    holeWidth: canvasWidth - left - right,
    holeHeight: canvasHeight - top - bottom,
  };
}

function freeForm(imageSize, spec, pct, minPx) {
  const leftTarget = Math.max(pct * Math.min(imageSize.width, imageSize.height), minPx);
  const scale = leftTarget / spec.left;
  const left = Math.round(spec.left * scale);
  const top = Math.round(spec.top * scale);
  const right = Math.round(spec.right * scale);
  const bottom = Math.round(spec.bottom * scale);
  const bottomRight = Math.round(spec.bottomRight * scale);
  const holeWidth = Math.round(imageSize.width);
  const holeHeight = Math.round(imageSize.height);
  return {
    scale, left, top, right, bottom, bottomRight,
    canvasWidth: left + holeWidth + right,
    canvasHeight: top + holeHeight + bottom,
    holeWidth, holeHeight,
  };
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
node --test web/tests/frameLayout.test.js
```

Expected: PASS — `# tests 5`, `# pass 5`, `# fail 0`

- [ ] **Step 5: Commit**

```bash
git add web/js/frameLayout.js web/tests/frameLayout.test.js
git commit -m "feat(web): port FrameLayout page sizing/margin/orientation math"
```

---

### Task 5: `frameRenderer.js`

**Files:**
- Create: `web/js/frameRenderer.js`
- Create: `web/tests/manual-frame-renderer-check.html`

**Interfaces:**
- Produces: `renderFrame(holeContent, layout, spec, svgImage)` → `HTMLCanvasElement` sized `layout.canvasWidth × layout.canvasHeight`. `holeContent` is any `CanvasImageSource` (canvas/image/bitmap) already exactly `layout.holeWidth × layout.holeHeight`. `svgImage` is an already-loaded `HTMLImageElement` pointing at one of the `web/assets/*.svg` files. Consumed by `borderedImage.js` (Task 9).
- Consumes: nothing (no imports). Uses `spec` (Spec shape) and `layout` (Layout shape) as plain parameters.

Direct port of `FrameRenderer.swift`'s `render(holeContent:layout:spec:svgURL:)` — same `renderScale = max(layout.scale, 1)` never-below-native-resolution technique, same 8 corner/edge paste operations. **Simplification vs. the Swift version:** Canvas 2D is already top-left-origin/y-down, so none of `flipDst`/the border-context flip is needed — every rect below is used exactly as computed, no Y-flipping. The native SVG resolution is read from `svgImage.width`/`svgImage.height` (the browser's own parsed intrinsic size), not a hardcoded constant — this mirrors what `FrameRenderer.swift` actually does (it reads `svg.size` from the parsed file; `TemplateSpec.nativeSize` in the Swift code is unused dead data, not ported here).

- [ ] **Step 1: Write the implementation**

```js
// web/js/frameRenderer.js
export function renderFrame(holeContent, layout, spec, svgImage) {
  // Rasterize the border at a resolution independent of layout.scale. The
  // border is vector, so it can render crisply at any size -- but
  // layout.scale shrinks for thin borders (small images/pages), which would
  // also shrink the small-but-detailed DOAC wordmark to a blocky size.
  // Never rasterize below native SVG resolution; corners/edges below
  // downsample from this into the (possibly smaller) target size, which
  // stays crisp, instead of upsampling a low-res render.
  const renderScale = Math.max(layout.scale, 1);
  const nW = Math.round(svgImage.width * renderScale);
  const nH = Math.round(svgImage.height * renderScale);

  const borderCanvas = document.createElement('canvas');
  borderCanvas.width = nW;
  borderCanvas.height = nH;
  const borderCtx = borderCanvas.getContext('2d');
  borderCtx.drawImage(svgImage, 0, 0, nW, nH);

  const cw = layout.canvasWidth;
  const ch = layout.canvasHeight;
  const canvas = document.createElement('canvas');
  canvas.width = cw;
  canvas.height = ch;
  const ctx = canvas.getContext('2d');
  ctx.imageSmoothingEnabled = true;
  ctx.imageSmoothingQuality = 'high';

  ctx.drawImage(holeContent, layout.left, layout.top, layout.holeWidth, layout.holeHeight);

  const paste = (sx, sy, sw, sh, dx, dy, dw, dh) => {
    ctx.drawImage(borderCanvas, sx, sy, sw, sh, dx, dy, dw, dh);
  };

  const { left, top, right, bottom, bottomRight: brW } = layout;
  const srcLeft = spec.left * renderScale;
  const srcTop = spec.top * renderScale;
  const srcRight = spec.right * renderScale;
  const srcBottom = spec.bottom * renderScale;
  const srcBrW = spec.bottomRight * renderScale;

  // corners (native to the render raster, downsampled to the target size)
  paste(0, 0, srcLeft, srcTop, 0, 0, left, top);
  paste(nW - srcRight, 0, srcRight, srcTop, cw - right, 0, right, top);
  paste(0, nH - srcBottom, srcLeft, srcBottom, 0, ch - bottom, left, bottom);
  paste(nW - srcBrW, nH - srcBottom, srcBrW, srcBottom, cw - brW, ch - bottom, brW, bottom);

  // edges (stretched only along their length)
  paste(srcLeft, 0, nW - srcRight - srcLeft, srcTop, left, 0, cw - left - right, top);
  const bottomEdgeW = cw - left - brW;
  paste(srcLeft, nH - srcBottom, nW - srcBrW - srcLeft, srcBottom, left, ch - bottom, bottomEdgeW, bottom);
  paste(0, srcTop, srcLeft, nH - srcBottom - srcTop, 0, top, left, ch - bottom - top);
  paste(nW - srcRight, srcTop, srcRight, nH - srcBottom - srcTop, cw - right, top, right, ch - bottom - top);

  return canvas;
}
```

- [ ] **Step 2: Write a manual visual-check harness**

```html
<!-- web/tests/manual-frame-renderer-check.html -->
<!doctype html>
<html>
<head><meta charset="utf-8" /><title>frameRenderer manual check</title></head>
<body>
  <p>Expect: a bordered square with a light-blue center, crisp "DOAC" wordmark
     bottom-right, no pixelation.</p>
  <canvas id="out"></canvas>
  <script type="module">
    import { renderFrame } from '../js/frameRenderer.js';

    function loadImage(url) {
      return new Promise((resolve, reject) => {
        const img = new Image();
        img.onload = () => resolve(img);
        img.onerror = reject;
        img.src = url;
      });
    }

    const spec = { left: 203, top: 190, right: 235, bottom: 210, bottomRight: 380 };
    const layout = {
      scale: 0.3, left: 61, top: 57, right: 71, bottom: 63, bottomRight: 114,
      canvasWidth: 968, canvasHeight: 654, holeWidth: 836, holeHeight: 534,
    };

    const holeCanvas = document.createElement('canvas');
    holeCanvas.width = layout.holeWidth;
    holeCanvas.height = layout.holeHeight;
    holeCanvas.getContext('2d').fillStyle = '#99c2e8';
    holeCanvas.getContext('2d').fillRect(0, 0, layout.holeWidth, layout.holeHeight);

    const svgImage = await loadImage('../assets/template-v1.svg');
    const result = renderFrame(holeCanvas, layout, spec, svgImage);

    const out = document.getElementById('out');
    out.width = result.width;
    out.height = result.height;
    out.getContext('2d').drawImage(result, 0, 0);
  </script>
</body>
</html>
```

- [ ] **Step 3: Manually verify in a browser**

```bash
cd "/Users/matthew.bellars/Documents/Research Team Projects/DOAC Graphs:Photos/web"
python3 -m http.server 8000
```

Open `http://localhost:8000/tests/manual-frame-renderer-check.html`. Confirm: a light-blue square with a black/white DOAC border around it, and the "DOAC" wordmark bottom-right is sharp with clean letter edges at whatever zoom level you view the page at — no visible blockiness. Stop the server (Ctrl-C) when done.

- [ ] **Step 4: Commit**

```bash
git add web/js/frameRenderer.js web/tests/manual-frame-renderer-check.html
git commit -m "feat(web): port FrameRenderer canvas compositing"
```

---

### Task 6: `exporter.js`

**Files:**
- Create: `web/js/exporter.js`

**Interfaces:**
- Produces: `downloadCanvasAsPNG(canvas, filename)` → `Promise<void>`. Triggers a browser download of `canvas` encoded as PNG, named `filename`. Rejects if PNG encoding fails. Consumed by `app.js` (Task 10).
- Consumes: nothing (no imports).

Direct port of `Exporter.swift`'s `writePNG(_:to:)`, adapted to the browser's blob-and-download-link pattern (there is no native "save panel" on the web — a `<a download>` click triggers the browser's own save UI).

- [ ] **Step 1: Write the module**

```js
// web/js/exporter.js
export function downloadCanvasAsPNG(canvas, filename) {
  return new Promise((resolve, reject) => {
    canvas.toBlob((blob) => {
      if (!blob) {
        reject(new Error('Failed to encode PNG'));
        return;
      }
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
      resolve();
    }, 'image/png');
  });
}
```

- [ ] **Step 2: Sanity-check the module has no syntax errors**

```bash
cd "/Users/matthew.bellars/Documents/Research Team Projects/DOAC Graphs:Photos"
node --check web/js/exporter.js && echo "syntax OK"
```

Expected: `syntax OK` (this only checks parse-validity; `downloadCanvasAsPNG` itself needs `document`/`URL`/canvas APIs, so its real behavior is verified in Task 10's manual browser pass, not here — consistent with the design spec's "no headless-canvas dependency" testing approach.)

- [ ] **Step 3: Commit**

```bash
git add web/js/exporter.js
git commit -m "feat(web): add canvas-to-PNG download helper"
```

---

### Task 7: Retire the native Swift app and tidy the repo root

**Files:**
- Delete: `DOACBorderApp/` (entire directory — Swift source, tests, `build_app.sh`, its README)
- Delete: `Template border V1.svg`, `Template border V2.svg` (stale root-level duplicates, superseded by `web/assets/*.svg`)
- Move to `design-source/`: `Template border V1.png`, `Template border V2.png`, `Template border.psd`, `DOAC_Logo_W2.png`, `DOAC_Logo_W2.svg`
- Create: `README.md` (repo root — none currently exists at root)

**Interfaces:**
- Produces: `design-source/` (original design art, for provenance/regeneration only — nothing in `web/` reads from it), a root `README.md` describing the web app.
- Consumes: nothing from other tasks' outputs, but **must run after Task 1** has already copied the SVGs into `web/assets/` (this task deletes `DOACBorderApp/Resources/`, the source those copies came from).

File-disjoint from every `web/**` path touched by Lanes A/C, so it's safe to run fully in parallel with Tasks 2–6, 8.

- [ ] **Step 1: Confirm the root-level SVG duplicates are stale**

```bash
cd "/Users/matthew.bellars/Documents/Research Team Projects/DOAC Graphs:Photos"
diff "Template border V1.svg" "DOACBorderApp/Resources/Template border V1.svg"; echo "exit: $?"
diff "Template border V2.svg" "DOACBorderApp/Resources/Template border V2.svg"; echo "exit: $?"
```

Expected: both `diff`s print changes and `exit: 1` (they differ — the root copies predate this session's crispness/wordmark fixes to `DOACBorderApp/Resources/`, which are the ones already copied into `web/assets/` by Task 1). If either instead prints `exit: 0` (identical), that's fine too — it just means this particular file has no stale content to worry about; proceed with deletion regardless, since the canonical copy now lives in `web/assets/`.

- [ ] **Step 2: Delete the native app and the stale root SVGs**

```bash
git rm -r "DOACBorderApp"
git rm "Template border V1.svg" "Template border V2.svg"
```

- [ ] **Step 3: Move design-source art into `design-source/`**

```bash
mkdir -p design-source
git mv "Template border V1.png" "Template border V2.png" "Template border.psd" "DOAC_Logo_W2.png" "DOAC_Logo_W2.svg" design-source/
```

- [ ] **Step 4: Create the root README**

```markdown
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
```

Save that content to `README.md` at the repo root.

- [ ] **Step 5: Verify the repo root looks right**

```bash
ls
```

Expected: `README.md`, `CLAUDE.md`, `design-source/`, `docs/`, `vectorize.py`, `web/`, `.git`, `.gitignore`, `.claude/` — no `DOACBorderApp/`, no root-level `Template border V*.svg`, no loose `.png`/`.psd`/logo files at the top level.

- [ ] **Step 6: Commit**

```bash
git add README.md
git commit -m "chore: retire the native Swift app, replaced by web/

Deletes DOACBorderApp/ (unsigned/ad-hoc Mac app, Gatekeeper friction for
every recipient) now that the web app under web/ covers the same
features with zero install. Moves original design art into
design-source/ for provenance; the border SVGs it produced now live at
web/assets/, copied out before this deletion."
```

---

### Task 8: CI workflows (test + deploy)

**Files:**
- Create: `.github/workflows/test.yml`
- Create: `.github/workflows/deploy.yml`

**Interfaces:**
- Produces: a `test` GitHub Actions workflow that runs `node --test web/tests/` on every PR and push to `main` touching `web/**`; a `deploy` workflow that publishes `web/` to GitHub Pages on every push to `main` touching `web/**`.
- Consumes: nothing from other tasks (pure YAML referencing the `web/` path convention already fixed by the design spec — doesn't need `web/`'s contents to exist yet to be valid).

File-disjoint from every other task, safe to run fully in parallel with Tasks 2–7.

- [ ] **Step 1: Write the test workflow**

```yaml
# .github/workflows/test.yml
name: Test

on:
  pull_request:
    paths:
      - 'web/**'
  push:
    branches: [main]
    paths:
      - 'web/**'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: node --test web/tests/
```

- [ ] **Step 2: Write the deploy workflow**

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main]
    paths:
      - 'web/**'
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/configure-pages@v5
      - uses: actions/upload-pages-artifact@v3
        with:
          path: web
      - id: deployment
        uses: actions/deploy-pages@v4
```

- [ ] **Step 3: Validate the YAML parses**

```bash
cd "/Users/matthew.bellars/Documents/Research Team Projects/DOAC Graphs:Photos"
python3 -c "import yaml, sys; [yaml.safe_load(open(f)) for f in ['.github/workflows/test.yml', '.github/workflows/deploy.yml']]; print('YAML OK')"
```

Expected: `YAML OK`. (If `pyyaml` isn't installed, run `pip3 install --user pyyaml` first, or just visually confirm indentation is consistent — either is acceptable, this is a syntax sanity check, not a functional one.)

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/test.yml .github/workflows/deploy.yml
git commit -m "ci: add web/ test runner and GitHub Pages deploy workflows"
```

---

### Task 9: `borderedImage.js`

**Files:**
- Create: `web/js/borderedImage.js`
- Create: `web/tests/manual-bordered-image-check.html`

**Interfaces:**
- Produces: `makeHoleContent(photo, layout, position, mode)` → `HTMLCanvasElement` sized `layout.holeWidth × layout.holeHeight`. `makeBorderedImage(photo, mode, spec, svgImage, opts)` → `HTMLCanvasElement` sized `layout.canvasWidth × layout.canvasHeight`, the full rendered/exportable result. `opts` is `{ position, customSizeMM, orientation }`, all optional. `photo` is any `CanvasImageSource` (canvas/image/bitmap) with `.width`/`.height`. Consumed by `app.js` (Task 10).
- Consumes: `placement` from `web/js/positionState.js` (Task 3), `makeLayout` from `web/js/frameLayout.js` (Task 4), `renderFrame` from `web/js/frameRenderer.js` (Task 5).

**Depends on:** Tasks 3, 4, 5.

Direct port of `BorderedImage.swift`'s `make(photo:mode:spec:svgURL:position:customSizeMM:orientation:)`. No Y-flip needed for the placement rect (see Global Constraints) — `placement()`'s top-left-origin rect is used as-is.

- [ ] **Step 1: Write the implementation**

```js
// web/js/borderedImage.js
import { placement } from './positionState.js';
import { makeLayout } from './frameLayout.js';
import { renderFrame } from './frameRenderer.js';

export function makeHoleContent(photo, layout, position, mode) {
  const holeCanvas = document.createElement('canvas');
  holeCanvas.width = layout.holeWidth;
  holeCanvas.height = layout.holeHeight;
  const ctx = holeCanvas.getContext('2d');
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, layout.holeWidth, layout.holeHeight);

  const photoSize = { width: photo.width, height: photo.height };
  const holeSize = { width: layout.holeWidth, height: layout.holeHeight };
  const rect = mode === 'free'
    ? { x: 0, y: 0, width: holeSize.width, height: holeSize.height } // whole image, untouched, no crop
    : placement(position, photoSize, holeSize);

  ctx.drawImage(photo, rect.x, rect.y, rect.width, rect.height);
  return holeCanvas;
}

export function makeBorderedImage(photo, mode, spec, svgImage, opts = {}) {
  const {
    position = { zoom: 0, panX: 0.5, panY: 0.5 },
    customSizeMM = { width: 210, height: 297 },
    orientation = 'auto',
  } = opts;

  const photoSize = { width: photo.width, height: photo.height };
  const layout = makeLayout(mode, photoSize, spec, { customSizeMM, orientation });
  const holeContent = makeHoleContent(photo, layout, position, mode);
  return renderFrame(holeContent, layout, spec, svgImage);
}
```

- [ ] **Step 2: Write a manual visual-check harness**

```html
<!-- web/tests/manual-bordered-image-check.html -->
<!doctype html>
<html>
<head><meta charset="utf-8" /><title>borderedImage manual check</title></head>
<body>
  <p>Expect two bordered images below: left is Free mode (border hugs a
     400x300 photo exactly); right is A4 landscape mode (photo placed inside
     a full A4 page). Both should show a crisp DOAC wordmark bottom-right.</p>
  <canvas id="free-out"></canvas>
  <canvas id="a4-out"></canvas>
  <script type="module">
    import { makeBorderedImage } from '../js/borderedImage.js';

    function loadImage(url) {
      return new Promise((resolve, reject) => {
        const img = new Image();
        img.onload = () => resolve(img);
        img.onerror = reject;
        img.src = url;
      });
    }

    function makeSyntheticPhoto(width, height) {
      const canvas = document.createElement('canvas');
      canvas.width = width;
      canvas.height = height;
      const ctx = canvas.getContext('2d');
      ctx.fillStyle = '#99c2e8';
      ctx.fillRect(0, 0, width, height);
      return canvas;
    }

    const spec = { left: 203, top: 190, right: 235, bottom: 210, bottomRight: 380 };
    const svgImage = await loadImage('../assets/template-v1.svg');
    const photo = makeSyntheticPhoto(400, 300);

    const freeResult = makeBorderedImage(photo, 'free', spec, svgImage);
    const freeOut = document.getElementById('free-out');
    freeOut.width = freeResult.width;
    freeOut.height = freeResult.height;
    freeOut.getContext('2d').drawImage(freeResult, 0, 0);

    const a4Result = makeBorderedImage(photo, 'a4', spec, svgImage, { orientation: 'landscape' });
    const a4Out = document.getElementById('a4-out');
    a4Out.width = a4Result.width;
    a4Out.height = a4Result.height;
    a4Out.getContext('2d').drawImage(a4Result, 0, 0);
  </script>
</body>
</html>
```

- [ ] **Step 3: Manually verify in a browser**

```bash
cd "/Users/matthew.bellars/Documents/Research Team Projects/DOAC Graphs:Photos/web"
python3 -m http.server 8000
```

Open `http://localhost:8000/tests/manual-bordered-image-check.html`. Confirm: the left canvas shows a small bordered square tightly hugging the light-blue photo; the right canvas shows a much larger A4-proportioned page with the same photo placed (letterboxed) inside the frame, wider than tall. Both show a crisp DOAC wordmark bottom-right. Stop the server when done.

- [ ] **Step 4: Commit**

```bash
git add web/js/borderedImage.js web/tests/manual-bordered-image-check.html
git commit -m "feat(web): port BorderedImage glue (photo+mode+position -> final canvas)"
```

---

### Task 10: `index.html` + `style.css` + `app.js`

**Files:**
- Create: `web/index.html`
- Create: `web/style.css`
- Create: `web/js/app.js`

**Interfaces:**
- Consumes: `TEMPLATE_SPECS` from `templateSpec.js` (Task 2), `downloadCanvasAsPNG` from `exporter.js` (Task 6), `makeBorderedImage` from `borderedImage.js` (Task 9, which transitively pulls in Tasks 3, 4, 5), `defaultPosition` from `positionState.js` (Task 3).
- Produces: the full interactive app — this is the plan's UI integration point; nothing else depends on it.

**Depends on:** Tasks 2, 6, 9 (transitively 3, 4, 5).

Direct port of `ContentView.swift` + `AppState.swift`'s UI/interaction logic, adapted to plain DOM: SwiftUI's segmented pickers become button groups toggling a `.selected` class; `NSCursor` hand states become CSS `cursor: grab`/`grabbing`; `DragGesture`/`MagnificationGesture` become Pointer Events and `wheel`+`ctrlKey` (trackpad pinch); `NSOpenPanel`/`NSSavePanel` become a hidden `<input type=file>` and `exporter.js`'s download link.

- [ ] **Step 1: Write `index.html`**

```html
<!-- web/index.html -->
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>DOAC Border</title>
  <link rel="stylesheet" href="style.css" />
</head>
<body>
  <main>
    <div id="preview" class="preview">
      <canvas id="preview-canvas" class="hidden"></canvas>
      <div id="drop-hint" class="drop-hint">
        <p>Drop an image here</p>
        <button type="button" class="choose-button">Choose Image&hellip;</button>
      </div>
    </div>

    <div class="controls">
      <div class="segmented" id="template-picker">
        <button type="button" data-value="v1" class="selected">V1</button>
        <button type="button" data-value="v2">V2</button>
      </div>

      <div class="segmented" id="mode-picker">
        <button type="button" data-value="free" class="selected">Free size</button>
        <button type="button" data-value="a4">A4</button>
        <button type="button" data-value="a5">A5</button>
        <button type="button" data-value="custom">Custom</button>
      </div>

      <div id="page-settings" class="page-settings hidden">
        <div id="custom-size-row" class="custom-size-row hidden">
          <span>Size</span>
          <input id="custom-width" type="number" min="1" step="0.1" />
          <span>&times;</span>
          <input id="custom-height" type="number" min="1" step="0.1" />
          <div class="segmented segmented-small" id="unit-picker">
            <button type="button" data-value="cm" class="selected">cm</button>
            <button type="button" data-value="inch">in</button>
          </div>
        </div>
        <div class="segmented" id="orientation-picker">
          <button type="button" data-value="portrait" class="selected">Portrait</button>
          <button type="button" data-value="landscape">Landscape</button>
        </div>
      </div>

      <div id="positioning" class="positioning hidden">
        <span class="hint">Drag or pinch the preview image to reposition and zoom</span>
        <button id="reset-button" type="button">Reset</button>
      </div>

      <div class="button-row">
        <button type="button" class="choose-button">Choose Image&hellip;</button>
        <button id="export-button" type="button" disabled>Export&hellip;</button>
      </div>
    </div>

    <p id="error-message" class="error hidden"></p>
  </main>

  <input id="file-input" type="file" accept="image/png,image/jpeg,image/tiff" hidden />

  <script type="module" src="js/app.js"></script>
</body>
</html>
```

- [ ] **Step 2: Write `style.css`**

```css
/* web/style.css */
:root {
  color-scheme: light dark;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
}

body {
  margin: 0;
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f4f4f5;
  color: #1c1c1e;
}

main {
  width: min(560px, 100vw - 32px);
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 16px;
}

.preview {
  position: relative;
  min-height: 360px;
  border-radius: 8px;
  background: rgba(0, 0, 0, 0.04);
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}

#preview-canvas {
  max-width: 100%;
  max-height: 480px;
  display: block;
  touch-action: none;
}

#preview-canvas.hidden {
  display: none;
}

#preview-canvas.grab {
  cursor: grab;
}

#preview-canvas.grabbing {
  cursor: grabbing;
}

.drop-hint {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  color: #6b6b70;
}

.drop-hint.hidden {
  display: none;
}

.controls {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.segmented {
  display: flex;
  border: 1px solid #d0d0d5;
  border-radius: 6px;
  overflow: hidden;
}

.segmented button {
  flex: 1;
  padding: 6px 10px;
  border: none;
  background: #fff;
  cursor: pointer;
  font-size: 13px;
}

.segmented button + button {
  border-left: 1px solid #d0d0d5;
}

.segmented button.selected {
  background: #1c1c1e;
  color: #fff;
}

.segmented-small {
  width: 90px;
  flex: none;
}

.page-settings {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.page-settings.hidden {
  display: none;
}

.custom-size-row {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 13px;
}

.custom-size-row.hidden {
  display: none;
}

.custom-size-row input {
  width: 56px;
  padding: 4px;
}

.positioning {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}

.positioning.hidden {
  display: none;
}

.positioning .hint {
  font-size: 12px;
  color: #6b6b70;
}

.button-row {
  display: flex;
  justify-content: space-between;
  gap: 8px;
}

button {
  font: inherit;
}

.button-row button,
.drop-hint button,
#reset-button {
  padding: 6px 14px;
  border-radius: 6px;
  border: 1px solid #d0d0d5;
  background: #fff;
  cursor: pointer;
}

.error {
  color: #c0392b;
  font-size: 12px;
}

.error.hidden {
  display: none;
}
```

- [ ] **Step 3: Write `app.js`**

```js
// web/js/app.js
import { TEMPLATE_SPECS } from './templateSpec.js';
import { defaultPosition } from './positionState.js';
import { makeBorderedImage } from './borderedImage.js';
import { downloadCanvasAsPNG } from './exporter.js';

const state = {
  photo: null,
  photoName: null,
  template: 'v1',
  mode: 'free',
  position: defaultPosition(),
  orientation: 'portrait',
  customWidthMM: 210,
  customHeightMM: 297,
  customSizeUnit: 'cm',
  rendered: null,
  errorMessage: null,
};

const svgImages = {};

function loadImage(url) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error(`Failed to load ${url}`));
    img.src = url;
  });
}

async function getSvgImage(templateKey) {
  if (!svgImages[templateKey]) {
    const spec = TEMPLATE_SPECS[templateKey];
    svgImages[templateKey] = await loadImage(`assets/${spec.svgFilename}`);
  }
  return svgImages[templateKey];
}

const mmFromUnit = { cm: (v) => v * 10, inch: (v) => v * 25.4 };
const unitFromMm = { cm: (mm) => mm / 10, inch: (mm) => mm / 25.4 };

const previewCanvas = document.getElementById('preview-canvas');
const dropHint = document.getElementById('drop-hint');
const preview = document.getElementById('preview');
const fileInput = document.getElementById('file-input');
const templatePicker = document.getElementById('template-picker');
const modePicker = document.getElementById('mode-picker');
const pageSettings = document.getElementById('page-settings');
const customSizeRow = document.getElementById('custom-size-row');
const customWidthInput = document.getElementById('custom-width');
const customHeightInput = document.getElementById('custom-height');
const unitPicker = document.getElementById('unit-picker');
const orientationPicker = document.getElementById('orientation-picker');
const positioning = document.getElementById('positioning');
const resetButton = document.getElementById('reset-button');
const exportButton = document.getElementById('export-button');
const errorMessage = document.getElementById('error-message');

function setSegmentedValue(container, value) {
  container.querySelectorAll('button').forEach((btn) => {
    btn.classList.toggle('selected', btn.dataset.value === value);
  });
}

function showError(message) {
  state.errorMessage = message;
  if (message) {
    errorMessage.textContent = message;
    errorMessage.classList.remove('hidden');
  } else {
    errorMessage.classList.add('hidden');
  }
}

function updateControlVisibility() {
  const showPageSettings = state.mode !== 'free';
  pageSettings.classList.toggle('hidden', !showPageSettings);
  positioning.classList.toggle('hidden', !showPageSettings);
  customSizeRow.classList.toggle('hidden', state.mode !== 'custom');
  previewCanvas.classList.toggle('grab', showPageSettings);
}

async function rerender() {
  updateControlVisibility();
  if (!state.photo) {
    state.rendered = null;
    previewCanvas.classList.add('hidden');
    dropHint.classList.remove('hidden');
    exportButton.disabled = true;
    return;
  }
  try {
    const spec = TEMPLATE_SPECS[state.template];
    const svgImage = await getSvgImage(state.template);
    const canvas = makeBorderedImage(state.photo, state.mode, spec, svgImage, {
      position: state.position,
      customSizeMM: { width: state.customWidthMM, height: state.customHeightMM },
      orientation: state.orientation,
    });
    state.rendered = canvas;
    showError(null);

    previewCanvas.width = canvas.width;
    previewCanvas.height = canvas.height;
    previewCanvas.getContext('2d').drawImage(canvas, 0, 0);
    previewCanvas.classList.remove('hidden');
    dropHint.classList.add('hidden');
    exportButton.disabled = false;
  } catch (err) {
    showError(String(err.message || err));
  }
}

async function loadPhotoFile(file) {
  try {
    const bitmap = await createImageBitmap(file);
    state.photo = bitmap;
    state.photoName = file.name.replace(/\.[^/.]+$/, '');
    state.position = defaultPosition();
    state.orientation = bitmap.width > bitmap.height ? 'landscape' : 'portrait';
    setSegmentedValue(orientationPicker, state.orientation);
    await rerender();
  } catch (err) {
    showError(`Couldn't read image: ${file.name}`);
  }
}

document.querySelectorAll('.choose-button').forEach((btn) => {
  btn.addEventListener('click', () => fileInput.click());
});
fileInput.addEventListener('change', () => {
  const file = fileInput.files && fileInput.files[0];
  if (file) loadPhotoFile(file);
  fileInput.value = '';
});
preview.addEventListener('dragover', (e) => e.preventDefault());
preview.addEventListener('drop', (e) => {
  e.preventDefault();
  const file = e.dataTransfer.files && e.dataTransfer.files[0];
  if (file) loadPhotoFile(file);
});

templatePicker.addEventListener('click', (e) => {
  const btn = e.target.closest('button[data-value]');
  if (!btn) return;
  state.template = btn.dataset.value;
  setSegmentedValue(templatePicker, state.template);
  rerender();
});

modePicker.addEventListener('click', (e) => {
  const btn = e.target.closest('button[data-value]');
  if (!btn) return;
  state.mode = btn.dataset.value;
  setSegmentedValue(modePicker, state.mode);
  rerender();
});

orientationPicker.addEventListener('click', (e) => {
  const btn = e.target.closest('button[data-value]');
  if (!btn) return;
  state.orientation = btn.dataset.value;
  setSegmentedValue(orientationPicker, state.orientation);
  rerender();
});

function syncCustomSizeInputs() {
  customWidthInput.value = unitFromMm[state.customSizeUnit](state.customWidthMM).toFixed(2);
  customHeightInput.value = unitFromMm[state.customSizeUnit](state.customHeightMM).toFixed(2);
}

unitPicker.addEventListener('click', (e) => {
  const btn = e.target.closest('button[data-value]');
  if (!btn) return;
  state.customSizeUnit = btn.dataset.value;
  setSegmentedValue(unitPicker, state.customSizeUnit);
  syncCustomSizeInputs();
});

customWidthInput.addEventListener('change', () => {
  const value = parseFloat(customWidthInput.value);
  if (!Number.isFinite(value) || value <= 0) return;
  state.customWidthMM = mmFromUnit[state.customSizeUnit](value);
  rerender();
});

customHeightInput.addEventListener('change', () => {
  const value = parseFloat(customHeightInput.value);
  if (!Number.isFinite(value) || value <= 0) return;
  state.customHeightMM = mmFromUnit[state.customSizeUnit](value);
  rerender();
});

resetButton.addEventListener('click', () => {
  state.position = defaultPosition();
  rerender();
});

exportButton.addEventListener('click', async () => {
  if (!state.rendered || !state.photoName) return;
  const suffix = { free: 'bordered', a4: 'a4', a5: 'a5', custom: 'custom' }[state.mode];
  try {
    await downloadCanvasAsPNG(state.rendered, `${state.photoName}_${suffix}.png`);
  } catch (err) {
    showError(`Export failed: ${err.message || err}`);
  }
});

// Drag-to-reposition + trackpad-pinch-to-zoom on the preview canvas.
let isDragging = false;
let dragStartPan = { x: 0.5, y: 0.5 };
let dragStartClient = { x: 0, y: 0 };

previewCanvas.addEventListener('pointerdown', (e) => {
  if (state.mode === 'free' || !state.photo) return;
  isDragging = true;
  dragStartPan = { x: state.position.panX, y: state.position.panY };
  dragStartClient = { x: e.clientX, y: e.clientY };
  previewCanvas.setPointerCapture(e.pointerId);
  previewCanvas.classList.add('grabbing');
});

previewCanvas.addEventListener('pointermove', (e) => {
  if (!isDragging) return;
  const rect = previewCanvas.getBoundingClientRect();
  if (rect.width === 0 || rect.height === 0) return;
  const dx = (e.clientX - dragStartClient.x) / rect.width;
  const dy = (e.clientY - dragStartClient.y) / rect.height;
  state.position.panX = Math.min(Math.max(dragStartPan.x - dx, 0), 1);
  state.position.panY = Math.min(Math.max(dragStartPan.y - dy, 0), 1);
  rerender();
});

function endDrag() {
  if (!isDragging) return;
  isDragging = false;
  previewCanvas.classList.remove('grabbing');
}
previewCanvas.addEventListener('pointerup', endDrag);
previewCanvas.addEventListener('pointercancel', endDrag);

previewCanvas.addEventListener('wheel', (e) => {
  if (state.mode === 'free' || !state.photo || !e.ctrlKey) return;
  e.preventDefault();
  // Trackpad pinch fires as wheel+ctrlKey with deltaY roughly proportional
  // to the pinch amount; negate so pinching out (deltaY<0) zooms in. This
  // is the only zoom input -- plain scroll (no ctrlKey) is left alone.
  const delta = -e.deltaY / 100;
  state.position.zoom = Math.min(Math.max(state.position.zoom + delta, 0), 4);
  rerender();
}, { passive: false });

syncCustomSizeInputs();
updateControlVisibility();
```

- [ ] **Step 4: Manually verify the full app in a browser**

```bash
cd "/Users/matthew.bellars/Documents/Research Team Projects/DOAC Graphs:Photos/web"
python3 -m http.server 8000
```

Open `http://localhost:8000`. Walk through:
1. Drag-drop a photo onto the drop zone (or click "Choose Image…" and pick one) — a bordered preview appears.
2. Switch between V1/V2 templates — the border style changes, wordmark stays crisp.
3. Switch through Free size / A4 / A5 / Custom modes — canvas proportions change; page-settings/positioning controls appear for all but Free.
4. In Custom mode, edit width/height, and toggle cm/in — values convert correctly (210cm should read as 82.68in) and the preview updates.
5. Toggle Portrait/Landscape — the page dimensions swap.
6. In A4/A5/Custom mode, drag on the preview to reposition — the image follows the cursor, `grab`/`grabbing` cursor shows correctly.
7. Pinch-zoom on a trackpad over the preview — the image zooms in smoothly from the default (no "dead" pinch at zero zoom).
8. Click Reset — position/zoom return to default contain-fit.
9. Click Export… — a PNG downloads named `<original>_<suffix>.png`; open it and confirm it matches the preview.

Fix anything that doesn't match before proceeding. Stop the server when done.

- [ ] **Step 5: Commit**

```bash
cd "/Users/matthew.bellars/Documents/Research Team Projects/DOAC Graphs:Photos"
git add web/index.html web/style.css web/js/app.js
git commit -m "feat(web): wire up the full UI (controls, drag/pinch, export)"
```

---

### Task 11: Final verification and live deploy

**Files:** none created — this task verifies and enables deployment of everything from Tasks 1–10.

**Depends on:** Tasks 7, 8, 10 (transitively everything).

- [ ] **Step 1: Confirm all prior tasks are merged to `main`**

```bash
cd "/Users/matthew.bellars/Documents/Research Team Projects/DOAC Graphs:Photos"
git checkout main -q && git pull origin main -q
git status --short
ls web/js web/assets web/tests
```

Expected: clean status; `web/js` contains `templateSpec.js`, `positionState.js`, `frameLayout.js`, `frameRenderer.js`, `exporter.js`, `borderedImage.js`, `app.js`; `web/assets` contains `template-v1.svg`, `template-v2.svg`; `web/tests` contains the two `.test.js` files and two `manual-*.html` files.

- [ ] **Step 2: Run the full test suite**

```bash
node --test web/tests/
```

Expected: `# tests 9`, `# pass 9`, `# fail 0` (4 from `positionState.test.js` + 5 from `frameLayout.test.js`).

- [ ] **Step 3: Enable GitHub Pages to build from Actions (one-time repo setting)**

```bash
gh api repos/MBF-S/doac-border-app/pages -X PUT -f build_type=workflow 2>&1 || \
gh api repos/MBF-S/doac-border-app/pages -X POST -f build_type=workflow
```

If both commands fail with a permissions error, do it manually instead: GitHub repo → **Settings → Pages → Build and deployment → Source → GitHub Actions**.

- [ ] **Step 4: Confirm the deploy workflow runs and succeeds**

```bash
gh run list --workflow=deploy.yml --limit 3
```

Expected: the most recent run for the latest commit on `main` shows `completed` / `success`. If it hasn't triggered yet (e.g. Task 10's commit predates Task 8's workflow file), trigger it manually:

```bash
gh workflow run deploy.yml --ref main
```

then re-run `gh run list --workflow=deploy.yml --limit 3` until it shows `success`.

- [ ] **Step 5: Verify the live site**

```bash
gh api repos/MBF-S/doac-border-app/pages --jq .html_url
```

Open the printed URL in a browser and repeat the manual checklist from Task 10 Step 4 against the **live** deployed site (not localhost) — drop an image, try both templates, all four modes, drag+pinch, Reset, Export, open the downloaded PNG.

- [ ] **Step 6: Confirm the test workflow is green on the PR/commit history**

```bash
gh run list --workflow=test.yml --limit 3
```

Expected: latest run `completed` / `success`.

No commit for this task — it's verification-only. If any step above fails, fix the underlying issue in the relevant task's files, commit the fix, and re-run this task's steps from the top.

---

## Self-Review

**Spec coverage:** Every section of `docs/superpowers/specs/2026-07-02-doac-border-web-app-design.md` maps to a task — Architecture/file layout → Task 1; each `js/` module → Tasks 2–6, 9; repo cleanup → Task 7; rendering pipeline/interaction/custom sizing → Tasks 5, 9, 10; testing → each task's own test/manual-check step plus Task 11; error handling → `showError`/`loadPhotoFile` catch blocks in Task 10; deployment → Task 8 + Task 11.

**Placeholder scan:** No TBD/TODO markers; every code step has complete, runnable code; every command has an expected output.

**Type consistency:** `Size {width,height}`, `Rect {x,y,width,height}`, `Position {zoom,panX,panY}`, `Spec {name,svgFilename,left,top,right,bottom,bottomRight}`, and `Layout {scale,left,top,right,bottom,bottomRight,canvasWidth,canvasHeight,holeWidth,holeHeight}` are used identically across Tasks 2–10 — verified by re-reading each task's function signatures against the Global Constraints glossary.
