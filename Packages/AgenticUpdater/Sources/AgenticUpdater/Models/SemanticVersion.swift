import Foundation

// MARK: - SemanticVersion

/// 語意化版本（Semantic Versioning）比較工具。
///
/// 支援解析 "1.8.0" 或 "v1.8.0" 格式的版本字串。
public struct SemanticVersion: Comparable, Equatable, Sendable, CustomStringConvertible {

    /// 主版號，不相容的 API 變更時遞增。
    public let major: Int

    /// 次版號，向下相容的功能新增時遞增。
    public let minor: Int

    /// 修訂號，向下相容的問題修正時遞增。
    public let patch: Int

    /// 從版本字串初始化，支援 "1.8.0" 或 "v1.8.0" 格式。
    public init?(_ string: String) {
        var versionString = string
        if versionString.hasPrefix("v") || versionString.hasPrefix("V") {
            versionString = String(versionString.dropFirst())
        }

        let components = versionString.split(separator: ".")
        guard components.count >= 3,
              let major = Int(components[0]),
              let minor = Int(components[1]),
              let patch = Int(components[2]) else {
            return nil
        }

        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public var description: String {
        "\(major).\(minor).\(patch)"
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { 
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        return lhs.patch < rhs.patch
    }
}
