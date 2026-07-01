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
        let result = try FrameRenderer.render(holeContent: holeContent, layout: layout, svgURL: svgURL)
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
}
