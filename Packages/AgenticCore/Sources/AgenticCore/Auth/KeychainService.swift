import Foundation
import Security

/// A dependency-injectable Keychain wrapper for storing OAuth tokens.
public struct KeychainService: Sendable {
    public var save: @Sendable (_ key: String, _ data: Data) throws -> Void
    public var load: @Sendable (_ key: String) throws -> Data?
    public var delete: @Sendable (_ key: String) throws -> Void

    public init(
        save: @escaping @Sendable (_ key: String, _ data: Data) throws -> Void,
        load: @escaping @Sendable (_ key: String) throws -> Data?,
        delete: @escaping @Sendable (_ key: String) throws -> Void
    ) {
        self.save = save
        self.load = load
        self.delete = delete
    }
}

// MARK: - Keys

extension KeychainService {
    /// The Keychain key used to store the GitHub OAuth access token.
    public static let accessTokenKey = "github_access_token"
}

// MARK: - Errors

public enum KeychainError: LocalizedError, Sendable {
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case unexpectedError(OSStatus)

    public var errorDescription: String? {
        switch self {
        case let .saveFailed(status):
            "Keychain save failed (status: \(status))"
        case let .deleteFailed(status):
            "Keychain delete failed (status: \(status))"
        case let .unexpectedError(status):
            "Keychain error (status: \(status))"
        }
    }
}

// MARK: - Live Implementation

private let serviceName = "com.leoho.AgenticUsage"

extension KeychainService {
    public static let live = KeychainService(
        save: { key, data in
            // Delete existing item first (ignore errors)
            let deleteQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: key,
            ]
            SecItemDelete(deleteQuery as CFDictionary)

            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: key,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            ]
            let status = SecItemAdd(addQuery as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw KeychainError.saveFailed(status)
            }
        },
        load: { key in
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: key,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)

            switch status {
            case errSecSuccess:
                return result as? Data
            case errSecItemNotFound:
                return nil
            default:
                throw KeychainError.unexpectedError(status)
            }
        },
        delete: { key in
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: key,
            ]
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw KeychainError.deleteFailed(status)
            }
        }
    )
}

// MARK: - Convenience

extension KeychainService {
    /// Save the OAuth access token string to the Keychain.
    public func saveAccessToken(_ token: String) throws {
        guard let data = token.data(using: .utf8) else { return }
        try save(KeychainService.accessTokenKey, data)
    }

    /// Load the OAuth access token string from the Keychain.
    public func loadAccessToken() throws -> String? {
        guard let data = try load(KeychainService.accessTokenKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Delete the OAuth access token from the Keychain.
    public func deleteAccessToken() throws {
        try delete(KeychainService.accessTokenKey)
    }
}
