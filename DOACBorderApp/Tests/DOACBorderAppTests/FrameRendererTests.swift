import XCTest
import CoreGraphics
import AppKit
@testable import DOACBorderApp

/// Builds a quadrant-colored CGImage: red=top-left, green=top-right,
/// blue=bottom-left, yellow=bottom-right (as read via NSBitmapImageRep,
/// top-left origin). Same fill pattern as
/// testRenderPreservesHoleContentOrientation, factored out so the
/// BorderedImage tests below can reuse it instead of reinventing it.
private func makeQuadrantImage(width: Int, height: Int) -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    func col(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor {
        CGColor(colorSpace: colorSpace, components: [r, g, b, 1])!
    }
    let halfW = CGFloat(width) / 2, halfH = CGFloat(height) / 2
    ctx.setFillColor(col(1, 0, 0))
    ctx.fill(CGRect(x: 0, y: halfH, width: halfW, height: halfH))       // red: top-left
    ctx.setFillColor(col(0, 1, 0))
    ctx.fill(CGRect(x: halfW, y: halfH, width: halfW, height: halfH))   // green: top-right
    ctx.setFillColor(col(0, 0, 1))
    ctx.fill(CGRect(x: 0, y: 0, width: halfW, height: halfH))           // blue: bottom-left
    ctx.setFillColor(col(1, 1, 0))
    ctx.fill(CGRect(x: halfW, y: 0, width: halfW, height: halfH))       // yellow: bottom-right
    return ctx.makeImage()!
}

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
        let result = try FrameRenderer.render(holeContent: holeContent, layout: layout, spec: .v1, svgURL: svgURL)

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

    /// Regression test for the historical "double flip" bug: an erroneous
    /// flip transform applied to the destination compositing context (in
    /// addition to the position-only flipDst() logic) silently mirrors the
    /// hole content vertically. A uniform-color hole image can't detect
    /// this, so this test uses a quadrant-colored hole image and checks
    /// each quadrant lands in the correct place in the output.
    func testRenderPreservesHoleContentOrientation() throws {
        let svgURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // DOACBorderAppTests/
            .deletingLastPathComponent()  // Tests/
            .appendingPathComponent("Resources/Template border V1.svg")

        let holeWidth = 836, holeHeight = 534
        let holeColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let holeCtx = CGContext(
            data: nil, width: holeWidth, height: holeHeight, bitsPerComponent: 8, bytesPerRow: 0,
            space: holeColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { XCTFail("context"); return }

        // CGContext is y-up (origin bottom-left). Fill quadrants so that,
        // once viewed right-side up (top-left origin, as colorAt below
        // reads it), red=top-left, green=top-right, blue=bottom-left,
        // yellow=bottom-right. That means the "top" colors (red/green) go
        // in the high-y half of the CGContext.
        // (Colors are built in the context's own color space -- the
        // CGColor(red:green:blue:alpha:) convenience initializer uses a
        // different generic color space, which introduces cross-channel
        // conversion noise that swamps the ~10/255 tolerance below.)
        func col(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor {
            CGColor(colorSpace: holeColorSpace, components: [r, g, b, 1])!
        }
        let halfW = CGFloat(holeWidth) / 2, halfH = CGFloat(holeHeight) / 2
        holeCtx.setFillColor(col(1, 0, 0))
        holeCtx.fill(CGRect(x: 0, y: halfH, width: halfW, height: halfH))       // red: top-left
        holeCtx.setFillColor(col(0, 1, 0))
        holeCtx.fill(CGRect(x: halfW, y: halfH, width: halfW, height: halfH))   // green: top-right
        holeCtx.setFillColor(col(0, 0, 1))
        holeCtx.fill(CGRect(x: 0, y: 0, width: halfW, height: halfH))           // blue: bottom-left
        holeCtx.setFillColor(col(1, 1, 0))
        holeCtx.fill(CGRect(x: halfW, y: 0, width: halfW, height: halfH))       // yellow: bottom-right
        let holeContent = holeCtx.makeImage()!

        let layout = FrameLayout.make(mode: .free, imageSize: CGSize(width: holeWidth, height: holeHeight), spec: .v1)
        let result = try FrameRenderer.render(holeContent: holeContent, layout: layout, spec: .v1, svgURL: svgURL)
        let rep = NSBitmapImageRep(cgImage: result)

        // Sample points a quarter/three-quarters of the way across the hole,
        // well inside each quadrant's interior (away from the boundary and
        // from the border edges).
        let qx1 = layout.left + holeWidth / 4
        let qx2 = layout.left + (3 * holeWidth) / 4
        let qy1 = layout.top + holeHeight / 4
        let qy2 = layout.top + (3 * holeHeight) / 4
        let tol = 10.0 / 255.0

        func assertColor(_ x: Int, _ y: Int, _ r: Double, _ g: Double, _ b: Double, _ label: String) {
            guard let c = rep.colorAt(x: x, y: y) else { XCTFail("no color at \(label)"); return }
            XCTAssertEqual(Double(c.redComponent), r, accuracy: tol, "\(label) red")
            XCTAssertEqual(Double(c.greenComponent), g, accuracy: tol, "\(label) green")
            XCTAssertEqual(Double(c.blueComponent), b, accuracy: tol, "\(label) blue")
        }

        assertColor(qx1, qy1, 1, 0, 0, "top-left (expected red)")
        assertColor(qx2, qy1, 0, 1, 0, "top-right (expected green)")
        assertColor(qx1, qy2, 0, 0, 1, "bottom-left (expected blue)")
        assertColor(qx2, qy2, 1, 1, 0, "bottom-right (expected yellow)")
    }

    /// Free mode must show the whole photo, uncropped and centered, as if
    /// `position` were never consulted. Proves this with a quadrant-colored
    /// photo: renders once with `.auto` and once with an extreme
    /// zoomed/panned `PositionState` that would visibly crop/shift the image
    /// if it were honored, then checks all four quadrants land correctly in
    /// BOTH renders -- i.e. the non-default position has zero effect.
    func testBorderedImageFreeModeIgnoresPositionAndShowsWholeImage() throws {
        let pw = 400, ph = 300
        let photo = makeQuadrantImage(width: pw, height: ph)

        let svgURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Template border V1.svg")

        let extremePosition = PositionState(zoom: 1, panX: 0, panY: 0)
        let autoResult = try BorderedImage.make(photo: photo, mode: .free, spec: .v1, svgURL: svgURL, position: .auto)
        let zoomedResult = try BorderedImage.make(photo: photo, mode: .free, spec: .v1, svgURL: svgURL, position: extremePosition)

        let layout = FrameLayout.make(mode: .free, imageSize: CGSize(width: pw, height: ph), spec: .v1)
        XCTAssertEqual(autoResult.width, layout.canvasWidth)
        XCTAssertEqual(autoResult.height, layout.canvasHeight)
        XCTAssertEqual(zoomedResult.width, layout.canvasWidth)
        XCTAssertEqual(zoomedResult.height, layout.canvasHeight)

        let qx1 = layout.left + pw / 4, qx2 = layout.left + (3 * pw) / 4
        let qy1 = layout.top + ph / 4, qy2 = layout.top + (3 * ph) / 4
        let tol = 10.0 / 255.0

        for (result, label) in [(autoResult, "auto"), (zoomedResult, "zoomed/panned")] {
            let rep = NSBitmapImageRep(cgImage: result)
            func assertColor(_ x: Int, _ y: Int, _ r: Double, _ g: Double, _ b: Double, _ corner: String) {
                guard let c = rep.colorAt(x: x, y: y) else { XCTFail("no color at \(corner) (\(label))"); return }
                XCTAssertEqual(Double(c.redComponent), r, accuracy: tol, "\(corner) red (\(label))")
                XCTAssertEqual(Double(c.greenComponent), g, accuracy: tol, "\(corner) green (\(label))")
                XCTAssertEqual(Double(c.blueComponent), b, accuracy: tol, "\(corner) blue (\(label))")
            }
            assertColor(qx1, qy1, 1, 0, 0, "top-left (expected red)")
            assertColor(qx2, qy1, 0, 1, 0, "top-right (expected green)")
            assertColor(qx1, qy2, 0, 0, 1, "bottom-left (expected blue)")
            assertColor(qx2, qy2, 1, 1, 0, "bottom-right (expected yellow)")
        }
    }

    /// Page modes must contain-fit the photo into the hole: when the photo's
    /// aspect ratio doesn't match the hole's, the result is letterboxed
    /// (white gutter bars), never stretched to fill and never cropped.
    /// Uses a 3:1 wide photo against an A5 hole (~1.42:1 landscape once the
    /// layout swaps to match the photo's orientation) so the mismatch forces
    /// visible top/bottom letterboxing.
    func testBorderedImagePageModeLetterboxes() throws {
        let pw = 900, ph = 300
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

        let rep = NSBitmapImageRep(cgImage: result)
        let holeW = layout.holeWidth, holeH = layout.holeHeight

        // Center of the hole: the photo's own blue should be present.
        let center = rep.colorAt(x: layout.left + holeW / 2, y: layout.top + holeH / 2)!
        XCTAssertGreaterThan(center.blueComponent, 0.7, "center should show photo content")
        XCTAssertLessThan(center.redComponent, 0.5, "center should not be white gutter")

        // Near the top and bottom edges of the hole: the 3:1 photo is far
        // wider than the hole, so contain-fit must leave a letterbox gutter
        // there -- these pixels should be the white gutter fill, not photo
        // content (proves it's not stretched to fill and not cropped).
        let margin = max(2, holeH / 20)
        let topGutter = rep.colorAt(x: layout.left + holeW / 2, y: layout.top + margin)!
        let bottomGutter = rep.colorAt(x: layout.left + holeW / 2, y: layout.top + holeH - margin)!
        for (label, c) in [("top", topGutter), ("bottom", bottomGutter)] {
            XCTAssertGreaterThan(c.redComponent, 0.9, "\(label) gutter should be white")
            XCTAssertGreaterThan(c.greenComponent, 0.9, "\(label) gutter should be white")
            XCTAssertGreaterThan(c.blueComponent, 0.9, "\(label) gutter should be white")
        }

        // Near the left edge at vertical mid-height: contain-fit scales to
        // fill the hole's full width, so the photo should reach edge-to-edge
        // horizontally (no pillarboxing / no crop of the width).
        let leftEdge = rep.colorAt(x: layout.left + 2, y: layout.top + holeH / 2)!
        XCTAssertGreaterThan(leftEdge.blueComponent, 0.7, "left edge should show photo content (no pillarbox)")
    }

    /// Page mode (A4/A5) is the code path with the most flip operations: a
    /// placement flip in BorderedImage.make() on top of the hole flip in
    /// FrameRenderer.render(). It's also untested with template V2 or with
    /// a non-centered `position`. A centered/default position can't catch a
    /// broken placement flip, because a perfectly-centered rect is
    /// symmetric under that flip whether or not it's correct -- so this
    /// test uses an extreme cover+pan position, which forces an asymmetric
    /// vertical offset that a wrong-signed flip would visibly get wrong.
    func testBorderedImageA5V2PreservesOrientationUnderPan() throws {
        let svgURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Template border V2.svg")

        // A5+V2 hole geometry for a portrait photo (width < height).
        let probe = FrameLayout.make(mode: .a5, imageSize: CGSize(width: 1, height: 2), spec: .v2)
        let holeW = probe.holeWidth, holeH = probe.holeHeight

        // Photo exactly as wide as the hole (no horizontal overflow) but 3x
        // taller, so cover mode (zoom: 1) scales it to exactly fill the
        // hole's width while overflowing 2x the hole's height. An extreme
        // panY (0 or 1) then shows only the photo's top band or only its
        // bottom band -- each entirely within one color half of the
        // quadrant photo, so the sampled colors are unambiguous.
        let photoWidth = holeW, photoHeight = holeH * 3
        let photo = makeQuadrantImage(width: photoWidth, height: photoHeight)

        let layout = FrameLayout.make(mode: .a5, imageSize: CGSize(width: photoWidth, height: photoHeight), spec: .v2)
        let qx1 = layout.left + photoWidth / 4, qx2 = layout.left + (3 * photoWidth) / 4
        let sampleY = layout.top + layout.holeHeight / 2
        let tol = 10.0 / 255.0

        func assertBand(panY: CGFloat, left: (Double, Double, Double), right: (Double, Double, Double), _ label: String) throws {
            let position = PositionState(zoom: 1, panX: 0.5, panY: panY)
            let result = try BorderedImage.make(photo: photo, mode: .a5, spec: .v2, svgURL: svgURL, position: position)
            let rep = NSBitmapImageRep(cgImage: result)
            func assertColor(_ x: Int, _ r: Double, _ g: Double, _ b: Double, _ side: String) {
                guard let c = rep.colorAt(x: x, y: sampleY) else { XCTFail("no color at \(side) (\(label))"); return }
                XCTAssertEqual(Double(c.redComponent), r, accuracy: tol, "\(side) red (\(label))")
                XCTAssertEqual(Double(c.greenComponent), g, accuracy: tol, "\(side) green (\(label))")
                XCTAssertEqual(Double(c.blueComponent), b, accuracy: tol, "\(side) blue (\(label))")
            }
            assertColor(qx1, left.0, left.1, left.2, "left")
            assertColor(qx2, right.0, right.1, right.2, "right")
        }

        // panY: 0 -- top of the (top-left-authored) placement rect aligns
        // with the hole's top, showing the photo's top band (red/green).
        try assertBand(panY: 0, left: (1, 0, 0), right: (0, 1, 0), "top band")
        // panY: 1 -- bottom of the placement rect aligns with the hole's
        // bottom, showing the photo's bottom band (blue/yellow).
        try assertBand(panY: 1, left: (0, 0, 1), right: (1, 1, 0), "bottom band")
    }
}
