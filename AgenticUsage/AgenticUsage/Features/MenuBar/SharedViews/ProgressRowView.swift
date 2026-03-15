import SwiftUI

// MARK: - ProgressRowView

/// 用量進度列，顯示標籤、百分比、重設倒數與進度條。
///
/// 統一 Claude/Codex/Antigravity 三組幾乎相同的 progressRow 為單一共用元件。
struct ProgressRowView: View {

    /// 用量窗口的標籤文字（例如 "Session (5h)"、"Weekly (7d)"）
    let label: LocalizedStringKey

    /// 使用百分比（0–100）
    let usedPercent: Int

    /// 重設倒數文字（例如 "2h 30m"），若無則隱藏倒數標籤
    let countdown: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                // 百分比文字，顏色依用量等級變化
                Text("\(usedPercent)%")
                    .font(.caption)
                    .foregroundStyle(ProgressBarView.color(for: Double(usedPercent) / 100.0))
                // 重設倒數（選擇性顯示）
                if let countdown {
                    Text("· resets in \(countdown)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            ProgressBarView(percentage: Double(usedPercent) / 100.0)
        }
    }
}
