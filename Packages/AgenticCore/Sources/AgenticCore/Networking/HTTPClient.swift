import Foundation

// MARK: - HTTPClient 錯誤

/// HTTPClient 共用錯誤。
public enum HTTPClientError: LocalizedError, Sendable {
    
    /// 回應不是 `HTTPURLResponse`。
    case invalidResponse
    
    /// HTTP 狀態碼非 2xx。
    case httpError(statusCode: Int, message: String, data: Data)
    
    /// JSON 解碼失敗。
    case decodingFailed(underlyingError: any Error, rawResponse: String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid HTTP response"
        case let .httpError(statusCode, message, _):
            "HTTP error (\(statusCode)): \(message)"
        case let .decodingFailed(underlyingError, rawResponse):
            """
            Failed to decode response: \
            \(underlyingError.localizedDescription)
            Raw response: \(rawResponse.prefix(500))
            """
        }
    }
}

// MARK: - HTTPClient

/// 包裝 `URLSession` 的共用 HTTP 用戶端。
///
/// 提供 `fetch()` 與 `fetchRaw()` 兩個核心方法，統一處理
/// HTTP 回應驗證與 JSON 解碼，減少各 API Client 的重複程式碼。
public struct HTTPClient: Sendable {
    
    /// 用於執行 HTTP 請求的 `URLSession` 實例。
    private let session: URLSession
    
    /// 以預設 `URLSessionConfiguration` 初始化。
    public init() {
        self.session = URLSession(configuration: .default)
    }
    
    // MARK: - 核心方法
    
    /// 執行 HTTP 請求，驗證回應並解碼為指定型別。
    ///
    /// - Parameters:
    ///   - request: 要執行的 `URLRequest`。
    ///   - responseType: 要解碼的目標型別。
    ///   - validate: 可選的自訂驗證 closure。接收 `(HTTPURLResponse, Data)`，
    ///     回傳 `nil` 表示通過預設驗證，回傳非 `nil` 的 `Data` 表示已自行處理
    ///     （例如 401 回傳特殊邏輯），此時會跳過後續驗證並嘗試解碼回傳的 Data。
    ///     若需中斷流程，直接 throw。
    /// - Returns: 解碼後的回應物件。
    public func fetch<T: Decodable>(
        _ request: URLRequest,
        responseType: T.Type,
        validate: (@Sendable (HTTPURLResponse, Data) throws -> Data?)? = nil
    ) async throws -> T {
        let (_, data) = try await fetchRaw(request, validate: validate)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let rawJSON = String(data: data, encoding: .utf8) ?? "<non-UTF8 data>"
            throw HTTPClientError.decodingFailed(
                underlyingError: error,
                rawResponse: rawJSON
            )
        }
    }
    
    /// 執行 HTTP 請求並驗證回應，回傳原始 `(HTTPURLResponse, Data)`。
    ///
    /// - Parameters:
    ///   - request: 要執行的 `URLRequest`。
    ///   - validate: 可選的自訂驗證 closure。接收 `(HTTPURLResponse, Data)`，
    ///     回傳 `nil` 表示繼續預設 2xx 驗證，回傳非 `nil` 的 `Data` 表示已自行處理
    ///     （跳過預設驗證，以回傳的 Data 取代）。若需中斷流程，直接 throw。
    /// - Returns: `(HTTPURLResponse, Data)` 元組。
    public func fetchRaw(
        _ request: URLRequest,
        validate: (@Sendable (HTTPURLResponse, Data) throws -> Data?)? = nil
    ) async throws -> (HTTPURLResponse, Data) {
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPClientError.invalidResponse
        }
        
        // 若有自訂驗證且回傳非 nil，使用其結果
        if let validate {
            if let overriddenData = try validate(httpResponse, data) {
                return (httpResponse, overriddenData)
            }
        }
        
        // 預設 2xx 驗證
        guard (200...299).contains(httpResponse.statusCode) else {
            throw HTTPClientError.httpError(
                statusCode: httpResponse.statusCode,
                message: extractErrorMessage(from: data),
                data: data
            )
        }
        
        return (httpResponse, data)
    }
}
