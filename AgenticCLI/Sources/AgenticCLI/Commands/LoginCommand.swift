import Foundation
import AgenticCore
import ArgumentParser

// MARK: - LoginCommand

/// 透過 GitHub OAuth Device Flow 進行身份驗證的 CLI 子指令。
///
/// 使用者可透過 `--client-id` 參數或 `AGENTIC_GITHUB_CLIENT_ID` 環境變數提供 OAuth App 的 Client ID，
/// 完成授權後會將存取權杖儲存至鑰匙圈。
struct LoginCommand: AsyncParsableCommand {

    /// CLI 指令的組態設定。
    static let configuration = CommandConfiguration(
        commandName: "login",
        abstract: "Authenticate with GitHub using the OAuth Device Flow.",
    )

    /// GitHub OAuth App 的 Client ID，可透過命令列參數或環境變數提供。
    @Option(name: .long, help: "Your GitHub OAuth App client ID.")
    var clientID: String?

    /// 執行登入流程。
    ///
    /// 流程步驟：
    /// 1. 取得 Client ID（優先使用命令列參數，其次使用環境變數）
    /// 2. 向 GitHub 請求裝置碼
    /// 3. 輪詢等待使用者完成瀏覽器端授權
    /// 4. 取得使用者資訊以確認登入成功
    /// 5. 將存取權杖儲存至鑰匙圈
    ///
    /// - Throws: 當 Client ID 未提供或 OAuth 流程失敗時拋出錯誤。
    func run() async throws {
        // 優先使用命令列參數，其次環境變數，最後使用預設值
        let clientID = self.clientID
            ?? ProcessInfo.processInfo.environment["AGENTIC_GITHUB_CLIENT_ID"]
            ?? GitHubConstants.defaultClientID

        let oAuth = OAuthService.live
        let keychain = KeychainService.live

        // 1. 向 GitHub 請求裝置碼
        print("Requesting device code from GitHub...")
        let deviceCode = try await oAuth.requestDeviceCode(clientID)

        print()
        print("  Open:  \(deviceCode.verificationUri)")
        print("  Code:  \(deviceCode.userCode)")
        print()
        print("Waiting for authorization (expires in \(deviceCode.expiresIn / 60) minutes)...")

        // 2. 輪詢等待使用者在瀏覽器端完成授權
        let token = try await oAuth.pollForAccessToken(
            clientID,
            deviceCode.deviceCode,
            deviceCode.interval,
        )

        // 3. 取得使用者資訊以確認登入身份
        let apiClient = GitHubAPIClient.live
        let user = try await apiClient.fetchUser(token.accessToken)

        // 4. 將存取權杖儲存至鑰匙圈
        try keychain.saveAccessToken(token.accessToken)

        print()
        print("Logged in as \(user.name ?? user.login) (@\(user.login))")
        print("Access token saved to Keychain.")
    }
}
