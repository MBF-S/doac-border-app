import XCTest
@testable import DOACBorderApp

final class UpdaterTests: XCTestCase {
    func testIsNewerComparesDottedVersions() {
        XCTAssertTrue(UpdateChecker.isNewer("1.1", than: "1.0"))
        XCTAssertTrue(UpdateChecker.isNewer("2.0", than: "1.9"))
        XCTAssertTrue(UpdateChecker.isNewer("1.10", than: "1.9"))
        XCTAssertFalse(UpdateChecker.isNewer("1.0", than: "1.0"))
        XCTAssertFalse(UpdateChecker.isNewer("1.0", than: "1.1"))
        XCTAssertFalse(UpdateChecker.isNewer("0.9", than: "1.0"))
    }

    func testIsNewerHandlesMismatchedComponentCounts() {
        XCTAssertTrue(UpdateChecker.isNewer("1.0.1", than: "1.0"))
        XCTAssertFalse(UpdateChecker.isNewer("1.0", than: "1.0.1"))
        XCTAssertFalse(UpdateChecker.isNewer("1.0.0", than: "1.0"))
    }
}
