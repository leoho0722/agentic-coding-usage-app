import SwiftUI
import AgenticCore
import ComposableArchitecture

// MARK: - ClaudeStatusLabelView

/// Claude Code 卡片收合時的狀態標籤，顯示偵測狀態與訂閱方案徽章。
///
/// 兩種連線狀態分別顯示：
/// - `.notDetected`：「Not Detected」
/// - `.connected`：「Connected」+ 方案徽章（若有偵測到方案）
struct ClaudeStatusLabelView: View {

    /// MenuBarFeature 的 TCA Store
    let store: StoreOf<MenuBarFeature>

    var body: some View {
        switch store.claude.connectionState {
        case .notDetected:
            ToolStatusTextView(text: "Not Detected")

        case let .connected(plan):
            Group {
                Text("|")
                    .foregroundStyle(.quaternary)
                Text("Connected")
                    .foregroundStyle(.secondary)
                // 偵測到方案時顯示對應的膠囊徽章
                if let plan {
                    PlanBadgeView(label: plan.badgeLabel, color: Self.badgeColor(for: plan))
                }
            }
            .font(.caption)
        }
    }

    /// 取得 Claude 方案對應的徽章顏色。
    /// - Parameter plan: Claude 方案類型
    /// - Returns: 對應的顏色
    static func badgeColor(for plan: ClaudePlan) -> Color {
        switch plan {
        case .free: .gray
        case .pro: .orange
        case .max: .purple
        }
    }
}
