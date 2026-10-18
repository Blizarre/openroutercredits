import Foundation
import UserNotifications

protocol LowBalanceNotifying {
    /// Fire-and-forget: the caller must not wait for notification delivery.
    func notifyLowBalance(balance: Decimal, threshold: Decimal)
}

/// Sends a local notification when the balance crosses below the threshold.
/// If authorization is denied or unavailable (for example an unsigned local
/// build), the store still shows an in-app warning.
final class NotificationService: LowBalanceNotifying {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func notifyLowBalance(balance: Decimal, threshold: Decimal) {
        Task {
            await send(balance: balance, threshold: threshold)
        }
    }

    private func send(balance: Decimal, threshold: Decimal) async {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                guard granted else { return }
            } catch {
                return
            }
        case .authorized, .provisional, .ephemeral:
            break
        case .denied:
            return
        @unknown default:
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "OpenRouter balance is low"
        content.body = "Remaining balance is \(MoneyFormatter.string(from: balance)), below your \(MoneyFormatter.string(from: threshold)) threshold."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "openrouter-low-balance",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }
}
