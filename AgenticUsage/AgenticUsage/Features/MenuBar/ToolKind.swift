import SwiftUI

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

    /// Asset catalog image name for the tool icon.
    /// Copilot uses separate light/dark assets; others are appearance-independent.
    func imageName(for colorScheme: ColorScheme) -> String {
        switch self {
        case .copilot:
            colorScheme == .dark ? "github-copilot-dark" : "github-copilot-light"
        case .claudeCode: "claude"
        case .codex: "openai-codex"
        case .antigravity: "google-antigravity"
        }
    }

    /// Optional brand tint color (from Asset catalog Brand Color set).
    /// `nil` means the image should be rendered as-is (original / template default).
    var tintColor: Color? {
        switch self {
        case .claudeCode: Color("Claude", bundle: .main)
        case .antigravity: Color("Antigravity", bundle: .main)
        case .copilot, .codex: nil
        }
    }

    /// Whether this tool is currently functional (has a working integration).
    var isAvailable: Bool {
        switch self {
        case .copilot, .claudeCode, .codex: true
        case .antigravity: false
        }
    }

    /// Whether the card should show "Coming Soon" instead of being expandable.
    var isComingSoon: Bool {
        !isAvailable
    }
}
