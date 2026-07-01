# DOAC Border App — design

## Goal

Replace the three drag-and-drop AppleScript apps + `border.py` with a single
native macOS app: clean UI, optional manual positioning, and — critically —
zero external dependencies, so it can be handed to anyone and just works.

## Why native

The current pipeline depends on Homebrew Python, Pillow, and rsvg-convert
(with its own chain of native libraries). None of that exists on a random
person's Mac. A native Swift app removes the entire dependency chain.

## Architecture

- Swift Package Manager executable target (macOS, SwiftUI + AppKit), built
  and packaged from the command line — no Xcode app required.
- Ad-hoc signed (no Apple Developer Program). Recipients right-click → Open
  once to clear Gatekeeper, then it runs normally.
- Border rendering: SwiftDraw (MIT-licensed SPM package) rasterizes the two
  bundled SVG frame assets (`Template border V1.svg` / `V2.svg`, already
  vectorized from the approved Canva art) at whatever exact pixel size is
  needed — this is the direct replacement for the `rsvg-convert` subprocess
  call, so text stays sharp with no external tool.
- Compositing logic (margins, 9-slice corner/edge scaling, the wide
  bottom-right corner that protects the logo, free/A4/A5 sizing, the
  min-px logo-legibility floor) is a direct port of the existing, already
  validated `border.py` logic — same math, Core Graphics instead of PIL.

## Modes (all three carried over from the CLI tool)

1. **Free size** — canvas grows to image size + border; border thickness =
   8% of the image's shorter side, floored so the logo stays legible.
2. **A4** / **A5** — fixed page size at 300dpi, orientation auto-matched to
   the image's aspect ratio, image contain-fit inside the frame (letterboxed
   with white gutters, never cropped) unless overridden (see Positioning).

## Positioning

Only meaningful in A4/A5 modes (Free mode always shows the whole image
untouched, so there's nothing to position). Default behavior is the
existing auto contain-fit. Optional override: drag to reposition and a zoom
slider to crop in tighter than the auto-fit, for when gutters aren't wanted.

## UI flow

1. Drop zone / "Choose Image" button.
2. Live preview of the framed result.
3. Controls: template picker (V1/V2), mode picker (Free/A4/A5), and (in
   A4/A5 modes) drag + zoom slider for manual positioning.
4. Export button → save panel, default filename = `<original>_<suffix>.png`.

## Out of scope

- Batch processing (one image at a time, by design — see prior brainstorm).
- App Store distribution / notarization (explicitly declined).
- Editing/replacing the border artwork itself (still sourced from the two
  vectorized SVGs; regenerate via `vectorize.py` if the Canva art changes).

## Distribution

Build produces a `.app` bundle; zip it and share via AirDrop/Slack/email.
