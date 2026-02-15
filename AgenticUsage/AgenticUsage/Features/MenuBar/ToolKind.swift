/// Represents an agentic coding tool supported (or planned) by the app.
enum ToolKind: String, CaseIterable, Identifiable, Sendable, Equatable {
    case copilot
    case claudeCode
    case codex
    case antigravity

    var id: String { rawValue }

    /// Display name shown in the tool card header.
    var displayName: String {
        switch self {
        case .copilot: "GitHub Copilot"
        case .claudeCode: "Claude Code"
        case .codex: "OpenAI Codex"
        case .antigravity: "Google Antigravity"
        }
    }

    /// SF Symbol name for the tool icon.
    var iconName: String {
        switch self {
        case .copilot: "chevron.left.forwardslash.chevron.right"
        case .claudeCode: "brain.head.profile"
        case .codex: "terminal"
        case .antigravity: "atom"
        }
    }

    /// Whether this tool is currently functional (has a working integration).
    var isAvailable: Bool {
        switch self {
        case .copilot: true
        case .claudeCode, .codex, .antigravity: false
        }
    }

    /// Whether the card should show "Coming Soon" instead of being expandable.
    var isComingSoon: Bool {
        !isAvailable
    }
}
