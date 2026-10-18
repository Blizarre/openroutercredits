import XCTest

final class LowBalanceTrackerTests: XCTestCase {
    func testDownwardCrossingNotifies() {
        var tracker = LowBalanceTracker()

        XCTAssertTrue(tracker.shouldNotify(balance: 4, threshold: 5))
    }

    func testStayingBelowDoesNotNotifyAgain() {
        var tracker = LowBalanceTracker()

        XCTAssertTrue(tracker.shouldNotify(balance: 4, threshold: 5))
        XCTAssertFalse(tracker.shouldNotify(balance: 3, threshold: 5))
        XCTAssertFalse(tracker.shouldNotify(balance: 1, threshold: 5))
    }

    func testRisingAboveRearmsNotification() {
        var tracker = LowBalanceTracker()

        XCTAssertTrue(tracker.shouldNotify(balance: 4, threshold: 5))
        XCTAssertFalse(tracker.shouldNotify(balance: 8, threshold: 5))
        XCTAssertTrue(tracker.shouldNotify(balance: 2, threshold: 5))
    }

    func testExactlyAtThresholdIsNotBelow() {
        var tracker = LowBalanceTracker()

        XCTAssertFalse(tracker.shouldNotify(balance: 5, threshold: 5))
    }

    func testPersistedBelowStateSuppressesNotification() {
        var tracker = LowBalanceTracker(wasBelowThreshold: true)

        XCTAssertFalse(tracker.shouldNotify(balance: 1, threshold: 5))
    }
}
