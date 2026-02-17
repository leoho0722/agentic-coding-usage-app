import Foundation
import Security

// MARK: - 鑰匙圈服務

/// 可依賴注入的鑰匙圈封裝，用於儲存 OAuth 權杖。
///
/// 透過閉包注入，讓 TCA 與 CLI 可各自提供不同的實作（正式版、模擬版等）。
public struct KeychainService: Sendable {
    
    /// 將資料儲存至鑰匙圈。
    public var save: @Sendable (_ key: String, _ data: Data) throws -> Void
    
    /// 從鑰匙圈載入資料。
    public var load: @Sendable (_ key: String) throws -> Data?
    
    /// 從鑰匙圈刪除資料。
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

// MARK: - 金鑰

extension KeychainService {
    
    /// 用於儲存 GitHub OAuth 存取權杖的鑰匙圈金鑰。
    public static let accessTokenKey = "github_access_token"
}

// MARK: - 錯誤

/// 鑰匙圈操作錯誤。
public enum KeychainError: LocalizedError, Sendable {
    
    /// 儲存失敗。
    case saveFailed(OSStatus)
    
    /// 刪除失敗。
    case deleteFailed(OSStatus)
    
    /// 未預期的錯誤。
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

// MARK: - 正式版實作

/// 鑰匙圈服務名稱。
private let serviceName = "com.leoho.AgenticUsage"

extension KeychainService {
    
    /// 使用 macOS Security Framework 的正式版實作。
    public static let live = KeychainService(
        save: { key, data in
            // 先刪除既有項目（忽略錯誤）
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

// MARK: - 便捷方法

extension KeychainService {
    
    /// 將 OAuth 存取權杖字串儲存至鑰匙圈。
    ///
    /// - Parameter token: 要儲存的存取權杖字串。
    /// - Throws: 儲存失敗時拋出 ``KeychainError``。
    public func saveAccessToken(_ token: String) throws {
        guard let data = token.data(using: .utf8) else { return }
        try save(KeychainService.accessTokenKey, data)
    }
    
    /// 從鑰匙圈載入 OAuth 存取權杖字串。
    ///
    /// - Returns: 存取權杖字串，不存在時回傳 `nil`。
    /// - Throws: 載入失敗時拋出 ``KeychainError``。
    public func loadAccessToken() throws -> String? {
        guard let data = try load(KeychainService.accessTokenKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// 從鑰匙圈刪除 OAuth 存取權杖。
    ///
    /// - Throws: 刪除失敗時拋出 ``KeychainError``。
    public func deleteAccessToken() throws {
        try delete(KeychainService.accessTokenKey)
    }
}
