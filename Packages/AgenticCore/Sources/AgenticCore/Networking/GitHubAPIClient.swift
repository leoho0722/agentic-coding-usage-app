import Foundation

/// A dependency-injectable GitHub API client.
///
/// Uses closure-based injection so TCA and CLI can each provide their own
/// implementations (live, mock, etc.).
public struct GitHubAPIClient: Sendable {
    /// Fetch the authenticated user's profile.
    public var fetchUser: @Sendable (_ accessToken: String) async throws -> GitHubUser
    /// Fetch Copilot status including plan and quota snapshots (internal API).
    public var fetchCopilotStatus: @Sendable (
        _ accessToken: String
    ) async throws -> CopilotStatusResponse

    public init(
        fetchUser: @escaping @Sendable (_ accessToken: String) async throws -> GitHubUser,
        fetchCopilotStatus: @escaping @Sendable (
            _ accessToken: String
        ) async throws -> CopilotStatusResponse
    ) {
        self.fetchUser = fetchUser
        self.fetchCopilotStatus = fetchCopilotStatus
    }
}

// MARK: - Live Implementation

extension GitHubAPIClient {
    /// Production implementation using `URLSession`.
    public static let live = GitHubAPIClient(
        fetchUser: { accessToken in
            let request = GitHubEndpoint.user.makeRequest(accessToken: accessToken)
            let (data, response) = try await URLSession.shared.data(for: request)
            try validateHTTPResponse(response, data: data)
            return try JSONDecoder().decode(GitHubUser.self, from: data)
        },
        fetchCopilotStatus: { accessToken in
            let request = GitHubEndpoint.copilotStatus.makeRequest(accessToken: accessToken)
            let (data, response) = try await URLSession.shared.data(for: request)
            try validateHTTPResponse(response, data: data)
            do {
                return try JSONDecoder().decode(CopilotStatusResponse.self, from: data)
            } catch let decodingError {
                let rawJSON = String(data: data, encoding: .utf8) ?? "<non-UTF8 data>"
                throw GitHubAPIError.decodingFailed(
                    underlyingError: decodingError,
                    rawResponse: rawJSON
                )
            }
        }
    )
}

// MARK: - Helpers

public enum GitHubAPIError: LocalizedError, Sendable {
    case httpError(statusCode: Int, message: String)
    case invalidResponse
    case decodingFailed(underlyingError: any Error, rawResponse: String)

    public var errorDescription: String? {
        switch self {
        case let .httpError(statusCode, message):
            "GitHub API error (\(statusCode)): \(message)"
        case .invalidResponse:
            "Invalid response from GitHub API"
        case let .decodingFailed(underlyingError, rawResponse):
            "Failed to decode API response: \(underlyingError.localizedDescription)\nRaw response: \(rawResponse.prefix(500))"
        }
    }
}

private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
    guard let httpResponse = response as? HTTPURLResponse else {
        throw GitHubAPIError.invalidResponse
    }
    guard (200 ... 299).contains(httpResponse.statusCode) else {
        let message = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw GitHubAPIError.httpError(statusCode: httpResponse.statusCode, message: message)
    }
}
