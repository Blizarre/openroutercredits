import Foundation

/// Tracks whether the balance has crossed below the configured threshold.
///
/// A notification is emitted only on a downward crossing. Staying below the
/// threshold does not notify again; rising back to or above it re-arms the
/// tracker for the next crossing.
struct LowBalanceTracker {
    private(set) var wasBelowThreshold: Bool

    init(wasBelowThreshold: Bool = false) {
        self.wasBelowThreshold = wasBelowThreshold
    }

    mutating func shouldNotify(balance: Decimal, threshold: Decimal) -> Bool {
        let isBelow = balance < threshold
        let shouldNotify = isBelow && !wasBelowThreshold
        wasBelowThreshold = isBelow
        return shouldNotify
    }
}
