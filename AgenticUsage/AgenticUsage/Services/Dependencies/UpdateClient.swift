import Foundation

import AgenticUpdater
import Dependencies

// MARK: - UpdateClient

/// 自動更新功能的 TCA 相依性封裝，提供檢查更新與執行更新的能力。
struct UpdateClient: Sendable {

    /// 檢查是否有新版本可用。
    /// - Parameter currentVersion: 目前安裝的版本字串
    /// - Returns: 若有新版本，回傳 `UpdateInfo`；否則回傳 `nil`
    var checkForUpdate: @Sendable (_ currentVersion: String) async throws -> UpdateInfo?

    /// 執行完整的更新流程：下載、安裝、準備重啟。
    /// - Parameters:
    ///   - updateInfo: 更新資訊，包含最新版本與 Release 資產
    ///   - currentAppPath: 目前 App 的檔案路徑
    var performUpdate: @Sendable (_ updateInfo: UpdateInfo, _ currentAppPath: String) async throws -> Void

    /// 重新啟動 App。
    /// - Parameter appPath: App bundle 的路徑
    var relaunchApp: @Sendable (_ appPath: String) throws -> Void
}

// MARK: - DependencyKey

extension UpdateClient: DependencyKey {

    /// 正式環境實作，使用 `UpdateService` 進行實際的 GitHub Release 檢查與更新。
    static let liveValue = UpdateClient(
        checkForUpdate: { currentVersion in
            let service = UpdateService()
            return try await service.checkForUpdate(currentVersion: currentVersion)
        },
        performUpdate: { updateInfo, currentAppPath in
            let service = UpdateService()
            let assetName = "AgenticUsage-v\(updateInfo.latestVersion).zip"
            guard let asset = updateInfo.release.assets.first(where: { $0.name == assetName }) else {
                throw UpdateError.assetNotFound(assetName)
            }
            let extractedDir = try await service.downloadAndExtract(asset: asset)
            try service.installApp(
                from: extractedDir,
                appName: "AgenticUsage.app",
                to: URL(fileURLWithPath: currentAppPath)
            )
        },
        relaunchApp: { appPath in
            let service = UpdateService()
            try service.relaunchApp(at: URL(fileURLWithPath: appPath))
        }
    )
}

// MARK: - TestDependencyKey

extension UpdateClient: TestDependencyKey {

    /// 測試用的模擬實作，不進行任何實際操作。
    static let testValue = UpdateClient(
        checkForUpdate: { _ in nil },
        performUpdate: { _, _ in },
        relaunchApp: { _ in }
    )
}

extension DependencyValues {

    /// 自動更新客戶端相依性
    var updateClient: UpdateClient {
        get { self[UpdateClient.self] }
        set { self[UpdateClient.self] = newValue }
    }
}
