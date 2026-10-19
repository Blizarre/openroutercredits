import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(CreditsStore.self) private var store
    @Environment(LaunchAtLoginController.self) private var launchAtLogin

    @State private var apiKey = ""
    @State private var savedKey = ""
    @State private var connectionMessage: String?
    @State private var connectionMessageIsError = false
    @State private var isTestingConnection = false
    @State private var settingsApplyTask: Task<Void, Never>?

    @AppStorage(AppSettings.lowBalanceThresholdKey) private var lowBalanceThreshold = 5.0
    @AppStorage(AppSettings.slowRefreshIntervalKey)
    private var slowRefreshSeconds = AppSettings.defaultSlowRefreshInterval
    @AppStorage(AppSettings.fastRefreshIntervalKey)
    private var fastRefreshSeconds = AppSettings.defaultFastRefreshInterval
    @AppStorage(AppSettings.unchangedRefreshLimitKey)
    private var unchangedRefreshLimit = AppSettings.defaultUnchangedRefreshLimit

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
            }

            Section("Refresh") {
                LabeledContent("Slow refresh") {
                    HStack(spacing: 6) {
                        TextField("Slow refresh", value: slowMinutes, format: .number)
                            .labelsHidden()
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("min")
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledContent("Fast refresh") {
                    HStack(spacing: 6) {
                        TextField("Fast refresh", value: fastMinutes, format: .number)
                            .labelsHidden()
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("min")
                            .foregroundStyle(.secondary)
                    }
                }

                Stepper(
                    "Slow down after \(unchangedRefreshLimit) unchanged checks",
                    value: $unchangedRefreshLimit,
                    in: 1...50
                )

                Text("The app refreshes slowly while the balance is steady. A change switches it to the fast interval until \(unchangedRefreshLimit) consecutive checks show no change.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Display") {
                Toggle(
                    "Launch at login",
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    )
                )

                if let error = launchAtLogin.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Security") {
                Text("The management key is stored only in the macOS Keychain on this Mac. It is never written to UserDefaults, logs, crash reports, or URLs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Spacer()
                    Text(versionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
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
        .onChange(of: lowBalanceThreshold) { _, _ in
            store.syncLowBalanceThreshold()
        }
        .onChange(of: slowRefreshSeconds) { _, _ in scheduleRefreshSettingsApply() }
        .onChange(of: fastRefreshSeconds) { _, _ in scheduleRefreshSettingsApply() }
        .onChange(of: unchangedRefreshLimit) { _, _ in scheduleRefreshSettingsApply() }
    }

    private var slowMinutes: Binding<Double> {
        Binding(
            get: { slowRefreshSeconds / 60 },
            set: { newValue in
                slowRefreshSeconds = max(newValue, 1) * 60
                if fastRefreshSeconds > slowRefreshSeconds {
                    fastRefreshSeconds = slowRefreshSeconds
                }
            }
        )
    }

    private var fastMinutes: Binding<Double> {
        Binding(
            get: { fastRefreshSeconds / 60 },
            set: { newValue in
                fastRefreshSeconds = min(max(newValue, 0.5), slowRefreshSeconds / 60) * 60
            }
        )
    }

    private var trimmedKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "OpenRouter Credits \(version) (\(build))"
    }

    private func scheduleRefreshSettingsApply() {
        settingsApplyTask?.cancel()
        settingsApplyTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await store.syncRefreshSettings()
            await store.restartRefreshLoop()
        }
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
