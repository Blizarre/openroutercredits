import AppKit
import SwiftUI

struct PopoverView: View {
    @Environment(CreditsStore.self) private var store
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "creditcard.fill")
                Text("OpenRouter Credits")
                    .font(.headline)
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(store.menuBarText)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()

                if store.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                Text(statusText)
                    .font(.callout)
                    .foregroundStyle(store.error == nil ? Color.secondary : Color.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack {
                Button {
                    Task { await store.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.isLoading)

                Spacer()

                Button("Open OpenRouter") {
                    NSWorkspace.shared.open(URL(string: "https://openrouter.ai")!)
                }
            }

            Divider()

            HStack {
                Button("Settings…") {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                }
                Spacer()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 300)
        .task {
            await store.refresh()
        }
    }

    private var statusText: String {
        if store.isLoading {
            return "Updating…"
        }
        if let error = store.error {
            return error.localizedDescription
        }
        if let lastUpdated = store.lastUpdated {
            return "Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))"
        }
        return "No balance loaded yet."
    }

    private var statusColor: Color {
        if store.error != nil { return .red }
        if store.lastUpdated != nil { return .green }
        return .secondary
    }
}
