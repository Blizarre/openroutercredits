import XCTest

private final class MockKeyStore: APIKeyStoring {
    var key: String?
    var readCount = 0
    var readError: Error?
    var saveCount = 0

    func readAPIKey() throws -> String? {
        readCount += 1
        if let readError { throw readError }
        return key
    }

    func saveAPIKey(_ key: String) throws {
        saveCount += 1
        self.key = key
    }

    func deleteAPIKey() throws {
        key = nil
    }
}

private final class MockClient: CreditsFetching {
    var result: Result<CreditsSnapshot, Error>
    var callCount = 0

    init(result: Result<CreditsSnapshot, Error>) {
        self.result = result
    }

    func fetchCredits(apiKey: String) async throws -> CreditsSnapshot {
        callCount += 1
        return try result.get()
    }
}

private final class TestClock {
    var now = Date(timeIntervalSince1970: 1_000_000)
}

@MainActor
final class CreditsStoreTests: XCTestCase {
    func testReadsKeyOnceAndCachesItAcrossRefreshes() async {
        let keyStore = MockKeyStore()
        keyStore.key = "cached-key"
        let client = MockClient(result: .success(CreditsSnapshot(totalCredits: 10, totalUsage: 2)))
        let store = CreditsStore(client: client, keyStore: keyStore)

        await store.refresh()
        await store.refresh()

        XCTAssertEqual(keyStore.readCount, 1)
        XCTAssertEqual(client.callCount, 2)
        XCTAssertEqual(store.balance, 8)
        XCTAssertTrue(store.hasAPIKey)
    }

    func testMissingKeyDoesNotCallAPI() async {
        let keyStore = MockKeyStore()
        let client = MockClient(result: .success(CreditsSnapshot(totalCredits: 1, totalUsage: 0)))
        let store = CreditsStore(client: client, keyStore: keyStore)

        await store.refresh()

        XCTAssertEqual(client.callCount, 0)
        XCTAssertEqual(store.error, .missingAPIKey)
        XCTAssertFalse(store.hasAPIKey)
    }

    func testStaleAfterTwoRefreshIntervals() async {
        let clock = TestClock()
        let keyStore = MockKeyStore()
        keyStore.key = "key"
        let client = MockClient(result: .success(CreditsSnapshot(totalCredits: 10, totalUsage: 2)))
        let store = CreditsStore(client: client, keyStore: keyStore, now: { clock.now })

        await store.refresh()
        XCTAssertFalse(store.isStale)

        clock.now = clock.now.addingTimeInterval(CreditsStore.staleInterval + 1)
        XCTAssertTrue(store.isStale)
    }

    func testSavingKeyUpdatesCacheWithoutAnotherRead() async throws {
        let keyStore = MockKeyStore()
        let client = MockClient(result: .success(CreditsSnapshot(totalCredits: 10, totalUsage: 2)))
        let store = CreditsStore(client: client, keyStore: keyStore)

        try store.saveAPIKey("new-key")
        await store.refresh()

        XCTAssertEqual(store.savedAPIKey(), "new-key")
        XCTAssertEqual(keyStore.readCount, 1)
        XCTAssertEqual(keyStore.saveCount, 1)
    }
}
