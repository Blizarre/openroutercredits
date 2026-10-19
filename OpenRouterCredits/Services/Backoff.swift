import Foundation

/// Retry timing for the background refresh loop.
///
/// Successful refreshes wait for the configured base interval (the slow or
/// fast tier). Retryable failures ignore the base interval, start at
/// `minimumRetryDelay` and double up to a cap. A server-provided `Retry-After`
/// value can extend the delay further.
enum Backoff {
    static let defaultBaseInterval: TimeInterval = 300
    static let minimumRetryDelay: TimeInterval = 60
    static let maximumDelay: TimeInterval = 900

    static func delay(
        afterFailures failures: Int,
        baseInterval: TimeInterval = defaultBaseInterval,
        retryAfter: TimeInterval? = nil
    ) -> TimeInterval {
        var delay = baseInterval

        if failures > 0 {
            let exponent = min(failures - 1, 10)
            delay = min(minimumRetryDelay * pow(2, Double(exponent)), maximumDelay)
        }

        if let retryAfter, retryAfter.isFinite, retryAfter > 0 {
            delay = max(delay, retryAfter)
        }

        return delay
    }
}
