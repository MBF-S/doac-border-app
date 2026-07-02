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
