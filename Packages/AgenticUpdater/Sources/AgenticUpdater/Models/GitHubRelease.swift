import Foundation

// MARK: - GitHubRelease

/// GitHub Release API 回應模型。
public struct GitHubRelease: Codable, Equatable, Sendable {

    /// Release tag 名稱，例如 "v1.8.0"。
    public let tagName: String

    /// Release 標題。
    public let name: String?

    /// Release notes（Markdown 格式）。
    public let body: String?

    /// Release 在瀏覽器中的 URL。
    public let htmlUrl: String

    /// Release 附帶的資產列表。
    public let assets: [GitHubReleaseAsset]
}

// MARK: - GitHubReleaseAsset

/// GitHub Release 中的單一資產。
public struct GitHubReleaseAsset: Codable, Equatable, Sendable {

    /// 資產檔名，例如 "AgenticCLI-arm64.zip"。
    public let name: String

    /// 資產的下載 URL。
    public let browserDownloadUrl: String

    /// 資產大小（bytes）。
    public let size: Int
}
