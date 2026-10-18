import Foundation

enum AppSettings {
    static let lowBalanceThresholdKey = "lowBalanceThreshold"
    static let lowBalanceWasBelowKey = "lowBalanceWasBelow"
    static let lastLowBalanceThresholdKey = "lastLowBalanceThreshold"

    static let defaultLowBalanceThreshold: Decimal = 5

    static func lowBalanceThreshold(from defaults: UserDefaults = .standard) -> Decimal {
        guard defaults.object(forKey: lowBalanceThresholdKey) != nil else {
            return defaultLowBalanceThreshold
        }
        return Decimal(defaults.double(forKey: lowBalanceThresholdKey))
    }
}
