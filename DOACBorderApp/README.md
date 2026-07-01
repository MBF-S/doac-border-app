# DOAC Border

A small Mac app that adds the DOAC branded border/frame around any photo,
so it's ready to print. Drop in a photo, pick a template and page size,
optionally reposition it, then export a bordered PNG.

## Getting it running the first time

This app isn't notarized (no Apple Developer account), so macOS will
block it on first launch by default. The workaround differs by macOS
version:

### macOS 15 (Sequoia) and later

Apple removed the old "Control-click → Open" bypass for unsigned/ad-hoc
apps on Sequoia, so use this flow instead:

1. Double-click **DOAC Border.app**. You'll see a message that "Apple
   could not verify..." the app — there's no "Open" button here, this is
   expected, just click OK/Done.
2. Open **System Settings → Privacy & Security**.
3. Scroll down to the message about "DOAC Border" being blocked, and
   click **Open Anyway**.
4. A follow-up dialog appears — click **Open Anyway** (or **Open**) to
   confirm.

The app will now launch, and every launch after this works normally
(double-click, no more warnings).

### macOS 13/14 (Ventura/Sonoma)

Control-click (or right-click) **DOAC Border.app** and choose **Open**
from the menu, then confirm **Open** in the dialog that appears. After
that, double-clicking works normally.

## Using the app

1. Drag a photo onto the app window, or click **Choose Image…**.
2. Pick a border **Template** (V1 or V2).
3. Pick a **Mode**:
   - **Free size** — the border wraps the photo at its own size/shape.
   - **A4** / **A5** — the photo is placed into a fixed print-size page.
4. In A4/A5 mode, drag on the preview to reposition the photo within the
   frame, and use the **Zoom** slider to crop in.
5. Click **Export…** and choose where to save the finished PNG.
