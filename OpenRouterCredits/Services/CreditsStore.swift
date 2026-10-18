import Foundation
import Observation

/// Observable application state shared by the menu bar, popover, settings and
/// floating panel.
@MainActor
@Observable
final class CreditsStore {
    private let client: CreditsFetching
    private let keyStore: APIKeyStoring
    private let now: () -> Date

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
        self.hasAPIKey = (try? keyStore.readAPIKey()) != nil
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
        return text
    }

    /// Fetches the balance from OpenRouter unless a request is already running.
    func refresh() async {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        let apiKey: String
        do {
            guard let storedKey = try keyStore.readAPIKey() else {
                hasAPIKey = false
                balance = nil
                error = .missingAPIKey
                return
            }
            apiKey = storedKey
            hasAPIKey = true
        } catch {
            self.error = .keychain
            return
        }

        do {
            let snapshot = try await client.fetchCredits(apiKey: apiKey)
            balance = snapshot.remaining
            lastUpdated = now()
            error = nil
        } catch is CancellationError {
            return
        } catch let creditsError as CreditsError {
            error = creditsError
        } catch {
            self.error = .network
        }
    }

    /// Saves a key to the Keychain and refreshes the balance.
    func saveAPIKey(_ key: String) throws {
        try keyStore.saveAPIKey(key)
        hasAPIKey = true
        error = nil
    }

    func deleteAPIKey() throws {
        try keyStore.deleteAPIKey()
        hasAPIKey = false
        balance = nil
        lastUpdated = nil
        error = .missingAPIKey
    }

    /// Returns the stored key so the Settings field can display it using the
    /// secure field's built-in masking. The value stays in memory only.
    func savedAPIKey() -> String? {
        try? keyStore.readAPIKey()
    }

    /// Validates a key without changing the displayed balance. When no key is
    /// supplied, the saved Keychain item is used.
    func testConnection(apiKey: String?) async -> Result<Decimal, CreditsError> {
        let trimmed = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let key: String
        do {
            if !trimmed.isEmpty {
                key = trimmed
            } else if let savedKey = try keyStore.readAPIKey() {
                key = savedKey
            } else {
                return .failure(.missingAPIKey)
            }
        } catch {
            return .failure(.keychain)
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
}
