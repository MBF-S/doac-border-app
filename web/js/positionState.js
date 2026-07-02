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
