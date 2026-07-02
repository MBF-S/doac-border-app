import XCTest
import CoreGraphics
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
        XCTAssertEqual(layout.left, 60)
    }
}
