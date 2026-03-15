import SwiftUI
import AgenticCore
import ComposableArchitecture

// MARK: - CopilotStatusLabelView

/// Copilot 卡片收合時的狀態標籤，顯示使用者名稱 + 方案徽章，或連線狀態。
///
/// 三種認證狀態分別顯示：
/// - `.loggedOut`：「Not Connected」
/// - `.authenticating`：「Connecting...」
/// - `.loggedIn`：「@username」+ 方案徽章
struct CopilotStatusLabelView: View {

    /// MenuBarFeature 的 TCA Store
    let store: StoreOf<MenuBarFeature>

    var body: some View {
        switch store.copilot.authState {
        case .loggedOut:
            ToolStatusTextView(text: "Not Connected")

        case .authenticating:
            ToolStatusTextView(text: "Connecting...")

        case let .loggedIn(user, _):
            Group {
                Text("|")
                    .foregroundStyle(.quaternary)
                Text("@\(user.login)")
                    .foregroundStyle(.secondary)
                // 偵測到方案時顯示對應的膠囊徽章
                if let plan = store.copilot.detectedPlan {
                    PlanBadgeView(label: plan.badgeLabel, color: Self.badgeColor(for: plan))
                }
            }
            .font(.caption)
        }
    }

    /// 取得 Copilot 方案對應的徽章顏色。
    /// - Parameter plan: Copilot 方案類型
    /// - Returns: 對應的顏色
    static func badgeColor(for plan: CopilotPlan) -> Color {
        switch plan {
        case .free: .gray
        case .pro: .blue
        case .proPlus: .purple
        }
    }
}
