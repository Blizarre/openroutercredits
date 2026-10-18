import Foundation
import Security

/// Errors surfaced by the Keychain wrapper. The underlying key is never
/// included in the error or its description.
struct KeychainError: Error, Equatable {
    let status: OSStatus
    let operation: String

    var localizedDescription: String {
        let detail = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
        return "Keychain \(operation) failed: \(detail)"
    }
}

extension KeychainError: LocalizedError {
    var errorDescription: String? { localizedDescription }
}

protocol APIKeyStoring {
    func readAPIKey() throws -> String?
    func saveAPIKey(_ key: String) throws
    func deleteAPIKey() throws
}

/// Stores the OpenRouter management key as a generic password in the user's
/// login Keychain. The item is readable after the first unlock, matching a
/// background menu-bar app that may refresh while the screen is locked.
///
/// The key is never written to UserDefaults, logs, crash reports, or URLs.
struct KeychainStore: APIKeyStoring {
    static let defaultService = "ai.openrouter.credits"
    static let defaultAccount = "management-api-key"

    let service: String
    let account: String

    init(
        service: String = KeychainStore.defaultService,
        account: String = KeychainStore.defaultAccount
    ) {
        self.service = service
        self.account = account
    }

    func readAPIKey() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard
                let data = result as? Data,
                let key = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                !key.isEmpty
            else {
                return nil
            }
            return key
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError(status: status, operation: "read")
        }
    }

    func saveAPIKey(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw KeychainError(status: errSecParam, operation: "save")
        }

        let data = Data(trimmed.utf8)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var addQuery = baseQuery
            for (key, value) in attributes {
                addQuery[key] = value
            }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError(status: addStatus, operation: "save")
            }
        default:
            throw KeychainError(status: updateStatus, operation: "save")
        }
    }

    func deleteAPIKey() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status, operation: "delete")
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
