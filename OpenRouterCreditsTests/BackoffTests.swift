import XCTest

final class BackoffTests: XCTestCase {
    func testNormalRefreshUsesBaseInterval() {
        XCTAssertEqual(Backoff.delay(afterFailures: 0), 300)
    }

    func testFirstFailureRetriesSooner() {
        XCTAssertEqual(Backoff.delay(afterFailures: 1), 60)
    }

    func testRepeatedFailuresDouble() {
        XCTAssertEqual(Backoff.delay(afterFailures: 2), 120)
        XCTAssertEqual(Backoff.delay(afterFailures: 3), 240)
        XCTAssertEqual(Backoff.delay(afterFailures: 4), 480)
    }

    func testDelayIsCapped() {
        XCTAssertEqual(Backoff.delay(afterFailures: 5), 900)
        XCTAssertEqual(Backoff.delay(afterFailures: 50), 900)
    }

    func testRetryAfterCanExtendDelay() {
        XCTAssertEqual(Backoff.delay(afterFailures: 1, retryAfter: 150), 150)
    }

    func testInvalidRetryAfterIsIgnored() {
        XCTAssertEqual(Backoff.delay(afterFailures: 1, retryAfter: -5), 60)
        XCTAssertEqual(Backoff.delay(afterFailures: 1, retryAfter: .infinity), 60)
    }
}
