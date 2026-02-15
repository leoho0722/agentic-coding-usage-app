import Foundation

/// Represents a GitHub Copilot subscription plan and its monthly premium request limit.
public enum CopilotPlan: String, Sendable, CaseIterable, Codable {
    case free = "Free"
    case pro = "Pro"
    case proPlus = "Pro+"

    /// The monthly premium request allowance for this plan.
    public var limit: Int {
        switch self {
        case .free: 50
        case .pro: 300
        case .proPlus: 1500
        }
    }
}
