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
