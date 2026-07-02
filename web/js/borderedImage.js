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
