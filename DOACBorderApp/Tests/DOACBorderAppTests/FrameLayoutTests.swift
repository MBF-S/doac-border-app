import CoreGraphics
@testable import DOACBorderApp

func assert(_ condition: Bool, _ message: String) {
    if !condition {
        print("FAIL: \(message)")
    } else {
        print("PASS: \(message)")
    }
}

func testFreeModeMatchesValidatedPythonOutput() {
    // Same inputs as border.py's validated chart_like test: 836x534 image, V1, defaults.
    let layout = FrameLayout.make(mode: .free, imageSize: CGSize(width: 836, height: 534), spec: .v1)
    assert(layout.left == 60, "testFreeModeMatchesValidatedPythonOutput: left=\(layout.left)")
    assert(layout.top == 56, "testFreeModeMatchesValidatedPythonOutput: top=\(layout.top)")
    assert(layout.right == 69, "testFreeModeMatchesValidatedPythonOutput: right=\(layout.right)")
    assert(layout.bottom == 62, "testFreeModeMatchesValidatedPythonOutput: bottom=\(layout.bottom)")
    assert(layout.bottomRight == 112, "testFreeModeMatchesValidatedPythonOutput: bottomRight=\(layout.bottomRight)")
    assert(layout.canvasWidth == 965, "testFreeModeMatchesValidatedPythonOutput: canvasWidth=\(layout.canvasWidth)")
    assert(layout.canvasHeight == 652, "testFreeModeMatchesValidatedPythonOutput: canvasHeight=\(layout.canvasHeight)")
    assert(layout.holeWidth == 836, "testFreeModeMatchesValidatedPythonOutput: holeWidth=\(layout.holeWidth)")
    assert(layout.holeHeight == 534, "testFreeModeMatchesValidatedPythonOutput: holeHeight=\(layout.holeHeight)")
}

func testA4LandscapeMatchesValidatedPythonOutput() {
    // Same inputs as border.py's validated A4 test: 600x400 landscape image, V1, 300dpi.
    let layout = FrameLayout.make(mode: .a4, imageSize: CGSize(width: 600, height: 400), spec: .v1)
    assert(layout.canvasWidth == 3508, "testA4LandscapeMatchesValidatedPythonOutput: canvasWidth=\(layout.canvasWidth)")
    assert(layout.canvasHeight == 2480, "testA4LandscapeMatchesValidatedPythonOutput: canvasHeight=\(layout.canvasHeight)")
    assert(layout.left == 198, "testA4LandscapeMatchesValidatedPythonOutput: left=\(layout.left)")
    assert(layout.top == 186, "testA4LandscapeMatchesValidatedPythonOutput: top=\(layout.top)")
    assert(layout.right == 230, "testA4LandscapeMatchesValidatedPythonOutput: right=\(layout.right)")
    assert(layout.bottom == 205, "testA4LandscapeMatchesValidatedPythonOutput: bottom=\(layout.bottom)")
    assert(layout.bottomRight == 371, "testA4LandscapeMatchesValidatedPythonOutput: bottomRight=\(layout.bottomRight)")
    assert(layout.holeWidth == 3080, "testA4LandscapeMatchesValidatedPythonOutput: holeWidth=\(layout.holeWidth)")
    assert(layout.holeHeight == 2089, "testA4LandscapeMatchesValidatedPythonOutput: holeHeight=\(layout.holeHeight)")
}

func testMinPxFloorProtectsSmallImages() {
    // 250x180 image: 8% of 180 = 14.4, well under the 60px floor.
    let layout = FrameLayout.make(mode: .free, imageSize: CGSize(width: 250, height: 180), spec: .v1)
    assert(layout.left == 60, "testMinPxFloorProtectsSmallImages: left=\(layout.left)")
}
