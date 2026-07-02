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
