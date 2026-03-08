import Foundation
import Testing

@testable import AgenticUpdater

@Suite("UpdateInfo")
struct UpdateInfoTests {

    /// 驗證最新版本較新時 isUpdateAvailable 回傳 true
    @Test
    func isUpdateAvailable_newerVersion_true() {
        let info = UpdateInfo(
            currentVersion: SemanticVersion("1.0.0")!,
            latestVersion: SemanticVersion("1.1.0")!,
            release: makeRelease()
        )
        #expect(info.isUpdateAvailable == true)
    }

    /// 驗證版本相同時 isUpdateAvailable 回傳 false
    @Test
    func isUpdateAvailable_sameVersion_false() {
        let info = UpdateInfo(
            currentVersion: SemanticVersion("1.0.0")!,
            latestVersion: SemanticVersion("1.0.0")!,
            release: makeRelease()
        )
        #expect(info.isUpdateAvailable == false)
    }

    /// 驗證目前版本較新時 isUpdateAvailable 回傳 false
    @Test
    func isUpdateAvailable_olderVersion_false() {
        let info = UpdateInfo(
            currentVersion: SemanticVersion("2.0.0")!,
            latestVersion: SemanticVersion("1.0.0")!,
            release: makeRelease()
        )
        #expect(info.isUpdateAvailable == false)
    }

    /// 驗證 releaseNotes 正確回傳 release body 內容
    @Test
    func releaseNotes_returnsBody() {
        let info = UpdateInfo(
            currentVersion: SemanticVersion("1.0.0")!,
            latestVersion: SemanticVersion("1.1.0")!,
            release: makeRelease(body: "Bug fixes and improvements")
        )
        #expect(info.releaseNotes == "Bug fixes and improvements")
    }

    /// 驗證 releaseURL 能正確轉換為有效的 URL
    @Test
    func releaseURL_validURL() {
        let info = UpdateInfo(
            currentVersion: SemanticVersion("1.0.0")!,
            latestVersion: SemanticVersion("1.1.0")!,
            release: makeRelease(htmlUrl: "https://github.com/owner/repo/releases/tag/v1.1.0")
        )
        #expect(info.releaseURL?.absoluteString == "https://github.com/owner/repo/releases/tag/v1.1.0")
    }
}

// MARK: - Helper Methods

private extension UpdateInfoTests {

    /// 建立測試用的 GitHubRelease 實例
    /// - Parameters:
    ///   - tagName: Git tag 名稱，預設為 `"v1.0.0"`
    ///   - body: Release 說明內容，預設為 `nil`
    ///   - htmlUrl: Release 頁面網址
    /// - Returns: 建構好的 `GitHubRelease`
    func makeRelease(
        tagName: String = "v1.0.0",
        body: String? = nil,
        htmlUrl: String = "https://github.com/test/releases/tag/v1.0.0"
    ) -> GitHubRelease {
        GitHubRelease(tagName: tagName, name: "Release", body: body, htmlUrl: htmlUrl, assets: [])
    }
}
