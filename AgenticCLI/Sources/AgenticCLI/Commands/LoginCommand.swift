import AgenticCore
import ArgumentParser
import Foundation

struct LoginCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "login",
        abstract: "Authenticate with GitHub using the OAuth Device Flow."
    )

    @Option(name: .long, help: "Your GitHub OAuth App client ID.")
    var clientID: String?

    func run() async throws {
        let clientID = self.clientID ?? ProcessInfo.processInfo.environment["AGENTIC_GITHUB_CLIENT_ID"]

        guard let clientID, !clientID.isEmpty else {
            print("Error: GitHub OAuth client ID is required.")
            print("Provide it via --client-id or set the AGENTIC_GITHUB_CLIENT_ID environment variable.")
            print("Register an OAuth App at: https://github.com/settings/developers")
            throw ExitCode.failure
        }

        let oAuth = OAuthService.live
        let keychain = KeychainService.live

        print("Requesting device code from GitHub...")
        let deviceCode = try await oAuth.requestDeviceCode(clientID)

        print()
        print("  Open:  \(deviceCode.verificationUri)")
        print("  Code:  \(deviceCode.userCode)")
        print()
        print("Waiting for authorization (expires in \(deviceCode.expiresIn / 60) minutes)...")

        let token = try await oAuth.pollForAccessToken(
            clientID,
            deviceCode.deviceCode,
            deviceCode.interval
        )

        // Fetch user info to confirm login
        let apiClient = GitHubAPIClient.live
        let user = try await apiClient.fetchUser(token.accessToken)

        // Save token to keychain
        try keychain.saveAccessToken(token.accessToken)

        print()
        print("Logged in as \(user.name ?? user.login) (@\(user.login))")
        print("Access token saved to Keychain.")
    }
}
