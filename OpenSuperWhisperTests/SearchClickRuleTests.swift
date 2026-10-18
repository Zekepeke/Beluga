import XCTest
@testable import OpenSuperWhisper

final class SearchClickRuleTests: XCTestCase {
    private let field = CGRect(x: 70, y: 4, width: 360, height: 24)
    private let icon = CGRect(x: 400, y: 2, width: 28, height: 28)
    private let outside = CGPoint(x: 200, y: 300)

    private func close(open: Bool = true, empty: Bool = true, at point: CGPoint, field: CGRect? = nil, since: TimeInterval = 5) -> Bool {
        SearchClickRule.shouldClose(isOpen: open, queryIsEmpty: empty, point: point, fieldFrame: field ?? self.field,
                                    iconFrame: icon, secondsSinceOpened: since)
    }

    func testClickOutsideWithEmptyFieldCloses() {
        XCTAssertTrue(close(at: outside))
    }

    func testOpeningClickIsIgnored() {
        XCTAssertFalse(close(at: outside, since: 0.05))
    }

    func testClickBeforeFieldHasALayoutIsIgnored() {
        XCTAssertFalse(close(at: outside, field: .zero))
    }

    func testClickOnTheIconIsIgnored() {
        XCTAssertFalse(close(at: CGPoint(x: 410, y: 10), field: CGRect(x: 70, y: 4, width: 300, height: 24)))
    }

    func testClickInsideTheFieldIsIgnored() {
        XCTAssertFalse(close(at: CGPoint(x: 100, y: 10)))
    }

    func testTextKeepsTheResults() {
        XCTAssertFalse(close(empty: false, at: outside))
    }

    func testClosedSearchNeverCloses() {
        XCTAssertFalse(close(open: false, at: outside))
    }
}
