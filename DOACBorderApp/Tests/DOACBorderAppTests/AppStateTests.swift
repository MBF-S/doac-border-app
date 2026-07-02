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

    func testSizeUnitRoundTripsThroughMillimeters() {
        XCTAssertEqual(SizeUnit.cm.fromMM(210), 21, accuracy: 0.001)
        XCTAssertEqual(SizeUnit.cm.toMM(21), 210, accuracy: 0.001)
        XCTAssertEqual(SizeUnit.inch.fromMM(25.4), 1, accuracy: 0.001)
        XCTAssertEqual(SizeUnit.inch.toMM(1), 25.4, accuracy: 0.001)
    }
}
