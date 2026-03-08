import Foundation

// MARK: - GitHub 使用者

/// GitHub 使用者基本資料，由 `GET /user` API 回傳。
public struct GitHubUser: Codable, Equatable, Sendable {
    
    /// 使用者的登入帳號名稱。
    public let login: String
    
    /// 使用者的顯示名稱，可能為 `nil`。
    public let name: String?
    
    /// 以指定的屬性值初始化。
    ///
    /// - Parameters:
    ///   - login: 使用者的登入帳號名稱。
    ///   - name: 使用者的顯示名稱，可能為 `nil`。
    public init(login: String, name: String? = nil) {
        self.login = login
        self.name = name
    }
}
