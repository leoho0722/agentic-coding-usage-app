import Foundation
import Testing

@testable import AgenticUpdater

@Suite("GitHubRelease")
struct GitHubReleaseTests {

    /// 驗證使用 snake_case JSON 鍵能正確解碼所有欄位與 assets
    @Test
    func decoding_withSnakeCase() throws {
        let json = """
            {
                "tag_name": "v1.8.0",
                "name": "Release 1.8.0",
                "body": "## Changes\\n- Bug fixes",
                "html_url": "https://github.com/owner/repo/releases/tag/v1.8.0",
                "assets": [
                    {
                        "name": "AgenticCLI-arm64.zip",
                        "browser_download_url": "https://github.com/owner/repo/releases/download/v1.8.0/AgenticCLI-arm64.zip",
                        "size": 1048576
                    }
                ]
            }
            """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let release = try decoder.decode(GitHubRelease.self, from: data)

        #expect(release.tagName == "v1.8.0")
        #expect(release.name == "Release 1.8.0")
        #expect(release.body?.contains("Bug fixes") == true)
        #expect(release.htmlUrl == "https://github.com/owner/repo/releases/tag/v1.8.0")
        #expect(release.assets.count == 1)
        #expect(release.assets.first?.name == "AgenticCLI-arm64.zip")
        #expect(release.assets.first?.size == 1048576)
    }

    /// 驗證可選欄位為 null 時能正確解碼為 nil
    @Test
    func decoding_nullOptionalFields() throws {
        let json = """
            {
                "tag_name": "v1.0.0",
                "name": null,
                "body": null,
                "html_url": "https://github.com/owner/repo/releases/tag/v1.0.0",
                "assets": []
            }
            """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let release = try decoder.decode(GitHubRelease.self, from: data)

        #expect(release.tagName == "v1.0.0")
        #expect(release.name == nil)
        #expect(release.body == nil)
        #expect(release.assets.isEmpty)
    }

    /// 驗證包含多個 assets 時能正確解碼數量
    @Test
    func decoding_multipleAssets() throws {
        let json = """
            {
                "tag_name": "v2.0.0",
                "html_url": "https://github.com/test",
                "assets": [
                    {"name": "cli-arm64.zip", "browser_download_url": "https://dl/1", "size": 100},
                    {"name": "cli-x86.zip", "browser_download_url": "https://dl/2", "size": 200}
                ]
            }
            """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let release = try decoder.decode(GitHubRelease.self, from: data)
        #expect(release.assets.count == 2)
    }
}
