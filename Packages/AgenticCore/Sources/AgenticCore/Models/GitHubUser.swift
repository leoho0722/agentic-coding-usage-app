/// A GitHub user profile returned by `GET /user`.
public struct GitHubUser: Codable, Equatable, Sendable {
    public let login: String
    public let name: String?

    public init(login: String, name: String? = nil) {
        self.login = login
        self.name = name
    }
}
