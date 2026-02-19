import Foundation

// MARK: - UpdateService

/// 核心更新服務，負責檢查更新、下載、安裝與重啟。
///
/// 透過 GitHub Releases API 取得最新版本資訊，
/// 並提供 CLI 與 App 兩種安裝模式。
public struct UpdateService: Sendable {

    /// GitHub repository owner。
    public let owner: String

    /// GitHub repository name。
    public let repo: String

    public init(owner: String = "leoho0722", repo: String = "agentic-coding-usage-app") {
        self.owner = owner
        self.repo = repo
    }

    // MARK: - Check for Update

    /// 檢查是否有新版本可用。
    ///
    /// - Parameter currentVersion: 目前版本字串，例如 "1.7.2" 或 "v1.7.2"。
    /// - Returns: 若有新版本，回傳 `UpdateInfo`；否則回傳 `nil`。
    public func checkForUpdate(currentVersion: String) async throws -> UpdateInfo? {
        guard let current = SemanticVersion(currentVersion) else {
            throw UpdateError.invalidVersion(currentVersion)
        }

        let release = try await fetchLatestRelease()

        guard let latest = SemanticVersion(release.tagName) else {
            throw UpdateError.invalidVersion(release.tagName)
        }

        let info = UpdateInfo(currentVersion: current, latestVersion: latest, release: release)
        return info.isUpdateAvailable ? info : nil
    }

    // MARK: - Download and Extract

    /// 下載指定資產並解壓縮到暫存目錄。
    ///
    /// - Parameter asset: 要下載的 GitHub Release 資產。
    /// - Returns: 解壓縮後的目錄路徑。
    public func downloadAndExtract(asset: GitHubReleaseAsset) async throws -> URL {
        guard let url = URL(string: asset.browserDownloadUrl) else {
            throw UpdateError.assetNotFound(asset.name)
        }

        // 下載到暫存檔
        let downloadedURL: URL
        do {
            let downloadRequest = URLRequest(url: url)
            let (tempURL, _) = try await URLSession.shared.download(for: downloadRequest)
            downloadedURL = tempURL
        } catch {
            throw UpdateError.downloadFailed(underlying: error)
        }

        // 建立解壓目標目錄
        let extractDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgenticUpdate-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

        // 使用 ditto 解壓縮（macOS 原生，支援 .app bundle）
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-xk", downloadedURL.path, extractDir.path]
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                throw NSError(
                    domain: "UpdateService",
                    code: Int(process.terminationStatus),
                    userInfo: [NSLocalizedDescriptionKey: "ditto exited with status \(process.terminationStatus)"]
                )
            }
        } catch let error as UpdateError {
            throw error
        } catch {
            throw UpdateError.extractionFailed(underlying: error)
        }

        // 清理下載的 zip
        try? FileManager.default.removeItem(at: downloadedURL)

        return extractDir
    }

    // MARK: - Install CLI

    /// 安裝 CLI binary，替換目標路徑的執行檔。
    ///
    /// - Parameters:
    ///   - extractedDir: 解壓縮後的目錄。
    ///   - binaryName: binary 檔名，例如 "AgenticCLI"。
    ///   - targetPath: 目標安裝路徑。
    public func installCLI(from extractedDir: URL, binaryName: String, to targetPath: URL) throws {
        let sourceBinary = extractedDir.appendingPathComponent(binaryName)

        guard FileManager.default.fileExists(atPath: sourceBinary.path) else {
            throw UpdateError.assetNotFound(binaryName)
        }

        let backupPath = targetPath.appendingPathExtension("backup")

        do {
            // 備份舊 binary
            if FileManager.default.fileExists(atPath: targetPath.path) {
                if FileManager.default.fileExists(atPath: backupPath.path) {
                    try FileManager.default.removeItem(at: backupPath)
                }
                try FileManager.default.moveItem(at: targetPath, to: backupPath)
            }

            // 移動新 binary 到目標路徑
            try FileManager.default.moveItem(at: sourceBinary, to: targetPath)

            // 設定 executable 權限
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: targetPath.path
            )

            // 刪除備份
            try? FileManager.default.removeItem(at: backupPath)
        } catch let error as UpdateError {
            throw error
        } catch {
            // 嘗試還原備份
            if FileManager.default.fileExists(atPath: backupPath.path),
               !FileManager.default.fileExists(atPath: targetPath.path) {
                try? FileManager.default.moveItem(at: backupPath, to: targetPath)
            }
            throw UpdateError.installationFailed(underlying: error)
        }

        // 清理解壓目錄
        try? FileManager.default.removeItem(at: extractedDir)
    }

    // MARK: - Install App

    /// 安裝 App bundle，替換目標路徑的 .app。
    ///
    /// - Parameters:
    ///   - extractedDir: 解壓縮後的目錄。
    ///   - appName: App bundle 名稱，例如 "AgenticUsage.app"。
    ///   - currentAppPath: 目前 App 的路徑。
    public func installApp(from extractedDir: URL, appName: String, to currentAppPath: URL) throws {
        let sourceApp = extractedDir.appendingPathComponent(appName)

        guard FileManager.default.fileExists(atPath: sourceApp.path) else {
            throw UpdateError.assetNotFound(appName)
        }

        do {
            // 將舊 .app 移至垃圾桶
            if FileManager.default.fileExists(atPath: currentAppPath.path) {
                var trashedURL: NSURL?
                try FileManager.default.trashItem(at: currentAppPath, resultingItemURL: &trashedURL)
            }

            // 將新 .app 移至原路徑
            try FileManager.default.moveItem(at: sourceApp, to: currentAppPath)
        } catch let error as UpdateError {
            throw error
        } catch {
            throw UpdateError.installationFailed(underlying: error)
        }

        // 清理解壓目錄
        try? FileManager.default.removeItem(at: extractedDir)
    }

    // MARK: - Relaunch App

    /// 重新啟動 App。
    ///
    /// - Parameter appPath: App bundle 的路徑。
    public func relaunchApp(at appPath: URL) throws {
        do {
            // 使用 shell 延遲啟動：等待舊 process 退出後再開啟新 App
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", "sleep 1 && open \"\(appPath.path)\""]
            try process.run()
        } catch {
            throw UpdateError.relaunchFailed
        }
    }

    // MARK: - Private

    private func fetchLatestRelease() async throws -> GitHubRelease {
        let urlString = "https://api.github.com/repos/\(owner)/\(repo)/releases/latest"
        guard let url = URL(string: urlString) else {
            throw UpdateError.noReleaseFound
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw UpdateError.noReleaseFound
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(GitHubRelease.self, from: data)
    }
}
