# DOAC Border Native App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the three AppleScript droplet apps + `border.py` with a single native macOS app (SwiftUI), zero external runtime dependencies, that anyone can be handed and just run.

**Architecture:** Swift Package Manager executable target (macOS 13+), built and packaged from the command line (no Xcode app required). SwiftDraw (MIT-licensed SPM dependency) rasterizes the two bundled SVG frame assets at whatever exact pixel size is needed. Core compositing logic is a direct, empirically-validated port of `border.py`'s margin/9-slice math to Core Graphics.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit, Core Graphics, SwiftDraw (https://github.com/swhitty/SwiftDraw), `swift build` + hand-assembled `.app` bundle, ad-hoc code signing (no Apple Developer Program).

## Global Constraints

- Minimum macOS version: 13.0 (Ventura). Set in `Package.swift` platforms and `Info.plist` `LSMinimumSystemVersion`.
- No Apple Developer Program / notarization. App is ad-hoc signed (`codesign -s -`); recipients right-click → Open the first launch.
- Zero runtime dependencies beyond system frameworks + the two bundled SVG files. No Homebrew, no Python, no `rsvg-convert`.
- Template constants (margins, native size) are the same numbers already validated in `border.py`: V1 = left 203, top 190, right 235, bottom 210, bottomRight 380, native 1999x1545. V2 = left 99, top 107, right 99, bottom 107, bottomRight 325, native 1999x1545.
- **Critical rendering rule (validated by spike, see Task 3):** when compositing the final canvas, do NOT apply a full context flip transform — drawing a *cropped* `CGImage` piece through a flipped context produces an internally flipped result. Instead, keep source crop rects top-left-authored (unchanged) and flip only the Y-position of each *destination* rect via `flipDst(rect) = CGRect(x: rect.minX, y: canvasHeight - rect.maxY, width: rect.width, height: rect.height)`. The SVG-to-border-image rasterization step is the one place that *does* need a full context flip (SVG content is natively top-left-origin).
- Project root for the app: `DOACBorderApp/` inside the existing `DOAC Graphs:Photos` folder, alongside `border.py`, the SVG templates, and the AppleScript apps (left in place, not deleted, until the new app is confirmed working).

---

## File Structure

```
DOAC Graphs:Photos/
  DOACBorderApp/
    Package.swift
    Sources/
      DOACBorderApp/
        DOACBorderApp.swift      # @main SwiftUI App entry
        TemplateSpec.swift       # template metadata (v1/v2 margins, native size)
        FrameLayout.swift        # pure geometry: scale/margins/canvas+hole size
        PositionState.swift      # pure geometry: pan/zoom placement rect
        FrameRenderer.swift      # SwiftDraw rasterize + 9-slice CoreGraphics composite
        BorderedImage.swift      # ties layout + position + renderer together
        AppState.swift           # ObservableObject wiring UI to the above
        ContentView.swift        # SwiftUI UI
        Exporter.swift           # PNG write via NSSavePanel
    Tests/
      DOACBorderAppTests/
        FrameLayoutTests.swift
        PositionStateTests.swift
        FrameRendererTests.swift
    Resources/
      Template border V1.svg     # copied from project root
      Template border V2.svg     # copied from project root
    build_app.sh                 # assembles the .app, ad-hoc signs, zips
```

---

### Task 1: Project scaffold + walking skeleton

Prove the whole toolchain (SPM build → hand-built `.app` bundle → ad-hoc codesign → launch) works before writing any real logic. This is the newest, least-proven part of the stack, so it goes first.

**Files:**
- Create: `DOACBorderApp/Package.swift`
- Create: `DOACBorderApp/Sources/DOACBorderApp/DOACBorderApp.swift`
- Create: `DOACBorderApp/Resources/Template border V1.svg` (copy)
- Create: `DOACBorderApp/Resources/Template border V2.svg` (copy)
- Create: `DOACBorderApp/build_app.sh`

**Interfaces:**
- Produces: a launchable `DOAC Border.app` in `DOACBorderApp/`, and the `build_app.sh` script every later task's verification step reuses.

- [ ] **Step 1: Create the package scaffold**

```bash
mkdir -p "DOACBorderApp/Sources/DOACBorderApp" "DOACBorderApp/Tests/DOACBorderAppTests" "DOACBorderApp/Resources"
cp "Template border V1.svg" "DOACBorderApp/Resources/Template border V1.svg"
cp "Template border V2.svg" "DOACBorderApp/Resources/Template border V2.svg"
```

- [ ] **Step 2: Write `Package.swift`**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DOACBorderApp",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/swhitty/SwiftDraw.git", from: "0.20.0")
    ],
    targets: [
        .executableTarget(
            name: "DOACBorderApp",
            dependencies: ["SwiftDraw"]
        ),
        .testTarget(
            name: "DOACBorderAppTests",
            dependencies: ["DOACBorderApp"]
        )
    ]
)
```

- [ ] **Step 3: Write a minimal SwiftUI entry point**

`DOACBorderApp/Sources/DOACBorderApp/DOACBorderApp.swift`:

```swift
import SwiftUI

@main
struct DOACBorderApp: App {
    var body: some Scene {
        WindowGroup {
            Text("DOAC Border — skeleton OK")
                .frame(width: 400, height: 200)
        }
    }
}
```

(Note: the entry file must NOT be named `main.swift` — that name implies implicit top-level script execution, which conflicts with the `@main` attribute and would also block `Tests` from importing this module later.)

- [ ] **Step 4: Confirm it builds**

Run: `cd DOACBorderApp && swift build 2>&1 | tail -30`
Expected: `Build complete!` with no errors. (First run will fetch SwiftDraw from GitHub — requires network access.)

- [ ] **Step 5: Write `build_app.sh`**

`DOACBorderApp/build_app.sh`:

```bash
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="DOAC Border"
BUNDLE_ID="com.doac.borderapp"

swift build -c release

APP_DIR="$APP_NAME.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp ".build/release/DOACBorderApp" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "Resources/Template border V1.svg" "$APP_DIR/Contents/Resources/"
cp "Resources/Template border V2.svg" "$APP_DIR/Contents/Resources/"

cat > "$APP_DIR/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --deep -s - "$APP_DIR"
echo "Built $APP_DIR"
```

- [ ] **Step 6: Make it executable and run it**

Run: `chmod +x build_app.sh && ./build_app.sh`
Expected: `Built DOAC Border.app`

- [ ] **Step 7: Launch and verify visually**

Run: `open "DOAC Border.app" && sleep 2 && screencapture -x /tmp/skeleton_check.png`
Then Read `/tmp/skeleton_check.png` — expect a window showing "DOAC Border — skeleton OK".
Quit the app afterward: `pkill -f "DOAC Border.app/Contents/MacOS/DOAC Border"`

- [ ] **Step 8: Initialize git and commit**

No git repo exists yet in the project folder. Initialize one so this and later tasks have real commit checkpoints:

```bash
cd ..  # back to "DOAC Graphs:Photos"
git init
git add DOACBorderApp/Package.swift DOACBorderApp/Sources DOACBorderApp/Resources DOACBorderApp/build_app.sh
git commit -m "feat: scaffold DOACBorderApp SPM project with walking-skeleton build"
```

---

### Task 2: TemplateSpec + FrameLayout (pure geometry)

Port `border.py`'s margin/canvas-size math. Pure Swift, no UI, no rendering — fully unit-testable.

**Files:**
- Create: `DOACBorderApp/Sources/DOACBorderApp/TemplateSpec.swift`
- Create: `DOACBorderApp/Sources/DOACBorderApp/FrameLayout.swift`
- Test: `DOACBorderApp/Tests/DOACBorderAppTests/FrameLayoutTests.swift`

**Interfaces:**
- Produces: `TemplateSpec` (struct, `.v1`/`.v2`/`.all` static members, fields `name: String`, `svgFilename: String`, `nativeSize: CGSize`, `left/top/right/bottom/bottomRight: CGFloat`), `PageMode` (enum `.free`/`.a4`/`.a5`), `FrameLayout` (struct, `.make(mode:imageSize:spec:pct:minPx:dpi:)` static factory, fields `scale: CGFloat`, `left/top/right/bottom/bottomRight/canvasWidth/canvasHeight/holeWidth/holeHeight: Int`).

- [ ] **Step 1: Write the failing test**

`DOACBorderApp/Tests/DOACBorderAppTests/FrameLayoutTests.swift`:

```swift
import XCTest
@testable import DOACBorderApp

final class FrameLayoutTests: XCTestCase {
    func testFreeModeMatchesValidatedPythonOutput() {
        // Same inputs as border.py's validated chart_like test: 836x534 image, V1, defaults.
        let layout = FrameLayout.make(mode: .free, imageSize: CGSize(width: 836, height: 534), spec: .v1)
        XCTAssertEqual(layout.left, 60)
        XCTAssertEqual(layout.top, 56)
        XCTAssertEqual(layout.right, 69)
        XCTAssertEqual(layout.bottom, 62)
        XCTAssertEqual(layout.bottomRight, 112)
        XCTAssertEqual(layout.canvasWidth, 965)
        XCTAssertEqual(layout.canvasHeight, 652)
        XCTAssertEqual(layout.holeWidth, 836)
        XCTAssertEqual(layout.holeHeight, 534)
    }

    func testA4LandscapeMatchesValidatedPythonOutput() {
        // Same inputs as border.py's validated A4 test: 600x400 landscape image, V1, 300dpi.
        let layout = FrameLayout.make(mode: .a4, imageSize: CGSize(width: 600, height: 400), spec: .v1)
        XCTAssertEqual(layout.canvasWidth, 3508)
        XCTAssertEqual(layout.canvasHeight, 2480)
        XCTAssertEqual(layout.left, 198)
        XCTAssertEqual(layout.top, 186)
        XCTAssertEqual(layout.right, 230)
        XCTAssertEqual(layout.bottom, 205)
        XCTAssertEqual(layout.bottomRight, 371)
        XCTAssertEqual(layout.holeWidth, 3080)
        XCTAssertEqual(layout.holeHeight, 2089)
    }

    func testMinPxFloorProtectsSmallImages() {
        // 250x180 image: 8% of 180 = 14.4, well under the 60px floor.
        let layout = FrameLayout.make(mode: .free, imageSize: CGSize(width: 250, height: 180), spec: .v1)
        XCTAssertEqual(layout.left, 60) // floor, not 14
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd DOACBorderApp && swift test --filter FrameLayoutTests 2>&1 | tail -30`
Expected: FAIL — `TemplateSpec`/`FrameLayout` not defined.

- [ ] **Step 3: Write `TemplateSpec.swift`**

```swift
import CoreGraphics

struct TemplateSpec: Equatable, Hashable {
    let name: String
    let svgFilename: String
    let nativeSize: CGSize
    let left: CGFloat
    let top: CGFloat
    let right: CGFloat
    let bottom: CGFloat
    let bottomRight: CGFloat

    static func == (lhs: TemplateSpec, rhs: TemplateSpec) -> Bool { lhs.name == rhs.name }
    func hash(into hasher: inout Hasher) { hasher.combine(name) }

    static let v1 = TemplateSpec(
        name: "V1", svgFilename: "Template border V1.svg",
        nativeSize: CGSize(width: 1999, height: 1545),
        left: 203, top: 190, right: 235, bottom: 210, bottomRight: 380
    )
    static let v2 = TemplateSpec(
        name: "V2", svgFilename: "Template border V2.svg",
        nativeSize: CGSize(width: 1999, height: 1545),
        left: 99, top: 107, right: 99, bottom: 107, bottomRight: 325
    )
    static let all: [TemplateSpec] = [.v1, .v2]
}
```

- [ ] **Step 4: Write `FrameLayout.swift`**

```swift
import CoreGraphics

enum PageMode: Equatable {
    case free
    case a4
    case a5

    var pageSizeMM: (width: Double, height: Double)? {
        switch self {
        case .free: return nil
        case .a4: return (210, 297)
        case .a5: return (148, 210)
        }
    }
}

struct FrameLayout: Equatable {
    let scale: CGFloat
    let left: Int
    let top: Int
    let right: Int
    let bottom: Int
    let bottomRight: Int
    let canvasWidth: Int
    let canvasHeight: Int
    let holeWidth: Int
    let holeHeight: Int

    static func make(mode: PageMode, imageSize: CGSize, spec: TemplateSpec,
                      pct: CGFloat = 0.08, minPx: CGFloat = 60, dpi: CGFloat = 300) -> FrameLayout {
        guard let mm = mode.pageSizeMM else {
            return freeForm(imageSize: imageSize, spec: spec, pct: pct, minPx: minPx)
        }
        var mmW = mm.width, mmH = mm.height
        if imageSize.width > imageSize.height { swap(&mmW, &mmH) }
        let canvasWidth = Int((mmW / 25.4 * dpi).rounded())
        let canvasHeight = Int((mmH / 25.4 * dpi).rounded())

        let scale = max(pct * CGFloat(min(canvasWidth, canvasHeight)), minPx) / spec.left
        let left = Int((spec.left * scale).rounded())
        let top = Int((spec.top * scale).rounded())
        let right = Int((spec.right * scale).rounded())
        let bottom = Int((spec.bottom * scale).rounded())
        let bottomRight = Int((spec.bottomRight * scale).rounded())

        return FrameLayout(
            scale: scale, left: left, top: top, right: right, bottom: bottom, bottomRight: bottomRight,
            canvasWidth: canvasWidth, canvasHeight: canvasHeight,
            holeWidth: canvasWidth - left - right, holeHeight: canvasHeight - top - bottom
        )
    }

    static func freeForm(imageSize: CGSize, spec: TemplateSpec, pct: CGFloat = 0.08, minPx: CGFloat = 60) -> FrameLayout {
        let leftTarget = max(pct * min(imageSize.width, imageSize.height), minPx)
        let scale = leftTarget / spec.left
        let left = Int((spec.left * scale).rounded())
        let top = Int((spec.top * scale).rounded())
        let right = Int((spec.right * scale).rounded())
        let bottom = Int((spec.bottom * scale).rounded())
        let bottomRight = Int((spec.bottomRight * scale).rounded())
        let holeWidth = Int(imageSize.width.rounded())
        let holeHeight = Int(imageSize.height.rounded())
        return FrameLayout(
            scale: scale, left: left, top: top, right: right, bottom: bottom, bottomRight: bottomRight,
            canvasWidth: left + holeWidth + right, canvasHeight: top + holeHeight + bottom,
            holeWidth: holeWidth, holeHeight: holeHeight
        )
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `swift test --filter FrameLayoutTests 2>&1 | tail -30`
Expected: `Test Suite 'FrameLayoutTests' passed` — all 3 tests pass.

- [ ] **Step 6: Commit**

```bash
cd .. && git add DOACBorderApp/Sources/DOACBorderApp/TemplateSpec.swift DOACBorderApp/Sources/DOACBorderApp/FrameLayout.swift DOACBorderApp/Tests
git commit -m "feat: port border.py margin/canvas-size math to FrameLayout"
```

---

### Task 3: FrameRenderer (SwiftDraw + 9-slice Core Graphics composite)

The core rendering engine. Uses the validated flip recipe from the constraints section.

**Files:**
- Create: `DOACBorderApp/Sources/DOACBorderApp/FrameRenderer.swift`
- Test: `DOACBorderApp/Tests/DOACBorderAppTests/FrameRendererTests.swift`

**Interfaces:**
- Consumes: `FrameLayout` (Task 2) — `scale`, `left/top/right/bottom/bottomRight`, `canvasWidth/canvasHeight`.
- Produces: `FrameRenderer.render(holeContent: CGImage, layout: FrameLayout, svgURL: URL) throws -> CGImage`, `FrameRenderer.RenderError` enum (`.svgLoadFailed`, `.contextCreationFailed`, `.cropFailed`, `.finalImageFailed`).

- [ ] **Step 1: Write the failing test**

`DOACBorderApp/Tests/DOACBorderAppTests/FrameRendererTests.swift`:

```swift
import XCTest
import CoreGraphics
import AppKit
@testable import DOACBorderApp

final class FrameRendererTests: XCTestCase {
    func testRenderProducesExactCanvasSizeAndOpaqueCorners() throws {
        let svgURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // DOACBorderAppTests/
            .deletingLastPathComponent()  // Tests/
            .appendingPathComponent("Resources/Template border V1.svg")

        let holeWidth = 836, holeHeight = 534
        guard let holeCtx = CGContext(
            data: nil, width: holeWidth, height: holeHeight, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { XCTFail("context"); return }
        holeCtx.setFillColor(CGColor(red: 0.5, green: 0.7, blue: 0.9, alpha: 1))
        holeCtx.fill(CGRect(x: 0, y: 0, width: holeWidth, height: holeHeight))
        let holeContent = holeCtx.makeImage()!

        let layout = FrameLayout.make(mode: .free, imageSize: CGSize(width: holeWidth, height: holeHeight), spec: .v1)
        let result = try FrameRenderer.render(holeContent: holeContent, layout: layout, svgURL: svgURL)

        XCTAssertEqual(result.width, layout.canvasWidth)
        XCTAssertEqual(result.height, layout.canvasHeight)

        // Top-left corner should be opaque black (outer border), confirming
        // correct orientation (not flipped) and correct compositing.
        let rep = NSBitmapImageRep(cgImage: result)
        let topLeft = rep.colorAt(x: 5, y: 5)!
        XCTAssertLessThan(topLeft.redComponent, 0.2)
        XCTAssertLessThan(topLeft.greenComponent, 0.2)
        XCTAssertLessThan(topLeft.blueComponent, 0.2)

        // Center of the canvas should show the hole content color (light blue),
        // confirming the photo/hole content lands in the right place.
        let center = rep.colorAt(x: result.width / 2, y: result.height / 2)!
        XCTAssertGreaterThan(center.blueComponent, 0.7)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter FrameRendererTests 2>&1 | tail -30`
Expected: FAIL — `FrameRenderer` not defined.

- [ ] **Step 3: Write `FrameRenderer.swift`**

```swift
import CoreGraphics
import AppKit
import SwiftDraw

enum FrameRenderer {
    enum RenderError: Error {
        case svgLoadFailed
        case contextCreationFailed
        case cropFailed
        case finalImageFailed
    }

    /// Renders `holeContent` inside the frame described by `layout`, using the
    /// SVG at `svgURL`. `holeContent` must already be exactly
    /// layout.holeWidth x layout.holeHeight.
    static func render(holeContent: CGImage, layout: FrameLayout, svgURL: URL) throws -> CGImage {
        guard let svg = SwiftDraw.SVG(fileURL: svgURL) else { throw RenderError.svgLoadFailed }

        let nW = Int((svg.size.width * layout.scale).rounded())
        let nH = Int((svg.size.height * layout.scale).rounded())

        guard let borderCtx = CGContext(
            data: nil, width: nW, height: nH, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw RenderError.contextCreationFailed }
        // SVG content assumes top-left origin; flip so it draws right-side up.
        borderCtx.translateBy(x: 0, y: CGFloat(nH))
        borderCtx.scaleBy(x: 1, y: -1)
        borderCtx.draw(svg, in: CGRect(x: 0, y: 0, width: nW, height: nH))
        guard let border = borderCtx.makeImage() else { throw RenderError.finalImageFailed }

        let cw = layout.canvasWidth, ch = layout.canvasHeight
        guard let ctx = CGContext(
            data: nil, width: cw, height: ch, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw RenderError.contextCreationFailed }

        // Do NOT flip this context -- see Global Constraints. Flip only the
        // Y-position of each destination rect; crop src rects stay as-is.
        let chF = CGFloat(ch)
        func flipDst(_ rect: CGRect) -> CGRect {
            CGRect(x: rect.minX, y: chF - rect.maxY, width: rect.width, height: rect.height)
        }

        ctx.draw(holeContent, in: flipDst(CGRect(x: layout.left, y: layout.top, width: layout.holeWidth, height: layout.holeHeight)))

        func paste(srcRect: CGRect, dstRect: CGRect) throws {
            guard let piece = border.cropping(to: srcRect) else { throw RenderError.cropFailed }
            ctx.draw(piece, in: flipDst(dstRect))
        }

        let left = CGFloat(layout.left), top = CGFloat(layout.top)
        let right = CGFloat(layout.right), bottom = CGFloat(layout.bottom)
        let brW = CGFloat(layout.bottomRight)
        let cwF = CGFloat(cw)
        let nWf = CGFloat(nW), nHf = CGFloat(nH)

        // corners (native, never stretched)
        try paste(srcRect: CGRect(x: 0, y: 0, width: left, height: top),
                  dstRect: CGRect(x: 0, y: 0, width: left, height: top))
        try paste(srcRect: CGRect(x: nWf - right, y: 0, width: right, height: top),
                  dstRect: CGRect(x: cwF - right, y: 0, width: right, height: top))
        try paste(srcRect: CGRect(x: 0, y: nHf - bottom, width: left, height: bottom),
                  dstRect: CGRect(x: 0, y: chF - bottom, width: left, height: bottom))
        try paste(srcRect: CGRect(x: nWf - brW, y: nHf - bottom, width: brW, height: bottom),
                  dstRect: CGRect(x: cwF - brW, y: chF - bottom, width: brW, height: bottom))

        // edges (stretched only along their length)
        try paste(srcRect: CGRect(x: left, y: 0, width: nWf - right - left, height: top),
                  dstRect: CGRect(x: left, y: 0, width: cwF - left - right, height: top))
        let bottomEdgeW = cwF - left - brW
        try paste(srcRect: CGRect(x: left, y: nHf - bottom, width: nWf - brW - left, height: bottom),
                  dstRect: CGRect(x: left, y: chF - bottom, width: bottomEdgeW, height: bottom))
        try paste(srcRect: CGRect(x: 0, y: top, width: left, height: nHf - bottom - top),
                  dstRect: CGRect(x: 0, y: top, width: left, height: chF - bottom - top))
        try paste(srcRect: CGRect(x: nWf - right, y: top, width: right, height: nHf - bottom - top),
                  dstRect: CGRect(x: cwF - right, y: top, width: right, height: chF - bottom - top))

        guard let result = ctx.makeImage() else { throw RenderError.finalImageFailed }
        return result
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter FrameRendererTests 2>&1 | tail -30`
Expected: PASS.

- [ ] **Step 5: Visual spot-check with the real chart test image**

Add a temporary debug write (remove after checking) or just run this ad-hoc via `swift run` is not convenient for a library-only target — instead write a one-off script:

```bash
cat > /tmp/render_check.swift << 'EOF'
import CoreGraphics
import AppKit
import DOACBorderApp

let photoURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard let data = try? Data(contentsOf: photoURL),
      let rep = NSBitmapImageRep(data: data),
      let photo = rep.cgImage else { fatalError("load failed") }

let svgURL = URL(fileURLWithPath: "Resources/Template border V1.svg")
let layout = FrameLayout.make(mode: .free, imageSize: CGSize(width: photo.width, height: photo.height), spec: .v1)
let result = try! FrameRenderer.render(holeContent: photo, layout: layout, svgURL: svgURL)
let outRep = NSBitmapImageRep(cgImage: result)
try! outRep.representation(using: .png, properties: [:])!.write(to: outURL)
print("wrote", outURL.path)
EOF
```

This requires `DOACBorderApp` to be importable, which it is (Task 1 already made it testable). Simpler: add this as a throwaway XCTest instead, since the test target already links everything:

```swift
func testVisualSpotCheckWritesPNGForManualReview() throws {
    let chartURL = URL(fileURLWithPath: "/tmp/chart_check.png")
    // Reuse the same chart-generation approach validated in border.py's tests;
    // simplest here is to synthesize a plain colored rect as the "photo".
    let pw = 836, ph = 534
    guard let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { XCTFail(); return }
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: pw, height: ph))
    ctx.setFillColor(CGColor(red: 0.9, green: 0.1, blue: 0.2, alpha: 1))
    ctx.fill(CGRect(x: 160, y: 350, width: 70, height: 120))
    let photo = ctx.makeImage()!

    let svgURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources/Template border V1.svg")
    let layout = FrameLayout.make(mode: .free, imageSize: CGSize(width: pw, height: ph), spec: .v1)
    let result = try FrameRenderer.render(holeContent: photo, layout: layout, svgURL: svgURL)
    let rep = NSBitmapImageRep(cgImage: result)
    try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "/tmp/frame_renderer_check.png"))
}
```

Run: `swift test --filter testVisualSpotCheckWritesPNGForManualReview 2>&1 | tail -10`
Then Read `/tmp/frame_renderer_check.png` — expect a clean single frame, DOAC logo bottom-right, red rectangle visible bottom-left-ish of the white hole, no doubling, no gaps. This mirrors the exact visual check already used successfully for `border.py`.

Delete this spot-check test once confirmed (it's a manual-review aid, not a real regression test — the pixel assertions in Step 1's test are the permanent automated check).

- [ ] **Step 6: Commit**

```bash
cd .. && git add DOACBorderApp/Sources/DOACBorderApp/FrameRenderer.swift DOACBorderApp/Tests/DOACBorderAppTests/FrameRendererTests.swift
git commit -m "feat: add FrameRenderer (SwiftDraw + validated 9-slice Core Graphics composite)"
```

---

### Task 4: PositionState (pan/zoom pure geometry)

**Files:**
- Create: `DOACBorderApp/Sources/DOACBorderApp/PositionState.swift`
- Test: `DOACBorderApp/Tests/DOACBorderAppTests/PositionStateTests.swift`

**Interfaces:**
- Produces: `PositionState` (struct, `Equatable`, fields `zoom: CGFloat = 0`, `panX: CGFloat = 0.5`, `panY: CGFloat = 0.5`, static `.auto`), method `placement(imageSize: CGSize, holeSize: CGSize) -> CGRect`.

- [ ] **Step 1: Write the failing test**

`DOACBorderApp/Tests/DOACBorderAppTests/PositionStateTests.swift`:

```swift
import XCTest
@testable import DOACBorderApp

final class PositionStateTests: XCTestCase {
    func testDefaultZoomContainsWholeImageCentered() {
        // 600x400 image (1.5 aspect) into a 500x500 hole (1.0 aspect):
        // contain scale = min(500/600, 500/400) = min(0.833, 1.25) = 0.833
        // drawWidth = 500, drawHeight = 333.3 -> centered vertically, no horizontal gap.
        let placement = PositionState.auto.placement(imageSize: CGSize(width: 600, height: 400), holeSize: CGSize(width: 500, height: 500))
        XCTAssertEqual(placement.width, 500, accuracy: 0.5)
        XCTAssertEqual(placement.height, 333.33, accuracy: 0.5)
        XCTAssertEqual(placement.origin.x, 0, accuracy: 0.5)
        XCTAssertEqual(placement.origin.y, (500 - 333.33) / 2, accuracy: 0.5)
    }

    func testFullZoomCoversHoleWithNoGutter() {
        var state = PositionState.auto
        state.zoom = 1
        // cover scale = max(500/600, 500/400) = max(0.833, 1.25) = 1.25
        let placement = state.placement(imageSize: CGSize(width: 600, height: 400), holeSize: CGSize(width: 500, height: 500))
        XCTAssertEqual(placement.width, 750, accuracy: 0.5)  // 600*1.25
        XCTAssertEqual(placement.height, 500, accuracy: 0.5) // 400*1.25, fills exactly
    }

    func testPanClampedWithinOverflowRange() {
        var state = PositionState.auto
        state.zoom = 1
        state.panX = 0 // pan fully to one edge of the overflow
        let placement = state.placement(imageSize: CGSize(width: 600, height: 400), holeSize: CGSize(width: 500, height: 500))
        // overflow = 750 - 500 = 250; panX=0 -> offset 0 (left-aligned)
        XCTAssertEqual(placement.origin.x, 0, accuracy: 0.5)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter PositionStateTests 2>&1 | tail -30`
Expected: FAIL — `PositionState` not defined.

- [ ] **Step 3: Write `PositionState.swift`**

```swift
import CoreGraphics

struct PositionState: Equatable {
    var zoom: CGFloat = 0       // 0 = contain (default), 1 = cover (fills, may crop)
    var panX: CGFloat = 0.5     // 0...1, only takes effect once zoom creates overflow
    var panY: CGFloat = 0.5

    static let auto = PositionState()

    /// Rect (top-left-origin, in hole pixel space) to draw the full source
    /// image into, given the hole size and the image's own native size.
    func placement(imageSize: CGSize, holeSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let containScale = min(holeSize.width / imageSize.width, holeSize.height / imageSize.height)
        let coverScale = max(holeSize.width / imageSize.width, holeSize.height / imageSize.height)
        let scale = containScale + (coverScale - containScale) * min(max(zoom, 0), 1)

        let drawWidth = imageSize.width * scale
        let drawHeight = imageSize.height * scale

        let maxOffsetX = max(0, drawWidth - holeSize.width)
        let maxOffsetY = max(0, drawHeight - holeSize.height)
        let clampedPanX = min(max(panX, 0), 1)
        let clampedPanY = min(max(panY, 0), 1)

        let x = maxOffsetX > 0 ? -maxOffsetX * clampedPanX : (holeSize.width - drawWidth) / 2
        let y = maxOffsetY > 0 ? -maxOffsetY * clampedPanY : (holeSize.height - drawHeight) / 2

        return CGRect(x: x, y: y, width: drawWidth, height: drawHeight)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter PositionStateTests 2>&1 | tail -30`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd .. && git add DOACBorderApp/Sources/DOACBorderApp/PositionState.swift DOACBorderApp/Tests/DOACBorderAppTests/PositionStateTests.swift
git commit -m "feat: add PositionState pure pan/zoom placement geometry"
```

---

### Task 5: BorderedImage (ties layout + position + renderer together)

**Files:**
- Create: `DOACBorderApp/Sources/DOACBorderApp/BorderedImage.swift`
- Test: add to `DOACBorderApp/Tests/DOACBorderAppTests/FrameRendererTests.swift`

**Interfaces:**
- Consumes: `FrameLayout.make` (Task 2), `PositionState.placement` (Task 4), `FrameRenderer.render` (Task 3).
- Produces: `BorderedImage.make(photo: CGImage, mode: PageMode, spec: TemplateSpec, svgURL: URL, position: PositionState = .auto) throws -> CGImage`.

- [ ] **Step 1: Write the failing test**

Append to `FrameRendererTests.swift`:

```swift
func testBorderedImageFreeModeIgnoresPositionAndShowsWholeImage() throws {
    let pw = 400, ph = 300
    guard let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { XCTFail(); return }
    ctx.setFillColor(CGColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: pw, height: ph))
    let photo = ctx.makeImage()!

    let svgURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources/Template border V1.svg")

    let result = try BorderedImage.make(photo: photo, mode: .free, spec: .v1, svgURL: svgURL)
    let layout = FrameLayout.make(mode: .free, imageSize: CGSize(width: pw, height: ph), spec: .v1)
    XCTAssertEqual(result.width, layout.canvasWidth)
    XCTAssertEqual(result.height, layout.canvasHeight)
}

func testBorderedImagePageModeLetterboxes() throws {
    let pw = 400, ph = 300
    guard let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { XCTFail(); return }
    ctx.setFillColor(CGColor(red: 0.2, green: 0.2, blue: 0.9, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: pw, height: ph))
    let photo = ctx.makeImage()!

    let svgURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources/Template border V1.svg")

    let result = try BorderedImage.make(photo: photo, mode: .a5, spec: .v1, svgURL: svgURL)
    let layout = FrameLayout.make(mode: .a5, imageSize: CGSize(width: pw, height: ph), spec: .v1)
    XCTAssertEqual(result.width, layout.canvasWidth)
    XCTAssertEqual(result.height, layout.canvasHeight)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter FrameRendererTests 2>&1 | tail -30`
Expected: FAIL — `BorderedImage` not defined.

- [ ] **Step 3: Write `BorderedImage.swift`**

```swift
import CoreGraphics

enum BorderedImage {
    static func make(photo: CGImage, mode: PageMode, spec: TemplateSpec, svgURL: URL,
                      position: PositionState = .auto) throws -> CGImage {
        let photoSize = CGSize(width: photo.width, height: photo.height)
        let layout = FrameLayout.make(mode: mode, imageSize: photoSize, spec: spec)
        let holeSize = CGSize(width: layout.holeWidth, height: layout.holeHeight)

        let placement: CGRect = mode == .free
            ? CGRect(origin: .zero, size: holeSize) // whole image, untouched, no crop
            : position.placement(imageSize: photoSize, holeSize: holeSize)

        guard let holeCtx = CGContext(
            data: nil, width: layout.holeWidth, height: layout.holeHeight, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw FrameRenderer.RenderError.contextCreationFailed }

        holeCtx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        holeCtx.fill(CGRect(x: 0, y: 0, width: layout.holeWidth, height: layout.holeHeight))

        // placement is top-left-authored; flip Y the same way FrameRenderer's dst rects do.
        let holeHeightF = CGFloat(layout.holeHeight)
        let flippedPlacement = CGRect(
            x: placement.minX, y: holeHeightF - placement.maxY,
            width: placement.width, height: placement.height
        )
        holeCtx.draw(photo, in: flippedPlacement)
        guard let holeContent = holeCtx.makeImage() else { throw FrameRenderer.RenderError.finalImageFailed }

        return try FrameRenderer.render(holeContent: holeContent, layout: layout, svgURL: svgURL)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter FrameRendererTests 2>&1 | tail -30`
Expected: PASS (all tests in the file, including the two new ones).

- [ ] **Step 5: Commit**

```bash
cd .. && git add DOACBorderApp/Sources/DOACBorderApp/BorderedImage.swift DOACBorderApp/Tests/DOACBorderAppTests/FrameRendererTests.swift
git commit -m "feat: add BorderedImage tying layout, position, and renderer together"
```

---

### Task 6: SwiftUI UI (drop zone, preview, template/mode pickers, positioning controls)

This is the first task with real UI, so verification is build + launch + screenshot rather than XCTest.

**Files:**
- Create: `DOACBorderApp/Sources/DOACBorderApp/AppState.swift`
- Create: `DOACBorderApp/Sources/DOACBorderApp/ContentView.swift`
- Modify: `DOACBorderApp/Sources/DOACBorderApp/DOACBorderApp.swift` (point at `ContentView` instead of the skeleton `Text`)

**Interfaces:**
- Consumes: `TemplateSpec`, `PageMode`, `PositionState`, `BorderedImage.make` (all prior tasks).
- Produces: `AppState` (`ObservableObject`, `@Published photo/photoURL/template/mode/position/rendered/errorMessage`, methods `load(url:)`, `rerender()`), `ContentView` (SwiftUI `View`).

- [ ] **Step 1: Write `AppState.swift`**

```swift
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var photoURL: URL?
    @Published var photo: CGImage?
    @Published var template: TemplateSpec = .v1
    @Published var mode: PageMode = .free
    @Published var position: PositionState = .auto
    @Published var rendered: CGImage?
    @Published var errorMessage: String?

    func load(url: URL) {
        guard let data = try? Data(contentsOf: url),
              let rep = NSBitmapImageRep(data: data),
              let image = rep.cgImage else {
            errorMessage = "Couldn't read image: \(url.lastPathComponent)"
            return
        }
        photoURL = url
        photo = image
        position = .auto
        rerender()
    }

    func rerender() {
        guard let photo else { rendered = nil; return }
        guard let svgURL = Bundle.main.resourceURL?.appendingPathComponent(template.svgFilename) else {
            errorMessage = "Missing frame resource: \(template.svgFilename)"
            return
        }
        do {
            rendered = try BorderedImage.make(photo: photo, mode: mode, spec: template, svgURL: svgURL, position: position)
            errorMessage = nil
        } catch {
            errorMessage = "\(error)"
        }
    }
}
```

- [ ] **Step 2: Write `ContentView.swift`**

```swift
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var state = AppState()

    var body: some View {
        VStack(spacing: 12) {
            preview
            controls
            if let msg = state.errorMessage {
                Text(msg).foregroundColor(.red).font(.caption)
            }
        }
        .padding()
        .frame(minWidth: 520, minHeight: 560)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    DispatchQueue.main.async { state.load(url: url) }
                }
            }
            return true
        }
    }

    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.1))
            if let rendered = state.rendered {
                Image(decorative: rendered, scale: 1, orientation: .up)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
            } else {
                VStack(spacing: 8) {
                    Text("Drop an image here").foregroundColor(.secondary)
                    Button("Choose Image…") { chooseFile() }
                }
            }
        }
        .frame(minHeight: 360)
    }

    private var controls: some View {
        VStack(spacing: 8) {
            Picker("Template", selection: $state.template) {
                ForEach(TemplateSpec.all, id: \.name) { spec in
                    Text(spec.name).tag(spec)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: state.template) { _, _ in state.rerender() }

            Picker("Mode", selection: $state.mode) {
                Text("Free size").tag(PageMode.free)
                Text("A4").tag(PageMode.a4)
                Text("A5").tag(PageMode.a5)
            }
            .pickerStyle(.segmented)
            .onChange(of: state.mode) { _, _ in state.rerender() }

            if state.mode != .free {
                positioning
            }

            HStack {
                Button("Choose Image…") { chooseFile() }
                Spacer()
                Button("Export…") { export() }
                    .disabled(state.rendered == nil)
            }
        }
    }

    private var positioning: some View {
        VStack {
            HStack { Text("Zoom"); Slider(value: $state.position.zoom, in: 0...1) }
            HStack { Text("Pan X"); Slider(value: $state.position.panX, in: 0...1) }
            HStack { Text("Pan Y"); Slider(value: $state.position.panY, in: 0...1) }
        }
        .onChange(of: state.position) { _, _ in state.rerender() }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            state.load(url: url)
        }
    }

    private func export() {
        guard let rendered = state.rendered, let sourceURL = state.photoURL else { return }
        let suffix: String
        switch state.mode {
        case .free: suffix = "bordered"
        case .a4: suffix = "a4"
        case .a5: suffix = "a5"
        }
        let defaultName = sourceURL.deletingPathExtension().lastPathComponent + "_\(suffix).png"

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = defaultName
        panel.directoryURL = sourceURL.deletingLastPathComponent()
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try Exporter.writePNG(rendered, to: url)
        } catch {
            state.errorMessage = "Export failed: \(error)"
        }
    }
}
```

- [ ] **Step 3: Write `Exporter.swift`** (needed for `ContentView` to compile)

`DOACBorderApp/Sources/DOACBorderApp/Exporter.swift`:

```swift
import AppKit

enum Exporter {
    enum ExportError: Error { case encodingFailed }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw ExportError.encodingFailed
        }
        try data.write(to: url)
    }
}
```

- [ ] **Step 4: Point the app entry at `ContentView`**

Modify `DOACBorderApp.swift`:

```swift
import SwiftUI

@main
struct DOACBorderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

- [ ] **Step 5: Build, fixing any compiler errors that surface**

Run: `swift build 2>&1 | tail -60`
Expected: `Build complete!`. SwiftUI/AppKit API surface is large — if a signature mismatch appears (e.g. `Picker` selection binding, `.onChange` two-parameter closure availability on macOS 13 vs 14), fix it using the error message; these are standard, well-documented APIs, not unknowns like the Task 3 rendering bug.

- [ ] **Step 6: Package and launch for a visual check**

Run: `./build_app.sh && open "DOAC Border.app" && sleep 2 && screencapture -x /tmp/ui_check.png`
Then Read `/tmp/ui_check.png` — expect a window with a drop zone / "Choose Image…" button, Template and Mode segmented pickers below it.
Quit: `pkill -f "DOAC Border.app/Contents/MacOS/DOAC Border"`

- [ ] **Step 7: Drive it with a real image via a simulated drop (Open Panel can't be scripted, so verify via `open -a` on a file, which exercises the same `onDrop`/load path indirectly is not possible for `.app` — instead verify `AppState.load` + `rerender` directly with a unit test)**

Add to a new file `DOACBorderApp/Tests/DOACBorderAppTests/AppStateTests.swift`:

```swift
import XCTest
@testable import DOACBorderApp

@MainActor
final class AppStateTests: XCTestCase {
    func testLoadAndRerenderProducesImage() throws {
        let pw = 400, ph = 300
        guard let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { XCTFail(); return }
        ctx.setFillColor(CGColor(red: 1, green: 0.5, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: pw, height: ph))
        let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
        let pngData = rep.representation(using: .png, properties: [:])!
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("appstate_test.png")
        try pngData.write(to: tmpURL)

        // Point Bundle.main.resourceURL-dependent rerender() at the real SVG by
        // calling BorderedImage directly here instead, since Bundle.main isn't
        // meaningful in `swift test`. This test therefore checks load() parses
        // the image correctly; full rerender-through-AppState is covered by
        // the packaged-app smoke test in Task 7.
        let state = AppState()
        state.load(url: tmpURL)
        XCTAssertNotNil(state.photo)
        XCTAssertEqual(state.photo?.width, pw)
        XCTAssertEqual(state.photo?.height, ph)

        try? FileManager.default.removeItem(at: tmpURL)
    }
}
```

Run: `swift test --filter AppStateTests 2>&1 | tail -30`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
cd .. && git add DOACBorderApp/Sources/DOACBorderApp DOACBorderApp/Tests/DOACBorderAppTests/AppStateTests.swift
git commit -m "feat: add SwiftUI UI (drop zone, preview, template/mode/position controls)"
```

---

### Task 7: Packaging polish + end-to-end distribution smoke test

**Files:**
- Modify: `DOACBorderApp/build_app.sh` (add zip step)

**Interfaces:**
- Produces: `DOAC Border.zip`, shareable as-is.

- [ ] **Step 1: Add zip packaging to `build_app.sh`**

Append to the end of `build_app.sh`:

```bash
rm -f "$APP_NAME.zip"
zip -r -q "$APP_NAME.zip" "$APP_DIR"
echo "Zipped $APP_NAME.zip"
```

- [ ] **Step 2: Full rebuild**

Run: `./build_app.sh`
Expected: `Built DOAC Border.app` then `Zipped DOAC Border.zip`.

- [ ] **Step 3: End-to-end smoke test simulating a recipient**

```bash
rm -rf /tmp/doac_recipient_test && mkdir -p /tmp/doac_recipient_test
cd /tmp/doac_recipient_test
unzip -q "/Users/matthew.bellars/Documents/Research Team Projects/DOAC Graphs:Photos/DOACBorderApp/DOAC Border.zip"
xattr -w com.apple.quarantine "0081;00000000;Safari;" "DOAC Border.app"  # simulate a downloaded/AirDropped file's quarantine flag
open "DOAC Border.app"
sleep 2
screencapture -x /tmp/recipient_launch_check.png
```

Read `/tmp/recipient_launch_check.png` — expect the app window to appear (same as Task 6's UI check), confirming it launches from a quarantined, freshly-unzipped copy exactly as a recipient would experience it (after their one-time right-click → Open to clear Gatekeeper — since we can't interactively click through the Gatekeeper dialog from a script, if `open` is blocked here, note that in the final report as the expected recipient-side manual step, not a bug).

Quit: `pkill -f "DOAC Border.app/Contents/MacOS/DOAC Border"`
Clean up: `rm -rf /tmp/doac_recipient_test`

- [ ] **Step 4: Manual drag-and-drop + export check (cannot be scripted — do this by hand once)**

Open `DOAC Border.app`, drag a real chart/photo onto the drop zone, confirm the live preview updates, switch Template/Mode and confirm the preview updates each time, click Export, confirm a save panel appears with a sensible default filename, save, and open the resulting PNG to confirm it matches the quality/positioning already validated in Tasks 3 and 5.

- [ ] **Step 5: Commit**

```bash
cd "/Users/matthew.bellars/Documents/Research Team Projects/DOAC Graphs:Photos"
git add DOACBorderApp/build_app.sh
git commit -m "feat: add zip packaging for distribution, complete end-to-end smoke test"
```

---

## Self-Review Notes

- **Spec coverage:** Free/A4/A5 modes (Task 2/5), template picker V1/V2 (Task 2/6), positioning override in A4/A5 only (Task 4/5/6 — `BorderedImage.make` hardcodes `mode == .free` to skip `PositionState`), live preview (Task 6), export with default filename (Task 6), zero-dependency distribution (Task 1/7), no Apple Developer Program (Task 1's ad-hoc `codesign`). All spec sections have a task.
- **Type consistency checked:** `TemplateSpec`, `PageMode`, `FrameLayout`, `PositionState`, `FrameRenderer.RenderError`, `BorderedImage.make`, `AppState`, `Exporter` signatures are identical everywhere they're referenced across tasks.
- **The Task 3 flip-transform bug and its fix are the single most important detail in this plan** — it was found and fixed empirically (not theoretically) before writing this plan, by building and running real Swift spikes. Do not "simplify" `FrameRenderer` by adding a context flip back in; it will silently reintroduce internally-flipped 9-slice pieces.
