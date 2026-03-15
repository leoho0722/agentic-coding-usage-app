import SwiftUI

// MARK: - ConnectedContentView

/// 已連線時的共用內容範本，包含用量摘要 slot、錯誤提示與重新整理按鈕。
///
/// 使用 `@ViewBuilder var` 儲存已建構的視圖結果，避免逃逸閉包效能問題。
struct ConnectedContentView<UsageSummary: View>: View {

    /// 是否正在載入
    let isLoading: Bool

    /// 錯誤訊息
    let errorMessage: String?

    /// 重新整理按鈕的動作
    let onRefresh: () -> Void

    /// 關閉錯誤訊息的動作
    let onDismissError: () -> Void

    /// 用量摘要內容，由呼叫端透過 trailing closure 提供
    @ViewBuilder var usageSummary: UsageSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 載入中顯示進度指示器，否則顯示用量摘要
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                }
                .padding(12)
            } else {
                usageSummary
            }

            // 錯誤訊息橫幅
            if let error = errorMessage {
                ErrorBannerView(message: error, lineLimit: 2, onDismiss: onDismissError)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }

            Divider()
                .padding(.horizontal, 12)

            // 重新整理按鈕列
            HStack {
                Button("Refresh", systemImage: "arrow.clockwise", action: onRefresh)
                    .font(.caption)
                    .buttonStyle(.borderless)
                    .disabled(isLoading)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}
