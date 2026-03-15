import SwiftUI

// MARK: - ToolStatusTextView

/// 「| + 狀態文字」的共用元件，用於卡片標題列的狀態標籤。
///
/// 以分隔符搭配次要色調文字呈現工具的連線狀態（如 "Not Connected"、"Not Detected"）。
struct ToolStatusTextView: View {

    /// 狀態文字（例如 "Not Connected"、"Connecting..."、"Not Detected"）
    ///
    /// 使用 `LocalizedStringKey` 以確保 SwiftUI 自動查詢翻譯目錄。
    let text: LocalizedStringKey

    var body: some View {
        Group {
            Text("|")
                .foregroundStyle(.quaternary)
            Text(text)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }
}
