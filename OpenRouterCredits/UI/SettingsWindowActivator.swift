import AppKit
import SwiftUI

/// Brings the Settings window to the front when it first appears.
///
/// A menu-bar-only app uses the `.accessory` activation policy, so opening a
/// Settings scene does not automatically activate the app. Without this the
/// window can open behind other applications.
struct SettingsWindowActivator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
