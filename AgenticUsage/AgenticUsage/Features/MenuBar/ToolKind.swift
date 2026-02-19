import SwiftUI

// MARK: - ToolKind

/// 應用程式支援（或計劃支援）的 AI 編碼工具列舉。
enum ToolKind: String, CaseIterable, Identifiable, Equatable, Sendable {
    
    /// GitHub Copilot
    case copilot
    
    /// Claude Code
    case claudeCode
    
    /// OpenAI Codex
    case codex
    
    /// Google Antigravity
    case antigravity

    /// 唯一識別碼，使用 rawValue
    var id: String { rawValue }

    /// 顯示在工具卡片標題列的名稱。
    var displayName: String {
        switch self {
        case .copilot: "GitHub Copilot"
        case .claudeCode: "Claude Code"
        case .codex: "OpenAI Codex"
        case .antigravity: "Google Antigravity"
        }
    }

    /// 取得工具圖示的 Asset Catalog 圖片名稱。
    ///
    /// Copilot 依 Light/Dark 外觀使用不同素材，其他工具則不分外觀。
    /// - Parameter colorScheme: 系統目前的外觀模式
    /// - Returns: Asset Catalog 中的圖片名稱
    func imageName(for colorScheme: ColorScheme) -> String {
        switch self {
        case .copilot: colorScheme == .dark ? "github-copilot-dark" : "github-copilot-light"
        case .claudeCode: "claude"
        case .codex: "openai-codex"
        case .antigravity: "google-antigravity"
        }
    }

    /// 工具的品牌色調（取自 Asset Catalog 的 Brand Color 集合）。
    ///
    /// 回傳 `nil` 表示圖片應以原始模式繪製，不套用著色。
    var tintColor: Color? {
        switch self {
        case .claudeCode: .claude
        case .antigravity: .antigravity
        case .copilot, .codex: nil
        }
    }

    /// 該工具是否已有可運作的整合功能。
    var isAvailable: Bool {
        switch self {
        case .copilot, .claudeCode, .codex, .antigravity: true
        }
    }

    /// 該工具卡片是否應顯示「Coming Soon」而非可展開的內容。
    var isComingSoon: Bool {
        !isAvailable
    }
}
