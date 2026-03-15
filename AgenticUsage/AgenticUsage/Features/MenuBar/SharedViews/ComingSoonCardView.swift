import SwiftUI

// MARK: - ComingSoonCardView

/// 尚未上線工具的靜態卡片，以低透明度與「Coming Soon」標示。
///
/// 不可展開，僅作為預告用途的佔位卡片。
struct ComingSoonCardView: View {

    /// 工具類型
    let tool: ToolKind

    var body: some View {
        HStack(spacing: 8) {
            // 工具圖示（降低透明度）
            ToolIconView(tool: tool)
                .opacity(0.4)

            Text(tool.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.tertiary)

            Text("|")
                .font(.caption)
                .foregroundStyle(.quaternary)

            Text("Coming Soon")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
