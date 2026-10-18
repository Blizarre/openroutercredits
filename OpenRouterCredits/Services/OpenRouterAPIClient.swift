import Foundation

enum CreditsError: Error, Equatable {
    case missingAPIKey
    case unauthorized
    case forbidden
    case rateLimited(retryAfter: TimeInterval?)
    case server(statusCode: Int)
    case network
    case decoding
    case invalidResponse
    case keychain

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add your OpenRouter management API key in Settings."
        case .unauthorized:
            return "The management key is invalid or expired."
        case .forbidden:
            return "This key is not a management API key."
        case .rateLimited:
            return "OpenRouter is rate limiting requests. Retrying later."
        case .server(let statusCode):
            return "OpenRouter server error (\(statusCode)). Retrying later."
        case .network:
            return "Can't reach OpenRouter. Check your connection."
        case .decoding, .invalidResponse:
            return "Unexpected response from OpenRouter."
        case .keychain:
            return "Couldn't access the management key in the Keychain."
        }
    }

    /// Whether waiting and retrying is worthwhile for this error.
    var isRetryable: Bool {
        switch self {
        case .rateLimited, .server, .network:
            return true
        case .missingAPIKey, .unauthorized, .forbidden, .decoding, .invalidResponse, .keychain:
            return false
        }
    }
}

extension CreditsError: LocalizedError {
    var localizedDescription: String { errorDescription ?? "Unknown error." }
}

protocol CreditsFetching {
    func fetchCredits(apiKey: String) async throws -> CreditsSnapshot
}

/// The only type that knows the OpenRouter credits endpoint.
struct OpenRouterAPIClient: CreditsFetching {
    static let endpoint = URL(string: "https://openrouter.ai/api/v1/credits")!

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchCredits(apiKey: String) async throws -> CreditsSnapshot {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw CreditsError.network
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CreditsError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            do {
                return try JSONDecoder().decode(CreditsResponse.self, from: data).snapshot
            } catch {
                throw CreditsError.decoding
            }
        case 401:
            throw CreditsError.unauthorized
        case 403:
            throw CreditsError.forbidden
        case 429:
            throw CreditsError.rateLimited(retryAfter: Self.retryAfter(from: httpResponse))
        case 500...599:
            throw CreditsError.server(statusCode: httpResponse.statusCode)
        default:
            throw CreditsError.invalidResponse
        }
    }

    private static func retryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After") else {
            return nil
        }
        return TimeInterval(value.trimmingCharacters(in: .whitespaces))
    }
}
