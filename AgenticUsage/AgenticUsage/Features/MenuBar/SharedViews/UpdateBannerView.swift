import SwiftUI
import AgenticUpdater

// MARK: - UpdateBannerView

/// 更新提示橫幅，當檢測到新版本時顯示。
///
/// 包含版本資訊、更新按鈕、更新進度與錯誤提示。
struct UpdateBannerView: View {

    /// 更新資訊，為 `nil` 時不顯示橫幅
    let updateInfo: UpdateInfo?

    /// 是否正在下載/安裝更新
    let isUpdating: Bool

    /// 更新錯誤訊息
    let updateError: String?

    /// 點擊「Update Now」按鈕的動作
    let onPerformUpdate: () -> Void

    /// 關閉更新錯誤訊息的動作
    let onDismissUpdateError: () -> Void

    var body: some View {
        if let updateInfo {
            Divider()

            HStack(spacing: 6) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.subheadline)

                Text("v\(updateInfo.latestVersion.description) available")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                // 更新中顯示進度指示器，否則顯示更新按鈕
                if isUpdating {
                    ProgressView()
                        .controlSize(.small)
                    Text("Updating...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Button("Update Now", action: onPerformUpdate)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            // 更新錯誤提示
            if let error = updateError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption2)

                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Spacer()

                    // 關閉更新錯誤按鈕
                    Button("Dismiss update error", systemImage: "xmark.circle.fill", action: onDismissUpdateError)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .foregroundStyle(.tertiary)
                        .font(.caption2)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }
        }
    }
}
