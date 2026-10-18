import Foundation
import Observation
import ServiceManagement

/// Wraps `SMAppService.mainApp` so the Settings toggle reflects the real
/// system state and can report registration errors.
@MainActor
@Observable
final class LaunchAtLoginController {
    private(set) var isEnabled: Bool
    private(set) var errorMessage: String?

    init() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        errorMessage = status == .requiresApproval
            ? "Allow OpenRouter Credits in System Settings › General › Login Items."
            : nil
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }

            let status = SMAppService.mainApp.status
            isEnabled = status == .enabled
            errorMessage = status == .requiresApproval
                ? "Allow OpenRouter Credits in System Settings › General › Login Items."
                : nil
        } catch {
            isEnabled = SMAppService.mainApp.status == .enabled
            errorMessage = error.localizedDescription
        }
    }
}
