import Foundation
import Observation

/// Observable application state shared by the menu bar, popover, settings and
/// floating panel.
@MainActor
@Observable
final class CreditsStore {
    static let refreshInterval: TimeInterval = 300
    static let staleInterval: TimeInterval = 600

    private let client: CreditsFetching
    private let keyStore: APIKeyStoring
    private let now: () -> Date

    private var refreshTask: Task<Void, Never>?
    private var consecutiveFailures = 0
    private var retryAfter: TimeInterval?

    /// The key is read from the Keychain once per launch and then kept in
    /// memory only. This avoids a Keychain prompt on every refresh.
    private var cachedAPIKey: String?
    private var keyLoadFailed = false

    private(set) var balance: Decimal?
    private(set) var lastUpdated: Date?
    private(set) var error: CreditsError?
    private(set) var isLoading = false
    private(set) var hasAPIKey: Bool

    init(
        client: CreditsFetching = OpenRouterAPIClient(),
        keyStore: APIKeyStoring = KeychainStore(),
        now: @escaping () -> Date = Date.init
    ) {
        self.client = client
        self.keyStore = keyStore
        self.now = now

        do {
            let storedKey = try keyStore.readAPIKey()
            self.cachedAPIKey = storedKey
            self.hasAPIKey = storedKey != nil
        } catch {
            self.cachedAPIKey = nil
            self.keyLoadFailed = true
            self.hasAPIKey = false
        }
    }

    var menuBarText: String {
        guard let balance else { return "$--" }
        return MoneyFormatter.string(from: balance)
    }

    var tooltip: String {
        guard let balance else {
            return "OpenRouter Credits — no balance yet"
        }

        var text = "OpenRouter Credits — \(MoneyFormatter.string(from: balance))"
        if let lastUpdated {
            text += "\nUpdated \(lastUpdated.formatted(date: .abbreviated, time: .shortened))"
        }
        if isStale {
            text += "\nBalance is stale."
        }
        return text
    }

    /// True when the displayed data is older than two refresh intervals.
    var isStale: Bool {
        guard let lastUpdated else { return false }
        return now().timeIntervalSince(lastUpdated) > Self.staleInterval
    }

    var nextRefreshDelay: TimeInterval {
        Backoff.delay(afterFailures: consecutiveFailures, retryAfter: retryAfter)
    }

    /// Starts the background refresh loop. Refreshes immediately, then every
    /// five minutes (or sooner when backing off from a transient failure).
    func start() {
        guard refreshTask == nil else { return }

        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()

                let delay = self.nextRefreshDelay
                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } catch {
                    return
                }
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    /// Refreshes when there is no data yet or the last update is older than
    /// the normal refresh interval. Used when the popover opens.
    func refreshIfNeeded() async {
        if let lastUpdated,
           error == nil,
           now().timeIntervalSince(lastUpdated) < Self.refreshInterval {
            return
        }
        await refresh()
    }

    /// Fetches the balance from OpenRouter unless a request is already running.
    func refresh() async {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        guard let apiKey = cachedAPIKey else {
            hasAPIKey = false
            balance = nil
            error = keyLoadFailed ? .keychain : .missingAPIKey
            resetFailureState()
            return
        }
        hasAPIKey = true

        do {
            let snapshot = try await client.fetchCredits(apiKey: apiKey)
            balance = snapshot.remaining
            lastUpdated = now()
            error = nil
            resetFailureState()
        } catch is CancellationError {
            return
        } catch let creditsError as CreditsError {
            error = creditsError
            recordFailure(creditsError)
        } catch {
            self.error = .network
            recordFailure(.network)
        }
    }

    /// Saves a key to the Keychain and refreshes the balance.
    func saveAPIKey(_ key: String) throws {
        try keyStore.saveAPIKey(key)
        cachedAPIKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        keyLoadFailed = false
        hasAPIKey = true
        error = nil
        resetFailureState()
    }

    func deleteAPIKey() throws {
        try keyStore.deleteAPIKey()
        cachedAPIKey = nil
        keyLoadFailed = false
        hasAPIKey = false
        balance = nil
        lastUpdated = nil
        error = .missingAPIKey
        resetFailureState()
    }

    /// Returns the cached key so the Settings field can display it using the
    /// secure field's built-in masking. Never reads the Keychain again.
    func savedAPIKey() -> String? {
        cachedAPIKey
    }

    /// Validates a key without changing the displayed balance. When no key is
    /// supplied, the cached Keychain value is used.
    func testConnection(apiKey: String?) async -> Result<Decimal, CreditsError> {
        let trimmed = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let key: String
        if !trimmed.isEmpty {
            key = trimmed
        } else if let cachedAPIKey {
            key = cachedAPIKey
        } else if keyLoadFailed {
            return .failure(.keychain)
        } else {
            return .failure(.missingAPIKey)
        }

        do {
            let snapshot = try await client.fetchCredits(apiKey: key)
            return .success(snapshot.remaining)
        } catch is CancellationError {
            return .failure(.network)
        } catch let creditsError as CreditsError {
            return .failure(creditsError)
        } catch {
            return .failure(.network)
        }
    }

    private func recordFailure(_ creditsError: CreditsError) {
        guard creditsError.isRetryable else {
            resetFailureState()
            return
        }

        consecutiveFailures = min(consecutiveFailures + 1, 10)

        if case .rateLimited(let value) = creditsError {
            retryAfter = value
        } else {
            retryAfter = nil
        }
    }

    private func resetFailureState() {
        consecutiveFailures = 0
        retryAfter = nil
    }
}
