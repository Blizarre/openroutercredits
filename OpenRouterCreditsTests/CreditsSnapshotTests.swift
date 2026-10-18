import XCTest

final class CreditsSnapshotTests: XCTestCase {
    func testRemainingIsCreditsMinusUsage() {
        let snapshot = CreditsSnapshot(totalCredits: 100.5, totalUsage: 25.75)

        XCTAssertEqual(snapshot.remaining, 74.75)
    }

    func testRemainingCanBeNegative() {
        let snapshot = CreditsSnapshot(totalCredits: 10, totalUsage: 12.5)

        XCTAssertEqual(snapshot.remaining, -2.5)
    }
}
