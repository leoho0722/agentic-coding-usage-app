import SwiftUI

// MARK: - NotDetectedContentView

/// 未偵測到憑證時的共用內容範本，適用於 Claude/Codex/Antigravity。
///
/// 提供載入中狀態、提示文字、重新偵測按鈕與錯誤橫幅。
struct NotDetectedContentView: View {

    /// 提示訊息，引導使用者先登入對應工具
    ///
    /// 使用 `LocalizedStringKey` 以確保 SwiftUI 自動查詢翻譯目錄。
    let promptMessage: LocalizedStringKey

    /// 是否正在載入（偵測憑證中）
    let isLoading: Bool

    /// 錯誤訊息，偵測失敗時顯示
    let errorMessage: String?

    /// 重新偵測按鈕的動作
    let onRedetect: () -> Void

    /// 關閉錯誤訊息的動作
    let onDismissError: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                }
            } else {
                Text(promptMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Re-detect", action: onRedetect)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }

            // 錯誤訊息橫幅
            if let error = errorMessage {
                ErrorBannerView(message: error, onDismiss: onDismissError)
            }
        }
        .padding(12)
    }
}
