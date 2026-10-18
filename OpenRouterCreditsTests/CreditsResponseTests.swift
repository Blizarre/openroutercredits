import XCTest

final class CreditsResponseTests: XCTestCase {
    func testDecodesFullResponse() throws {
        let json = #"{"data":{"total_credits":100.5,"total_usage":25.75}}"#

        let response = try JSONDecoder().decode(CreditsResponse.self, from: Data(json.utf8))

        XCTAssertEqual(response.snapshot.totalCredits, Decimal(string: "100.5"))
        XCTAssertEqual(response.snapshot.totalUsage, Decimal(string: "25.75"))
        XCTAssertEqual(response.snapshot.remaining, Decimal(string: "74.75"))
    }

    func testMissingTotalUsageDefaultsToZero() throws {
        let json = #"{"data":{"total_credits":100.5}}"#

        let response = try JSONDecoder().decode(CreditsResponse.self, from: Data(json.utf8))

        XCTAssertEqual(response.snapshot.totalUsage, 0)
        XCTAssertEqual(response.snapshot.remaining, Decimal(string: "100.5"))
    }

    func testMissingTotalCreditsDefaultsToZero() throws {
        let json = #"{"data":{"total_usage":12}}"#

        let response = try JSONDecoder().decode(CreditsResponse.self, from: Data(json.utf8))

        XCTAssertEqual(response.snapshot.totalCredits, 0)
        XCTAssertEqual(response.snapshot.remaining, -12)
    }

    func testMissingDataFailsToDecode() {
        let json = #"{"error":"nope"}"#

        XCTAssertThrowsError(
            try JSONDecoder().decode(CreditsResponse.self, from: Data(json.utf8))
        )
    }
}
