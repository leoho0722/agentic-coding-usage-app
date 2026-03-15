import SwiftUI
import ComposableArchitecture

// MARK: - ClaudeToolCardView

/// Claude Code 工具卡片，包含可點擊的標題列與可展開的內容區域。
///
/// 依據連線狀態（未偵測/已連線）使用共用的 `NotDetectedContentView` 或 `ConnectedContentView`。
struct ClaudeToolCardView: View {

    /// MenuBarFeature 的 TCA Store
    let store: StoreOf<MenuBarFeature>

    var body: some View {
        let tool = ToolKind.claudeCode
        let isExpanded = store.expandedTool == tool

        VStack(alignment: .leading, spacing: 0) {
            // 標題列按鈕：點擊切換展開/收合
            Button {
                store.send(.toggleToolExpansion(tool))
            } label: {
                ToolCardHeaderView(tool: tool, isExpanded: isExpanded) {
                    ClaudeStatusLabelView(store: store)
                }
            }
            .buttonStyle(.plain)

            // 展開的內容區域，依連線狀態顯示不同視圖
            if isExpanded {
                Divider()
                    .padding(.horizontal, 12)

                switch store.claude.connectionState {
                case .notDetected:
                    NotDetectedContentView(
                        promptMessage: "Please sign in to Claude Code via terminal first.",
                        isLoading: store.claude.isLoading,
                        errorMessage: store.claude.errorMessage,
                        onRedetect: { store.send(.claude(.detectCredentials)) },
                        onDismissError: { store.send(.claude(.dismissError)) }
                    )

                case .connected:
                    ConnectedContentView(
                        isLoading: store.claude.isLoading,
                        errorMessage: store.claude.errorMessage,
                        onRefresh: { store.send(.claude(.fetchUsage)) },
                        onDismissError: { store.send(.claude(.dismissError)) }
                    ) {
                        if let summary = store.claude.usageSummary {
                            ClaudeUsageSummaryView(summary: summary)
                        }
                    }
                }
            }
        }
    }
}
