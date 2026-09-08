import XCTest
@testable import LoginToggle

final class NameFilterTests: XCTestCase {
    func testVisibleNamesAreKept() {
        XCTAssertTrue(hasVisibleName("Rectangle"))
        XCTAssertTrue(hasVisibleName("1Password"))
        XCTAssertTrue(hasVisibleName("🚀 Launch"))
        XCTAssertTrue(hasVisibleName("!!!"))
        XCTAssertTrue(hasVisibleName("—"))
        XCTAssertTrue(hasVisibleName("1"))
    }

    func testInvisibleNamesAreRejected() {
        XCTAssertFalse(hasVisibleName(""))
        XCTAssertFalse(hasVisibleName(" "))
        XCTAssertFalse(hasVisibleName("\t\n "))
        XCTAssertFalse(hasVisibleName("\u{200B}"))
        XCTAssertFalse(hasVisibleName("\u{200B}\u{FEFF}"))
        XCTAssertFalse(hasVisibleName("\u{2060}"))
        XCTAssertFalse(hasVisibleName("\u{00AD}"))
        XCTAssertFalse(hasVisibleName(" \u{200B} "))
    }
}
