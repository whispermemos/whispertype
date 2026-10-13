import Foundation
import Security

/*
 * Stores the user's Groq API key in the Keychain instead of UserDefaults, which is plain text on disk.
 * Used by the API Key preferences tab to save the key and by Uploading.swift to authorize requests.
 * Saving an empty string deletes the key.
 */

private let groqApiKeyQuery: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: Bundle.main.bundleIdentifier ?? "WhisperType",
    kSecAttrAccount as String: "groqApiKey",
]

func loadGroqApiKey() -> String? {
    var query = groqApiKeyQuery
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var result: AnyObject?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
        let data = result as? Data
    else { return nil }

    return String(data: data, encoding: .utf8)
}

func saveGroqApiKey(_ key: String) {
    SecItemDelete(groqApiKeyQuery as CFDictionary)

    guard !key.isEmpty else { return }

    var item = groqApiKeyQuery
    item[kSecValueData as String] = Data(key.utf8)
    let status = SecItemAdd(item as CFDictionary, nil)
    if status != errSecSuccess {
        print("Failed to save Groq API key to Keychain: \(status)")
    }
}
