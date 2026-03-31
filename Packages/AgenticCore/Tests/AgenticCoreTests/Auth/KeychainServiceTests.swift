import Foundation
import Synchronization
import Testing

@testable import AgenticCore

@Suite("KeychainService")
struct KeychainServiceTests {

    // MARK: - saveAccessToken

    /// 驗證 saveAccessToken 以正確的 key 與 UTF-8 編碼資料呼叫 save 閉包
    @Test
    func saveAccessToken_callsSaveWithCorrectKeyAndData() throws {
        let capturedKey = Mutex<String?>(nil)
        let capturedData = Mutex<Data?>(nil)

        let service = KeychainService(
            save: { key, data in
                capturedKey.withLock { $0 = key }
                capturedData.withLock { $0 = data }
            },
            load: { _ in nil },
            delete: { _ in }
        )

        try service.saveAccessToken("test_token_123")

        #expect(capturedKey.withLock { $0 } == KeychainService.accessTokenKey)
        #expect(capturedData.withLock { $0 } == "test_token_123".data(using: .utf8))
    }

    // MARK: - loadAccessToken

    /// 驗證 loadAccessToken 正確解碼 UTF-8 資料為字串
    @Test
    func loadAccessToken_returnsDecodedString() throws {
        let service = KeychainService(
            save: { _, _ in },
            load: { key in
                #expect(key == KeychainService.accessTokenKey)
                return "my_token".data(using: .utf8)
            },
            delete: { _ in }
        )

        let token = try service.loadAccessToken()
        #expect(token == "my_token")
    }

    /// 驗證鑰匙圈無資料時回傳 nil
    @Test
    func loadAccessToken_returnsNilWhenNoData() throws {
        let service = KeychainService(
            save: { _, _ in },
            load: { _ in nil },
            delete: { _ in }
        )

        let token = try service.loadAccessToken()
        #expect(token == nil)
    }

    // MARK: - deleteAccessToken

    /// 驗證 deleteAccessToken 以正確的 key 呼叫 delete 閉包
    @Test
    func deleteAccessToken_callsDeleteWithCorrectKey() throws {
        let capturedKey = Mutex<String?>(nil)

        let service = KeychainService(
            save: { _, _ in },
            load: { _ in nil },
            delete: { key in capturedKey.withLock { $0 = key } }
        )

        try service.deleteAccessToken()

        #expect(capturedKey.withLock { $0 } == KeychainService.accessTokenKey)
    }

    // MARK: - KeychainError

    /// 驗證 KeychainError 的錯誤描述包含狀態碼
    @Test
    func keychainError_descriptionsContainStatusCode() {
        let saveError = KeychainError.saveFailed(-25299)
        #expect(saveError.errorDescription?.contains("-25299") == true)

        let deleteError = KeychainError.deleteFailed(-25300)
        #expect(deleteError.errorDescription?.contains("-25300") == true)

        let unexpectedError = KeychainError.unexpectedError(-25301)
        #expect(unexpectedError.errorDescription?.contains("-25301") == true)
    }

    // MARK: - accessTokenKey

    /// 驗證存取權杖金鑰值為預期的字串
    @Test
    func accessTokenKey_hasExpectedValue() {
        #expect(KeychainService.accessTokenKey == "github_access_token")
    }
}
