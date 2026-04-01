import SwiftUI

// MARK: - ErrorBannerView

/// 錯誤訊息橫幅，統一各工具的錯誤提示樣式。
///
/// 關閉按鈕使用 `Button("text", systemImage:)` 搭配 `.labelStyle(.iconOnly)`，
/// 確保 VoiceOver 可正確朗讀按鈕用途。
struct ErrorBannerView: View {

    /// 錯誤訊息文字
    let message: String

    /// 文字行數限制，預設為 1
    var lineLimit: Int = 2

    /// 關閉按鈕的動作
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.caption2)
                .lineLimit(lineLimit)
            Spacer()

            // 關閉錯誤訊息按鈕
            Button("Dismiss error", systemImage: "xmark.circle", action: onDismiss)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
        }
    }
}
