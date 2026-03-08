import Foundation
import Testing

@testable import AgenticCore

@Suite("HTTPClientError")
struct HTTPClientErrorTests {

    /// 驗證 invalidResponse 錯誤的描述包含「Invalid HTTP response」
    @Test
    func invalidResponse_description() {
        let error = HTTPClientError.invalidResponse
        #expect(error.errorDescription?.contains("Invalid HTTP response") == true)
    }

    /// 驗證 httpError 錯誤的描述包含狀態碼與錯誤訊息
    @Test
    func httpError_description() {
        let error = HTTPClientError.httpError(
            statusCode: 401,
            message: "Unauthorized",
            data: Data()
        )
        let desc = error.errorDescription!
        #expect(desc.contains("401"))
        #expect(desc.contains("Unauthorized"))
    }

    /// 驗證 decodingFailed 錯誤的描述包含解碼失敗資訊與原始回應內容
    @Test
    func decodingFailed_description() {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "test decode error" }
        }
        let error = HTTPClientError.decodingFailed(
            underlyingError: TestError(),
            rawResponse: "some raw json"
        )
        let desc = error.errorDescription!
        #expect(desc.contains("decode"))
        #expect(desc.contains("some raw json"))
    }

    /// 驗證 decodingFailed 錯誤會截斷過長的原始回應內容
    @Test
    func decodingFailed_truncatesLongResponse() {
        let longResponse = String(repeating: "x", count: 1000)
        let error = HTTPClientError.decodingFailed(
            underlyingError: NSError(domain: "test", code: 0),
            rawResponse: longResponse
        )
        let desc = error.errorDescription!
        // 原始回應應透過 .prefix(500) 截斷至 500 字元以內
        #expect(desc.count < 1000)
    }
}
