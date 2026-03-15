import SwiftUI

// MARK: - PlanBadgeView

/// 方案膠囊徽章，統一 Copilot/Claude/Codex/Antigravity 四組 planBadge 的共用元件。
///
/// 接收文字與顏色，以白色文字搭配彩色膠囊背景呈現。
struct PlanBadgeView: View {

    /// 徽章文字（例如 "Pro"、"Max"、"Free"）
    let label: String

    /// 徽章背景顏色，由各工具的 StatusLabel 決定
    let color: Color

    var body: some View {
        Text(label)
            .font(.system(.caption2, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(color, in: Capsule())
    }
}
