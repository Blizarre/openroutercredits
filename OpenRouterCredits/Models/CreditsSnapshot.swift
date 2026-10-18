import Foundation

/// A point-in-time view of an OpenRouter account's credit balance.
struct CreditsSnapshot: Equatable, Sendable {
    let totalCredits: Decimal
    let totalUsage: Decimal

    var remaining: Decimal {
        totalCredits - totalUsage
    }
}
