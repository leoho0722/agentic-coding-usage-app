import SwiftUI
import ComposableArchitecture

// MARK: - CopilotLoggedInContentView

/// 已登入時的完整內容，包含用量摘要、錯誤提示與操作按鈕。
///
/// 底部操作列提供重新整理與登出按鈕。
struct CopilotLoggedInContentView: View {

    /// MenuBarFeature 的 TCA Store
    let store: StoreOf<MenuBarFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 用量顯示區域：載入中 → 進度指示器；已載入 → 用量摘要
            if store.copilot.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                }
                .padding(12)
            } else if let summary = store.copilot.usageSummary {
                CopilotUsageSummaryView(summary: summary)
            }

            // 錯誤訊息橫幅
            if let error = store.copilot.errorMessage {
                ErrorBannerView(message: error) {
                    store.send(.copilot(.dismissError))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            Divider()
                .padding(.horizontal, 12)

            // 卡片底部操作列：重新整理 + 登出
            HStack {
                Button {
                    store.send(.copilot(.fetchUsage))
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .disabled(store.copilot.isLoading)

                Spacer()

                Button("Sign Out") {
                    store.send(.copilot(.logoutButtonTapped))
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}
