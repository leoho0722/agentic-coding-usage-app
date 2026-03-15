import SwiftUI

// MARK: - ToolCardHeaderView

/// 泛型工具卡片標題列，包含圖示、名稱、狀態標籤 slot 與展開箭頭。
///
/// 使用 `@ViewBuilder var` 儲存已建構的視圖結果，避免逃逸閉包效能問題。
struct ToolCardHeaderView<StatusLabel: View>: View {

    /// 工具類型
    let tool: ToolKind

    /// 是否處於展開狀態
    let isExpanded: Bool

    /// 狀態標籤內容，由呼叫端透過 trailing closure 提供
    @ViewBuilder var statusLabel: StatusLabel

    var body: some View {
        HStack(spacing: 8) {
            ToolIconView(tool: tool)

            Text(tool.displayName)
                .font(.subheadline)
                .fontWeight(.medium)

            statusLabel

            Spacer()

            // 展開/收合指示箭頭
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .animation(.easeInOut(duration: 0.15), value: isExpanded)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
