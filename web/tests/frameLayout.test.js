import { test } from 'node:test';
import assert from 'node:assert/strict';
import { makeLayout } from '../js/frameLayout.js';

const specV1 = { left: 203, top: 190, right: 235, bottom: 210, bottomRight: 380, wordmarkHeight: 88.799 };

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

test('wordmark legibility floor protects small custom pages', () => {
  // 80x80mm custom page at 300dpi: the pct-based scale (~0.37) would print
  // the DOAC wordmark under 4mm tall -- the wordmarkHeight-based floor
  // (targeting >=6mm printed height) must take over instead.
  const layout = makeLayout('custom', { width: 600, height: 400 }, specV1, {
    customSizeMM: { width: 80, height: 80 },
    orientation: 'portrait',
  });
  assert.equal(layout.canvasWidth, 945);
  assert.equal(layout.canvasHeight, 945);
  assert.equal(layout.left, 162);
  // printed wordmark height = spec.wordmarkHeight * scale / dpi * 25.4mm >= 6mm
  const printedWordmarkMM = (specV1.wordmarkHeight * layout.scale) / 300 * 25.4;
  assert.ok(printedWordmarkMM >= 6, `expected >=6mm, got ${printedWordmarkMM}`);
});

test('wordmark floor does not shrink an already-generous a4 border', () => {
  // At A4/300dpi the pct-based scale already exceeds the wordmark floor, so
  // the floor must not change existing A4 output.
  const layout = makeLayout('a4', { width: 600, height: 400 }, specV1);
  assert.equal(layout.left, 198);
});
