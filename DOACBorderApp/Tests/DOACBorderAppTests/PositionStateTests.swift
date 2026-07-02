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

    func testZoomPastCoverAllowsPanningBothAxes() {
        // At zoom<=1 a non-square image only overflows on one axis (whichever cover's
        // aspect-locked dimension doesn't exactly fill), so the other axis can't pan.
        // Past cover (zoom>1) both axes must overflow and both must respond to pan.
        var state = PositionState.auto
        state.zoom = 2
        state.panX = 0
        state.panY = 0
        let atStart = state.placement(imageSize: CGSize(width: 600, height: 400), holeSize: CGSize(width: 500, height: 500))
        state.panX = 1
        state.panY = 1
        let atEnd = state.placement(imageSize: CGSize(width: 600, height: 400), holeSize: CGSize(width: 500, height: 500))
        XCTAssertNotEqual(atStart.origin.x, atEnd.origin.x, "panX should move the image once zoomed past cover")
        XCTAssertNotEqual(atStart.origin.y, atEnd.origin.y, "panY should move the image once zoomed past cover")
    }
}
