import SwiftUI
import ComposableArchitecture

// MARK: - CodexToolCardView

/// Codex 工具卡片，包含可點擊的標題列與可展開的內容區域。
///
/// 依據連線狀態（未偵測/已連線）使用共用的 `NotDetectedContentView` 或 `ConnectedContentView`。
struct CodexToolCardView: View {

    /// MenuBarFeature 的 TCA Store
    let store: StoreOf<MenuBarFeature>

    var body: some View {
        let tool = ToolKind.codex
        let isExpanded = store.expandedTool == tool

        VStack(alignment: .leading, spacing: 0) {
            // 標題列按鈕：點擊切換展開/收合
            Button {
                store.send(.toggleToolExpansion(tool))
            } label: {
                ToolCardHeaderView(tool: tool, isExpanded: isExpanded) {
                    CodexStatusLabelView(store: store)
                }
            }
            .buttonStyle(.plain)

            // 展開的內容區域，依連線狀態顯示不同視圖
            if isExpanded {
                Divider()
                    .padding(.horizontal, 12)

                switch store.codex.connectionState {
                case .notDetected:
                    NotDetectedContentView(
                        promptMessage: "Please sign in to Codex via terminal first.",
                        isLoading: store.codex.isLoading,
                        errorMessage: store.codex.errorMessage,
                        onRedetect: { store.send(.codex(.detectCredentials)) },
                        onDismissError: { store.send(.codex(.dismissError)) }
                    )

                case .connected:
                    ConnectedContentView(
                        isLoading: store.codex.isLoading,
                        errorMessage: store.codex.errorMessage,
                        onRefresh: { store.send(.codex(.fetchUsage)) },
                        onDismissError: { store.send(.codex(.dismissError)) }
                    ) {
                        if let summary = store.codex.usageSummary {
                            CodexUsageSummaryView(summary: summary)
                        }
                    }
                }
            }
        }
    }
}
