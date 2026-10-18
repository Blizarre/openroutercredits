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

private final class MockNotifier: LowBalanceNotifying {
    struct Call: Equatable {
        let balance: Decimal
        let threshold: Decimal
    }

    var calls: [Call] = []

    func notifyLowBalance(balance: Decimal, threshold: Decimal) {
        calls.append(Call(balance: balance, threshold: threshold))
    }
}

private func makeTestDefaults() -> UserDefaults {
    let suite = "OpenRouterCreditsTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}

@MainActor
final class CreditsStoreTests: XCTestCase {
    func testReadsKeyOnceAndCachesItAcrossRefreshes() async {
        let keyStore = MockKeyStore()
        keyStore.key = "cached-key"
        let client = MockClient(result: .success(CreditsSnapshot(totalCredits: 10, totalUsage: 2)))
        let store = CreditsStore(
            client: client,
            keyStore: keyStore,
            userDefaults: makeTestDefaults(),
            notificationService: MockNotifier()
        )

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
        let store = CreditsStore(
            client: client,
            keyStore: keyStore,
            userDefaults: makeTestDefaults(),
            notificationService: MockNotifier()
        )

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
        let store = CreditsStore(
            client: client,
            keyStore: keyStore,
            now: { clock.now },
            userDefaults: makeTestDefaults(),
            notificationService: MockNotifier()
        )

        await store.refresh()
        XCTAssertFalse(store.isStale)

        clock.now = clock.now.addingTimeInterval(CreditsStore.staleInterval + 1)
        XCTAssertTrue(store.isStale)
    }

    func testSavingKeyUpdatesCacheWithoutAnotherRead() async throws {
        let keyStore = MockKeyStore()
        let client = MockClient(result: .success(CreditsSnapshot(totalCredits: 10, totalUsage: 2)))
        let store = CreditsStore(
            client: client,
            keyStore: keyStore,
            userDefaults: makeTestDefaults(),
            notificationService: MockNotifier()
        )

        try store.saveAPIKey("new-key")
        await store.refresh()

        XCTAssertEqual(store.savedAPIKey(), "new-key")
        XCTAssertEqual(keyStore.readCount, 1)
        XCTAssertEqual(keyStore.saveCount, 1)
    }

    func testLowBalanceNotifiesOnlyOnDownwardCrossing() async {
        let keyStore = MockKeyStore()
        keyStore.key = "key"
        let notifier = MockNotifier()
        let client = MockClient(result: .success(CreditsSnapshot(totalCredits: 3, totalUsage: 0)))
        let store = CreditsStore(
            client: client,
            keyStore: keyStore,
            userDefaults: makeTestDefaults(),
            notificationService: notifier
        )

        await store.refresh()
        XCTAssertEqual(notifier.calls.count, 1)
        XCTAssertTrue(store.isLowBalance)

        await store.refresh()
        XCTAssertEqual(notifier.calls.count, 1)

        client.result = .success(CreditsSnapshot(totalCredits: 10, totalUsage: 0))
        await store.refresh()
        XCTAssertFalse(store.isLowBalance)

        client.result = .success(CreditsSnapshot(totalCredits: 2, totalUsage: 0))
        await store.refresh()
        XCTAssertEqual(notifier.calls.count, 2)
    }

    func testLowBalanceStatePersistsAcrossStores() async {
        let defaults = makeTestDefaults()
        let keyStore = MockKeyStore()
        keyStore.key = "key"
        let client = MockClient(result: .success(CreditsSnapshot(totalCredits: 3, totalUsage: 0)))

        let firstNotifier = MockNotifier()
        let first = CreditsStore(
            client: client,
            keyStore: keyStore,
            userDefaults: defaults,
            notificationService: firstNotifier
        )
        await first.refresh()
        XCTAssertEqual(firstNotifier.calls.count, 1)

        let secondNotifier = MockNotifier()
        let second = CreditsStore(
            client: client,
            keyStore: keyStore,
            userDefaults: defaults,
            notificationService: secondNotifier
        )
        await second.refresh()
        XCTAssertEqual(secondNotifier.calls.count, 0)
    }
}
