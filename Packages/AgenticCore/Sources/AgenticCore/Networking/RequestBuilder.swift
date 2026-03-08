import Foundation

// MARK: - HTTP 方法

/// 支援的 HTTP 方法。
public enum HTTPMethod: String, Sendable {
    
    /// HTTP GET 方法。
    case get = "GET"
    
    /// HTTP POST 方法。
    case post = "POST"
    
    /// HTTP PUT 方法。
    case put = "PUT"
    
    /// HTTP DELETE 方法。
    case delete = "DELETE"
}

// MARK: - RequestBuilder

/// 以 fluent API 建構 `URLRequest` 的輔助工具。
///
/// 純 value type，符合 `Sendable`，可安全跨並行邊界傳遞。
///
/// ```swift
/// let request = RequestBuilder(url: someURL)
///     .method(.post)
///     .bearerToken("abc123")
///     .jsonBody(encodable)
///     .build()
/// ```
public struct RequestBuilder: Sendable {
    
    /// 請求的目標 URL。
    private let url: URL
    
    /// HTTP 方法，預設為 `.get`。
    private var httpMethod: HTTPMethod = .get
    
    /// 自訂標頭列表。
    private var headers: [(String, String)] = []
    
    /// 請求的 HTTP body 資料。
    private var body: Data?
    
    /// 以目標 URL 初始化 builder。
    public init(url: URL) {
        self.url = url
    }
    
    /// 以 URL 字串初始化 builder。
    ///
    /// - Parameter urlString: URL 字串，必須為合法 URL。
    public init(urlString: String) {
        self.url = URL(string: urlString)!
    }
    
    // MARK: - Fluent Setters
    
    /// 設定 HTTP 方法。
    ///
    /// - Parameter method: 要使用的 ``HTTPMethod``。
    /// - Returns: 套用新方法後的 ``RequestBuilder``。
    public func method(_ method: HTTPMethod) -> RequestBuilder {
        var copy = self
        copy.httpMethod = method
        return copy
    }
    
    /// 加入 Bearer Token 認證標頭。
    ///
    /// - Parameter token: Bearer 存取權杖。
    /// - Returns: 套用認證標頭後的 ``RequestBuilder``。
    public func bearerToken(_ token: String) -> RequestBuilder {
        header("Authorization", "Bearer \(token)")
    }
    
    /// 設定自訂標頭，同名標頭會被覆蓋。
    ///
    /// - Parameters:
    ///   - name: 標頭名稱。
    ///   - value: 標頭值。
    /// - Returns: 套用新標頭後的 ``RequestBuilder``。
    public func header(_ name: String, _ value: String) -> RequestBuilder {
        var copy = self
        copy.headers.removeAll { $0.0.caseInsensitiveCompare(name) == .orderedSame }
        copy.headers.append((name, value))
        return copy
    }
    
    /// 設定 JSON body，自動加入 `Content-Type: application/json`。
    ///
    /// - Parameter value: 要編碼為 JSON 的 `Encodable` 物件。
    /// - Returns: 套用 JSON body 後的 ``RequestBuilder``。
    public func jsonBody<T: Encodable>(_ value: T) throws -> RequestBuilder {
        var copy = self
        copy.body = try JSONEncoder().encode(value)
        return copy.header("Content-Type", "application/json")
    }
    
    /// 設定原始 JSON 字串 body，自動加入 `Content-Type: application/json`。
    ///
    /// - Parameter rawJSON: 原始 JSON 字串。
    /// - Returns: 套用 JSON body 後的 ``RequestBuilder``。
    public func jsonBody(_ rawJSON: String) -> RequestBuilder {
        var copy = self
        copy.body = rawJSON.data(using: .utf8)
        return copy.header("Content-Type", "application/json")
    }
    
    /// 設定 form-urlencoded body，自動加入 `Content-Type`。
    ///
    /// - Parameter params: 以 `&` 連結的 key=value 字串陣列。
    /// - Returns: 套用 form body 後的 ``RequestBuilder``。
    public func formBody(_ params: [String]) -> RequestBuilder {
        var copy = self
        copy.body = params.joined(separator: "&").data(using: .utf8)
        return copy.header("Content-Type", "application/x-www-form-urlencoded")
    }
    
    // MARK: - Build
    
    /// 建構最終的 `URLRequest`。
    ///
    /// - Returns: 依據目前設定組裝完成的 `URLRequest`。
    public func build() -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod.rawValue
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        request.httpBody = body
        return request
    }
}
