import Foundation
import Testing

@testable import AgenticCore

@Suite("RequestBuilder")
struct RequestBuilderTests {

    // MARK: - HTTP Method

    /// 驗證預設 HTTP 方法為 GET
    @Test
    func defaultMethod_isGet() {
        let request = RequestBuilder(url: testURL).build()
        #expect(request.httpMethod == "GET")
    }

    /// 驗證設定 HTTP 方法為 POST
    @Test
    func method_post() {
        let request = RequestBuilder(url: testURL).method(.post).build()
        #expect(request.httpMethod == "POST")
    }

    /// 驗證設定 HTTP 方法為 PUT
    @Test
    func method_put() {
        let request = RequestBuilder(url: testURL).method(.put).build()
        #expect(request.httpMethod == "PUT")
    }

    /// 驗證設定 HTTP 方法為 DELETE
    @Test
    func method_delete() {
        let request = RequestBuilder(url: testURL).method(.delete).build()
        #expect(request.httpMethod == "DELETE")
    }

    // MARK: - URL

    /// 驗證以 URL 字串初始化時正確設定請求網址
    @Test
    func urlString_init() {
        let request = RequestBuilder(urlString: "https://example.com/path").build()
        #expect(request.url?.absoluteString == "https://example.com/path")
    }

    // MARK: - Fluent chaining

    /// 驗證鏈式呼叫產生獨立副本，原始 builder 不受影響
    @Test
    func fluentChaining_immutable() {
        let builder1 = RequestBuilder(url: testURL)
        let builder2 = builder1.method(.post)
        // builder1 應仍然產生 GET
        #expect(builder1.build().httpMethod == "GET")
        #expect(builder2.build().httpMethod == "POST")
    }

    // MARK: - Headers

    /// 驗證相同名稱的 Header 會以不區分大小寫的方式覆蓋
    @Test
    func header_caseInsensitiveDedup() {
        let request = RequestBuilder(url: testURL)
            .header("Accept", "text/html")
            .header("accept", "application/json")
            .build()
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    /// 驗證可同時設定多個不同名稱的 Header
    @Test
    func header_multipleDistinctHeaders() {
        let request = RequestBuilder(url: testURL)
            .header("X-Custom-1", "value1")
            .header("X-Custom-2", "value2")
            .build()
        #expect(request.value(forHTTPHeaderField: "X-Custom-1") == "value1")
        #expect(request.value(forHTTPHeaderField: "X-Custom-2") == "value2")
    }

    // MARK: - Bearer token

    /// 驗證 bearerToken 方法正確設定 Authorization 標頭
    @Test
    func bearerToken_setsAuthorizationHeader() {
        let request = RequestBuilder(url: testURL)
            .bearerToken("abc123")
            .build()
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer abc123")
    }

    // MARK: - JSON body (Encodable)

    /// 驗證以 Encodable 物件設定 JSON body 並正確編碼
    @Test
    func jsonBody_encodable() throws {
        struct TestPayload: Codable {
            let name: String
        }
        let request = try RequestBuilder(url: testURL)
            .method(.post)
            .jsonBody(TestPayload(name: "test"))
            .build()
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.httpBody != nil)
        let decoded = try JSONDecoder().decode(TestPayload.self, from: request.httpBody!)
        #expect(decoded.name == "test")
    }

    // MARK: - JSON body (raw string)

    /// 驗證以原始 JSON 字串設定 body 並正確寫入
    @Test
    func jsonBody_rawString() {
        let request = RequestBuilder(url: testURL)
            .method(.post)
            .jsonBody("{\"key\":\"value\"}")
            .build()
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = String(data: request.httpBody!, encoding: .utf8)
        #expect(body == "{\"key\":\"value\"}")
    }

    // MARK: - Form body

    /// 驗證 formBody 正確設定表單編碼的 Content-Type 與內容
    @Test
    func formBody() {
        let request = RequestBuilder(url: testURL)
            .method(.post)
            .formBody(["grant_type=refresh_token", "client_id=abc"])
            .build()
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
        let body = String(data: request.httpBody!, encoding: .utf8)
        #expect(body == "grant_type=refresh_token&client_id=abc")
    }

    // MARK: - jsonBody overrides Content-Type

    /// 驗證 jsonBody 會覆蓋先前手動設定的 Content-Type
    @Test
    func jsonBody_overridesPreviousContentType() {
        let request = RequestBuilder(url: testURL)
            .header("Content-Type", "text/plain")
            .jsonBody("{}")
            .build()
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }
}

// MARK: - Helper Methods

private extension RequestBuilderTests {

    /// 測試用的基礎 URL
    var testURL: URL {
        URL(string: "https://api.example.com/test")!
    }
}
