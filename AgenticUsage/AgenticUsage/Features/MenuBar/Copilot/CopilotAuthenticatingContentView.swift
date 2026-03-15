import SwiftUI
import ComposableArchitecture

// MARK: - CopilotAuthenticatingContentView

/// Device Flow 認證進行中的畫面，顯示驗證碼與開啟 GitHub 按鈕。
///
/// 當收到 Device Code 後顯示驗證碼供使用者複製，並提供開啟 GitHub 驗證頁面的按鈕。
struct CopilotAuthenticatingContentView: View {

    /// MenuBarFeature 的 TCA Store
    let store: StoreOf<MenuBarFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let flow = store.copilot.deviceFlowState {
                Text("Enter this code on GitHub:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // 驗證碼與複製按鈕
                HStack {
                    Text(flow.userCode)
                        .font(.system(.title3, design: .monospaced, weight: .bold))
                        .textSelection(.enabled)

                    Button("Copy code", systemImage: "doc.on.doc") {
                        store.send(.copilot(.copyUserCode))
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help("Copy code")
                }

                // 開啟 GitHub 驗證頁面按鈕
                Button("Open GitHub") {
                    store.send(.copilot(.openVerificationURL))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Text("Waiting for authorization...")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                // 尚未收到 Device Code，顯示載入中
                ProgressView("Requesting device code...")
                    .controlSize(.small)
            }
        }
        .padding(12)
    }
}
