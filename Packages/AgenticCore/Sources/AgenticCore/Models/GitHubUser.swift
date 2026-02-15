import Foundation

/// A GitHub user profile returned by `GET /user`.
public struct GitHubUser: Codable, Equatable, Sendable {
    public let login: String
    public let id: Int
    public let avatarUrl: String?
    public let name: String?

    enum CodingKeys: String, CodingKey {
        case login
        case id
        case avatarUrl = "avatar_url"
        case name
    }

    public init(login: String, id: Int, avatarUrl: String? = nil, name: String? = nil) {
        self.login = login
        self.id = id
        self.avatarUrl = avatarUrl
        self.name = name
    }
}
