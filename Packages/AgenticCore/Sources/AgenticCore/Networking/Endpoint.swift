import Foundation

/// GitHub API endpoints used by AgenticUsage.
public enum GitHubEndpoint: Sendable {
    /// `GET /user` — authenticated user profile.
    case user
    /// `GET /users/{username}/settings/billing/premium_request/usage?year=&month=`
    case premiumRequestUsage(username: String, year: Int, month: Int)

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

        case let .premiumRequestUsage(username, year, month):
            var components = URLComponents(
                string: "https://api.github.com/users/\(username)/settings/billing/premium_request/usage"
            )!
            components.queryItems = [
                URLQueryItem(name: "year", value: "\(year)"),
                URLQueryItem(name: "month", value: "\(month)"),
            ]
            return components.url!

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
        case .user, .premiumRequestUsage:
            request.httpMethod = "GET"
            if let accessToken {
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            }
            request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

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
