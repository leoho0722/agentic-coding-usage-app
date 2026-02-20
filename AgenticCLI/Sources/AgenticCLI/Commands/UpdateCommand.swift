import Foundation
import AgenticUpdater
import ArgumentParser

// MARK: - UpdateCommand

/// 檢查更新並自動更新 CLI 的子指令。
///
/// 預設行為為檢查並安裝更新，使用 `--check` 旗標可僅檢查而不安裝。
struct UpdateCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "update",
        abstract: "Check for updates and self-update the CLI."
    )

    @Flag(name: .long, help: "Only check for updates without installing.")
    var check: Bool = false

    func run() async throws {
        let currentVersion = AgenticCLI.configuration.version
        let service = UpdateService()

        print("Checking for updates...")

        let updateInfo: UpdateInfo?
        do {
            updateInfo = try await service.checkForUpdate(currentVersion: currentVersion)
        } catch {
            print("Failed to check for updates: \(error.localizedDescription)")
            throw ExitCode.failure
        }

        guard let info = updateInfo else {
            print("Already up to date (v\(currentVersion))")
            return
        }

        print("New version available: v\(info.latestVersion) (current: v\(info.currentVersion))")

        if let notes = info.releaseNotes, !notes.isEmpty {
            print()
            print("Release notes:")
            print(notes)
            print()
        }

        // 僅檢查模式
        if check {
            if let url = info.releaseURL {
                print("Download: \(url)")
            }
            return
        }

        // 尋找 CLI asset
        let assetName = "AgenticCLI-v\(info.latestVersion)-arm64.zip"
        guard let asset = info.release.assets.first(where: { $0.name == assetName }) else {
            print("Error: Asset '\(assetName)' not found in release.")
            throw ExitCode.failure
        }

        print("Downloading \(assetName) (\(formatBytes(asset.size)))...")

        let extractedDir: URL
        do {
            extractedDir = try await service.downloadAndExtract(asset: asset)
        } catch {
            print("Download failed: \(error.localizedDescription)")
            throw ExitCode.failure
        }

        // 取得目前 binary 的路徑
        let currentBinaryPath = URL(
            fileURLWithPath: ProcessInfo.processInfo.arguments[0]
        ).resolvingSymlinksInPath()

        print("Installing to \(currentBinaryPath.path)...")

        do {
            try service.installCLI(
                from: extractedDir,
                binaryName: "agentic",
                to: currentBinaryPath
            )
        } catch {
            print("Installation failed: \(error.localizedDescription)")
            throw ExitCode.failure
        }

        print("Successfully updated to v\(info.latestVersion)!")
    }

    /// 將位元組數格式化為人類可讀的字串（KB 或 MB）。
    ///
    /// - Parameter bytes: 檔案大小（位元組）。
    /// - Returns: 格式化後的字串，例如 "1.5 MB" 或 "512 KB"。
    private func formatBytes(_ bytes: Int) -> String {
        let mb = Double(bytes) / 1_048_576.0
        if mb >= 1.0 {
            return String(format: "%.1f MB", mb)
        }
        let kb = Double(bytes) / 1024.0
        return String(format: "%.0f KB", kb)
    }
}
