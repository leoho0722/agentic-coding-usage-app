import Foundation

// MARK: - UpdateInfo

/// 更新資訊封裝，包含當前版本、最新版本以及 Release 詳情。
public struct UpdateInfo: Equatable, Sendable {

    /// 目前安裝的版本。
    public let currentVersion: SemanticVersion

    /// GitHub 上的最新版本。
    public let latestVersion: SemanticVersion

    /// 完整的 GitHub Release 資訊。
    public let release: GitHubRelease

    public init(currentVersion: SemanticVersion, latestVersion: SemanticVersion, release: GitHubRelease) {
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.release = release
    }

    /// 是否有新版本可用。
    public var isUpdateAvailable: Bool {
        latestVersion > currentVersion
    }

    /// Release notes（Markdown 格式）。
    public var releaseNotes: String? {
        release.body
    }

    /// Release 在瀏覽器中的 URL。
    public var releaseURL: URL? {
        URL(string: release.htmlUrl)
    }
}
