import SwiftUI
import ComposableArchitecture

// MARK: - AntigravityToolCardView

/// Antigravity 工具卡片，包含可點擊的標題列與可展開的內容區域。
///
/// 依據連線狀態（未偵測/已連線）使用共用的 `NotDetectedContentView` 或 `ConnectedContentView`。
struct AntigravityToolCardView: View {

    /// MenuBarFeature 的 TCA Store
    let store: StoreOf<MenuBarFeature>

    var body: some View {
        let tool = ToolKind.antigravity
        let isExpanded = store.expandedTool == tool

        VStack(alignment: .leading, spacing: 0) {
            // 標題列按鈕：點擊切換展開/收合
            Button {
                store.send(.toggleToolExpansion(tool))
            } label: {
                ToolCardHeaderView(tool: tool, isExpanded: isExpanded) {
                    AntigravityStatusLabelView(store: store)
                }
            }
            .buttonStyle(.plain)

            // 展開的內容區域，依連線狀態顯示不同視圖
            if isExpanded {
                Divider()
                    .padding(.horizontal, 12)

                switch store.antigravity.connectionState {
                case .notDetected:
                    NotDetectedContentView(
                        promptMessage: "Please sign in to Google Antigravity IDE first.",
                        isLoading: store.antigravity.isLoading,
                        errorMessage: store.antigravity.errorMessage,
                        onRedetect: { store.send(.antigravity(.detectCredentials)) },
                        onDismissError: { store.send(.antigravity(.dismissError)) }
                    )

                case .connected:
                    ConnectedContentView(
                        isLoading: store.antigravity.isLoading,
                        errorMessage: store.antigravity.errorMessage,
                        onRefresh: { store.send(.antigravity(.fetchUsage)) },
                        onDismissError: { store.send(.antigravity(.dismissError)) }
                    ) {
                        if let summary = store.antigravity.usageSummary {
                            AntigravityUsageSummaryView(summary: summary)
                        }
                    }
                }
            }
        }
    }
}
