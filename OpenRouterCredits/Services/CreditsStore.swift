import Foundation
import Observation

/// Observable application state shared by the menu bar, popover and settings.
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

    private let userDefaults: UserDefaults
    private let notificationService: LowBalanceNotifying
    private var lowBalanceTracker: LowBalanceTracker

    private(set) var balance: Decimal?
    private(set) var lastUpdated: Date?
    private(set) var error: CreditsError?
    private(set) var isLoading = false
    private(set) var hasAPIKey: Bool
    private(set) var lowBalanceThreshold: Decimal

    init(
        client: CreditsFetching = OpenRouterAPIClient(),
        keyStore: APIKeyStoring = KeychainStore(),
        now: @escaping () -> Date = Date.init,
        userDefaults: UserDefaults = .standard,
        notificationService: LowBalanceNotifying = NotificationService()
    ) {
        self.client = client
        self.keyStore = keyStore
        self.now = now
        self.userDefaults = userDefaults
        self.notificationService = notificationService
        self.lowBalanceThreshold = AppSettings.lowBalanceThreshold(from: userDefaults)
        self.lowBalanceTracker = LowBalanceTracker(
            wasBelowThreshold: userDefaults.bool(forKey: AppSettings.lowBalanceWasBelowKey)
        )

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

    /// True when the displayed data is older than two refresh intervals.
    var isStale: Bool {
        guard let lastUpdated else { return false }
        return now().timeIntervalSince(lastUpdated) > Self.staleInterval
    }

    var nextRefreshDelay: TimeInterval {
        Backoff.delay(afterFailures: consecutiveFailures, retryAfter: retryAfter)
    }

    /// Re-reads the threshold so the warning updates without a network refresh.
    func syncLowBalanceThreshold() {
        let value = AppSettings.lowBalanceThreshold(from: userDefaults)
        if value != lowBalanceThreshold {
            lowBalanceThreshold = value
        }
    }

    var isLowBalance: Bool {
        guard let balance else { return false }
        return balance < lowBalanceThreshold
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
        syncLowBalanceThreshold()

        if let lastUpdated,
           error == nil,
           now().timeIntervalSince(lastUpdated) < Self.refreshInterval {
            return
        }
        await refresh()
    }

    /// Fetches the balance from OpenRouter unless a request is already running.
    func refresh() async {
        syncLowBalanceThreshold()
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
            evaluateLowBalance(remaining: snapshot.remaining)
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
        lowBalanceTracker = LowBalanceTracker()
        userDefaults.set(false, forKey: AppSettings.lowBalanceWasBelowKey)
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

    private func evaluateLowBalance(remaining: Decimal) {
        let threshold = lowBalanceThreshold
        let thresholdValue = (threshold as NSDecimalNumber).doubleValue
        let storedThreshold = userDefaults.object(
            forKey: AppSettings.lastLowBalanceThresholdKey
        ) as? Double

        // A threshold change only rebases the crossing state. Notifications
        // are for balance movements, not for the user editing the threshold.
        // A missing stored threshold means this is the first evaluation.
        if let storedThreshold, storedThreshold != thresholdValue {
            lowBalanceTracker = LowBalanceTracker(
                wasBelowThreshold: remaining < threshold
            )
            persistLowBalanceState(thresholdValue: thresholdValue)
            return
        }

        let shouldNotify = lowBalanceTracker.shouldNotify(balance: remaining, threshold: threshold)
        persistLowBalanceState(thresholdValue: thresholdValue)

        if shouldNotify {
            notificationService.notifyLowBalance(balance: remaining, threshold: threshold)
        }
    }

    private func persistLowBalanceState(thresholdValue: Double) {
        userDefaults.set(thresholdValue, forKey: AppSettings.lastLowBalanceThresholdKey)
        userDefaults.set(
            lowBalanceTracker.wasBelowThreshold,
            forKey: AppSettings.lowBalanceWasBelowKey
        )
    }
}
