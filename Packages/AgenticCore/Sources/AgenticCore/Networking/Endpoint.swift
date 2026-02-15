import Foundation

/// GitHub API endpoints used by AgenticUsage.
public enum GitHubEndpoint: Sendable {
    /// `GET /user` — authenticated user profile.
    case user
    /// `GET /copilot_internal/user` — internal Copilot status (plan, quota snapshots).
    case copilotStatus

    // MARK: - OAuth Device Flow

    /// `POST https://github.com/login/device/code`
    case deviceCode(clientID: String)
    /// `POST https://github.com/login/oauth/access_token`
    case pollAccessToken(clientID: String, deviceCode: String)

    /// The full URL for this endpoint.
    public var url: URL {
        switch self {
        case .user:
            return URL(string: "https://api.github.com/user")!

        case .copilotStatus:
            return URL(string: "https://api.github.com/copilot_internal/user")!

        case .deviceCode:
            return URL(string: "https://github.com/login/device/code")!

        case .pollAccessToken:
            return URL(string: "https://github.com/login/oauth/access_token")!
        }
    }

    /// Build a `URLRequest` for this endpoint.
    public func makeRequest(accessToken: String? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        switch self {
        case .user:
            request.httpMethod = "GET"
            if let accessToken {
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            }
            request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        case .copilotStatus:
            request.httpMethod = "GET"
            if let accessToken {
                request.setValue("token \(accessToken)", forHTTPHeaderField: "Authorization")
            }
            // The internal Copilot API requires editor-style headers.
            request.setValue("vscode/1.96.2", forHTTPHeaderField: "Editor-Version")
            request.setValue("copilot-chat/0.26.7", forHTTPHeaderField: "Editor-Plugin-Version")
            request.setValue("GitHubCopilotChat/0.26.7", forHTTPHeaderField: "User-Agent")
            request.setValue("2025-04-01", forHTTPHeaderField: "X-Github-Api-Version")

        case let .deviceCode(clientID):
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body = ["client_id": clientID, "scope": "user"]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        case let .pollAccessToken(clientID, deviceCode):
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: String] = [
                "client_id": clientID,
                "device_code": deviceCode,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        return request
    }
}
