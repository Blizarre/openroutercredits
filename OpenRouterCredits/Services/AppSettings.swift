import Foundation

enum AppSettings {
    static let lowBalanceThresholdKey = "lowBalanceThreshold"
    static let lowBalanceWasBelowKey = "lowBalanceWasBelow"
    static let lastLowBalanceThresholdKey = "lastLowBalanceThreshold"
    static let slowRefreshIntervalKey = "slowRefreshInterval"
    static let fastRefreshIntervalKey = "fastRefreshInterval"
    static let unchangedRefreshLimitKey = "unchangedRefreshLimit"

    static let defaultLowBalanceThreshold: Decimal = 5
    static let defaultSlowRefreshInterval: TimeInterval = 300
    static let defaultFastRefreshInterval: TimeInterval = 60
    static let defaultUnchangedRefreshLimit = 5

    static let minimumSlowRefreshInterval: TimeInterval = 60
    static let minimumFastRefreshInterval: TimeInterval = 30
    static let minimumUnchangedRefreshLimit = 1

    static func lowBalanceThreshold(from defaults: UserDefaults = .standard) -> Decimal {
        guard defaults.object(forKey: lowBalanceThresholdKey) != nil else {
            return defaultLowBalanceThreshold
        }
        return Decimal(defaults.double(forKey: lowBalanceThresholdKey))
    }

    /// The interval used while the balance is steady.
    static func slowRefreshInterval(from defaults: UserDefaults = .standard) -> TimeInterval {
        let stored = defaults.object(forKey: slowRefreshIntervalKey) != nil
            ? defaults.double(forKey: slowRefreshIntervalKey)
            : defaultSlowRefreshInterval
        guard stored.isFinite else { return defaultSlowRefreshInterval }
        return max(stored, minimumSlowRefreshInterval)
    }

    /// The interval used after the balance changes. Never exceeds the slow
    /// interval, so the fast tier can only speed things up.
    static func fastRefreshInterval(from defaults: UserDefaults = .standard) -> TimeInterval {
        let stored = defaults.object(forKey: fastRefreshIntervalKey) != nil
            ? defaults.double(forKey: fastRefreshIntervalKey)
            : defaultFastRefreshInterval
        guard stored.isFinite else { return defaultFastRefreshInterval }
        let clamped = max(stored, minimumFastRefreshInterval)
        return min(clamped, slowRefreshInterval(from: defaults))
    }

    /// How many consecutive unchanged checks are needed before returning to
    /// the slow interval.
    static func unchangedRefreshLimit(from defaults: UserDefaults = .standard) -> Int {
        guard defaults.object(forKey: unchangedRefreshLimitKey) != nil else {
            return defaultUnchangedRefreshLimit
        }
        return max(defaults.integer(forKey: unchangedRefreshLimitKey), minimumUnchangedRefreshLimit)
    }
}
