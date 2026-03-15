import SwiftUI

// MARK: - ProgressBarView

/// 水平進度條，依據百分比著色（綠 → 黃 → 橘 → 紅）。
///
/// 使用 `scaleEffect(x:anchor:)` 取代 `GeometryReader`，避免不必要的佈局計算。
struct ProgressBarView: View {

    /// 使用百分比（0.0–1.0）
    let percentage: Double

    /// 將百分比限制在 0–1 範圍內，避免進度條溢出
    private var clamped: Double { min(max(percentage, 0), 1) }

    var body: some View {
        ZStack(alignment: .leading) {
            // 背景軌道
            Capsule().fill(.quaternary)
            // 前景進度，透過 scaleEffect 控制寬度比例
            Capsule()
                .fill(Self.color(for: percentage))
                .scaleEffect(x: clamped, anchor: .leading)
        }
        .frame(height: 8)
    }

    /// 依據使用百分比回傳對應的顏色等級。
    /// - Parameter percentage: 使用百分比（0.0–1.0）
    /// - Returns: 對應的顏色（綠 → 黃 → 橘 → 紅）
    static func color(for percentage: Double) -> Color {
        switch percentage {
        case ..<0.5: .green
        case 0.5..<0.8: .yellow
        case 0.8..<1.0: .orange
        default: .red
        }
    }
}
