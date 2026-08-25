import XCTest
@testable import VimScroll

final class ScrollDirectionTests: XCTestCase {
    func testVimKeyMappings() {
        XCTAssertEqual(ScrollDirection.from(keyCode: 4), .left)
        XCTAssertEqual(ScrollDirection.from(keyCode: 38), .down)
        XCTAssertEqual(ScrollDirection.from(keyCode: 40), .up)
        XCTAssertEqual(ScrollDirection.from(keyCode: 37), .right)
        XCTAssertNil(ScrollDirection.from(keyCode: 0))
    }

    func testDirectionVectors() {
        XCTAssertEqual(ScrollDirection.left.vector.horizontal, 1)
        XCTAssertEqual(ScrollDirection.down.vector.vertical, -1)
        XCTAssertEqual(ScrollDirection.up.vector.vertical, 1)
        XCTAssertEqual(ScrollDirection.right.vector.horizontal, -1)
    }
}
