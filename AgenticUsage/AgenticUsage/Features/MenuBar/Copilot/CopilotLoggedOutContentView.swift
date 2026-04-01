import SwiftUI
import ComposableArchitecture

// MARK: - CopilotLoggedOutContentView

/// 未登入時顯示的提示與連接 GitHub 按鈕。
///
/// 引導使用者透過 GitHub OAuth Device Flow 登入以查看 Copilot 用量。
struct CopilotLoggedOutContentView: View {

    /// MenuBarFeature 的 TCA Store
    let store: StoreOf<MenuBarFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sign in with GitHub to view your Copilot premium request usage.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // 登入失敗時的錯誤訊息橫幅
            if let error = store.copilot.errorMessage {
                ErrorBannerView(message: error, lineLimit: 3) {
                    store.send(.copilot(.dismissError))
                }
            }

            Button("Connect with GitHub") {
                store.send(.copilot(.loginButtonTapped))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
    }
}
