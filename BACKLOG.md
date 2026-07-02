# Backlog

- [ ] **TIFF file picker accepts a format it can't decode** — `web/index.html`'s file input and `app.js`'s loader admit `image/tiff`, but browsers can't decode TIFF via `createImageBitmap`. It degrades gracefully to the "Couldn't read image" error, but either drop TIFF from `accept` or leave as-is if the graceful failure is acceptable.
- [ ] **`.gitignore` still has native-app entries** — `.build/`, `.swiftpm/`, `*.app/`, `*.zip` are stale now that `DOACBorderApp/` was deleted in favor of `web/`. Harmless but worth pruning.
- [ ] **`deploy.yml` publishes `web/tests/` to GitHub Pages** — `path: web` uploads the whole directory including unit tests and the two `manual-*-check.html` harnesses. Unlinked from the app UI, just minor bloat on the deployed site; could restructure to exclude `tests/` from the Pages artifact if it matters.
- [ ] **`style.css` declares `color-scheme: light dark` but doesn't implement a dark theme** — body/segmented-control colors are hardcoded light values, so dark mode is asserted but not honored. Either add dark values or drop the `color-scheme` declaration.
