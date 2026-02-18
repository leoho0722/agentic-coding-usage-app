import Foundation

// MARK: - 共用工具方法

extension UsageCommand {

    /// 印出文字進度條。
    ///
    /// - Parameters:
    ///   - label: 進度條左側的標籤文字。
    ///   - percentage: 使用百分比（0-100）。
    ///   - barWidth: 進度條的字元寬度。
    func printProgressBar(label: String, percentage: Int, barWidth: Int) {
        let fraction = Double(percentage) / 100.0
        let filled = min(barWidth, Int(Double(barWidth) * fraction))
        let empty = barWidth - filled
        let bar = String(repeating: "#", count: filled) + String(repeating: "-", count: empty)
        print("  \(label): [\(bar)] \(percentage)%")
    }
}
