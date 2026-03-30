import SwiftUI
import AgenticCore
import AgenticUpdater
import ComposableArchitecture

// MARK: - MenuBarView

/// MenuBar 視窗的主要視圖，以手風琴式卡片佈局呈現各工具的用量資訊。
///
/// 由頂部標題列、更新橫幅、工具卡片捲動區域與底部動作列組成。
/// 各工具卡片已拆分為獨立的 View struct，此處僅負責組合與生命週期管理。
struct MenuBarView: View {

    /// TCA Store 的綁定參考
    @Bindable var store: StoreOf<MenuBarFeature>

    /// 自動重新整理間隔，從 UserDefaults 讀取
    @AppStorage(.refreshInterval, defaultValue: .seconds30)
    private var refreshInterval: RefreshInterval

    /// 捲動區域內容的實際高度，用於動態調整 ScrollView 框架
    @State private var scrollContentHeight: CGFloat = 0

    /// 捲動區域允許的最大高度
    private let maxScrollHeight: CGFloat = 500

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 頂部標題列：App 名稱 + 版本號
            MenuBarHeaderView()

            // 更新提示橫幅（有新版本時顯示）
            UpdateBannerView(
                updateInfo: store.updateInfo,
                isUpdating: store.isUpdating,
                updateError: store.updateError,
                onPerformUpdate: { store.send(.performUpdate) },
                onDismissUpdateError: { store.send(.dismissUpdateError) }
            )

            Divider()

            // 工具卡片區域：各工具以手風琴式展開/收合
            ScrollView {
                VStack(spacing: 0) {
                    CopilotToolCardView(store: store)

                    Divider()
                    ClaudeToolCardView(store: store)

                    Divider()
                    CodexToolCardView(store: store)

                    Divider()
                    AntigravityToolCardView(store: store)

                    // 尚未上線的工具顯示「Coming Soon」卡片
                    ForEach(ToolKind.allCases.filter(\.isComingSoon)) { tool in
                        Divider()
                        ComingSoonCardView(tool: tool)
                    }
                }
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { newHeight in
                    scrollContentHeight = newHeight
                }
            }
            .frame(height: min(scrollContentHeight, maxScrollHeight))

            Divider()

            // 底部動作列：設定 + 結束應用程式
            MenuBarFooterView {
                store.send(.quitApp)
            }
        }
        .frame(width: 320)
        .task {
            await store.send(.onAppear).finish()
        }
        .onAppear {
            store.send(.menuDidAppear(refreshInterval))
        }
        .onDisappear {
            store.send(.menuDidDisappear)
        }
    }
}
