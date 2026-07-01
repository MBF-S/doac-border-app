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
