import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(CreditsStore.self) private var store

    @State private var apiKey = ""
    @State private var savedKey = ""
    @State private var connectionMessage: String?
    @State private var connectionMessageIsError = false
    @State private var isTestingConnection = false

    @AppStorage("lowBalanceThreshold") private var lowBalanceThreshold = 5.0
    @AppStorage("showFloatingPanel") private var showFloatingPanel = false

    var body: some View {
        Form {
            Section("OpenRouter") {
                HStack(spacing: 8) {
                    SecureField(
                        "Management API key",
                        text: $apiKey,
                        prompt: Text("Paste management key")
                    )

                    if store.hasAPIKey && !trimmedKey.isEmpty && trimmedKey == savedKey {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                HStack {
                    Button("Save") {
                        saveKey()
                    }
                    .disabled(trimmedKey.isEmpty)

                    Button(isTestingConnection ? "Testing…" : "Test Connection") {
                        testConnection()
                    }
                    .disabled(isTestingConnection || (trimmedKey.isEmpty && !store.hasAPIKey))
                }

                if let connectionMessage {
                    Text(connectionMessage)
                        .font(.callout)
                        .foregroundStyle(connectionMessageIsError ? Color.red : Color.secondary)
                } else if store.hasAPIKey {
                    Text("A management key is saved in the Keychain.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Text("Create a management key at openrouter.ai/settings/management-keys.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Balance") {
                TextField("Low-balance threshold (USD)", value: $lowBalanceThreshold, format: .number)
                Text("Refreshes every 5 minutes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Display") {
                Toggle("Show floating panel", isOn: $showFloatingPanel)
                Toggle("Launch at login", isOn: .constant(false))
                    .disabled(true)
            }

            Section("Security") {
                Text("The management key is stored only in the macOS Keychain on this Mac. It is never written to UserDefaults, logs, crash reports, or URLs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .padding(.vertical, 8)
        .background(SettingsWindowActivator())
        .task {
            guard apiKey.isEmpty, let storedKey = store.savedAPIKey() else { return }
            apiKey = storedKey
            savedKey = storedKey
        }
    }

    private var trimmedKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveKey() {
        do {
            try store.saveAPIKey(trimmedKey)
            apiKey = trimmedKey
            savedKey = trimmedKey
            connectionMessage = "Saved to the Keychain."
            connectionMessageIsError = false
            Task { await store.refresh() }
        } catch {
            connectionMessage = error.localizedDescription
            connectionMessageIsError = true
        }
    }

    private func testConnection() {
        isTestingConnection = true
        connectionMessage = nil

        Task {
            let result = await store.testConnection(apiKey: apiKey)
            isTestingConnection = false

            switch result {
            case .success(let balance):
                connectionMessage = "Connected. Remaining balance: \(MoneyFormatter.string(from: balance))"
                connectionMessageIsError = false
            case .failure(let error):
                connectionMessage = error.localizedDescription
                connectionMessageIsError = true
            }
        }
    }
}
