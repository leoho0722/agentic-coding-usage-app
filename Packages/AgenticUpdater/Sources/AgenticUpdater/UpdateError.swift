import Foundation

// MARK: - UpdateError

/// 更新過程中可能發生的錯誤。
public enum UpdateError: LocalizedError {

    /// 找不到任何 Release。
    case noReleaseFound

    /// 無法解析版本字串。
    case invalidVersion(String)

    /// 找不到指定名稱的資產。
    case assetNotFound(String)

    /// 下載失敗。
    case downloadFailed(underlying: Error)

    /// 解壓縮失敗。
    case extractionFailed(underlying: Error)

    /// 安裝失敗。
    case installationFailed(underlying: Error)

    /// 重新啟動失敗。
    case relaunchFailed

    public var errorDescription: String? {
        switch self {
        case .noReleaseFound:
            return "No release found on GitHub."
        case .invalidVersion(let version):
            return "Invalid version string: \(version)"
        case .assetNotFound(let name):
            return "Asset not found: \(name)"
        case .downloadFailed(let error):
            return "Download failed: \(error.localizedDescription)"
        case .extractionFailed(let error):
            return "Extraction failed: \(error.localizedDescription)"
        case .installationFailed(let error):
            return "Installation failed: \(error.localizedDescription)"
        case .relaunchFailed:
            return "Failed to relaunch the application."
        }
    }
}
