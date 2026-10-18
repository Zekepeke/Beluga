import Foundation
import Security

/// Minimal generic-password storage for LLM provider API keys, one per provider.
enum KeychainStore {

    private static var service: String {
        "\(Bundle.main.bundleIdentifier ?? "com.zekepeke.beluga").llm-cleanup"
    }

    private static func query(for provider: CleanupProvider) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
        ]
    }

    static func get(for provider: CleanupProvider) -> String? {
        var query = query(for: provider)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// An empty value deletes the entry.
    static func set(_ value: String, for provider: CleanupProvider) {
        guard !value.isEmpty else {
            delete(for: provider)
            return
        }
        let data = Data(value.utf8)
        let status = SecItemUpdate(query(for: provider) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var attributes = query(for: provider)
            attributes[kSecValueData as String] = data
            SecItemAdd(attributes as CFDictionary, nil)
        }
    }

    static func delete(for provider: CleanupProvider) {
        SecItemDelete(query(for: provider) as CFDictionary)
    }
}
