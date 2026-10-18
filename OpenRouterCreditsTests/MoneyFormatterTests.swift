import XCTest

final class MoneyFormatterTests: XCTestCase {
    func testZero() {
        XCTAssertEqual(MoneyFormatter.string(from: 0), "$0.00")
    }

    func testLargeAmountUsesGrouping() {
        XCTAssertEqual(
            MoneyFormatter.string(from: Decimal(string: "1234567.89")!),
            "$1,234,567.89"
        )
    }

    func testNegativeAmount() {
        XCTAssertEqual(MoneyFormatter.string(from: Decimal(string: "-2.5")!), "-$2.50")
    }

    func testRoundsHalfUpToTwoDecimalPlaces() {
        XCTAssertEqual(MoneyFormatter.string(from: Decimal(string: "1.005")!), "$1.01")
    }
}
