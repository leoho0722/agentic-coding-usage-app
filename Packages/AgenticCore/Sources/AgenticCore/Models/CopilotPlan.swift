/// Represents a GitHub Copilot subscription plan and its monthly premium request limit.
public enum CopilotPlan: String, Sendable, Equatable {
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

    /// Attempt to parse a `CopilotPlan` from the `copilot_plan` string
    /// returned by `GET /copilot_internal/user`.
    ///
    /// Known API values include:
    /// - `"copilot_for_individual_user"` → `.pro`
    /// - `"copilot_for_individual_user_pro_plus"` or values containing `"pro_plus"` → `.proPlus`
    /// - `"copilot_free"` or values containing `"free"` → `.free`
    ///
    /// Falls back to `.pro` for unrecognised strings.
    public static func fromAPIString(_ apiPlan: String?) -> CopilotPlan {
        guard let apiPlan, !apiPlan.isEmpty else { return .pro }
        let lowered = apiPlan.lowercased()

        if lowered.contains("pro_plus") || lowered.contains("proplus") {
            return .proPlus
        }
        if lowered.contains("free") {
            return .free
        }
        // "copilot_for_individual_user" and other paid plans default to Pro
        return .pro
    }

    /// A short label suitable for displaying as a badge.
    public var badgeLabel: String {
        rawValue
    }
}
