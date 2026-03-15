import SwiftUI

// MARK: - MenuBarHeaderView

/// 頂部標題列，顯示 App 名稱與版本號。
///
/// 左側為 App 圖示與名稱，右側為目前版本號。
struct MenuBarHeaderView: View {

    var body: some View {
        HStack {
            Label("AgenticUsage", systemImage: "chart.bar.fill")
                .font(.headline)
            Spacer()
            Text("Version：\(Bundle.main.shortVersionString)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
