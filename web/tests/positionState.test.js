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
