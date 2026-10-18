import Foundation

/// Formats a decimal amount as US dollars for the menu bar and UI.
///
/// A fixed `en_US` locale keeps the output predictable regardless of the
/// system locale. Values use two fraction digits with half-up rounding.
enum MoneyFormatter {
    static func string(from value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.currencySymbol = "$"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.roundingMode = .halfUp

        return formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
    }
}
