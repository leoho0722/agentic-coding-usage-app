import SwiftUI
import ComposableArchitecture

// MARK: - CopilotToolCardView

/// Copilot 工具卡片，包含可點擊的標題列與可展開的內容區域。
///
/// Copilot 是唯一擁有三態認證流程（未登入、認證中、已登入）的工具，
/// 展開內容依認證狀態切換不同的子視圖。
struct CopilotToolCardView: View {

    /// MenuBarFeature 的 TCA Store
    let store: StoreOf<MenuBarFeature>

    var body: some View {
        let tool = ToolKind.copilot
        let isExpanded = store.expandedTool == tool

        VStack(alignment: .leading, spacing: 0) {
            // 標題列按鈕：點擊切換展開/收合
            Button {
                store.send(.toggleToolExpansion(tool))
            } label: {
                ToolCardHeaderView(tool: tool, isExpanded: isExpanded) {
                    CopilotStatusLabelView(store: store)
                }
            }
            .buttonStyle(.plain)

            // 展開的內容區域，依認證狀態顯示不同視圖
            if isExpanded {
                Divider()
                    .padding(.horizontal, 12)

                switch store.copilot.authState {
                case .loggedOut:
                    CopilotLoggedOutContentView(store: store)

                case .authenticating:
                    CopilotAuthenticatingContentView(store: store)

                case .loggedIn:
                    CopilotLoggedInContentView(store: store)
                }
            }
        }
    }
}
