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

    /// 將原始 JSON 資料以格式化方式印出。
    ///
    /// 若資料為合法 JSON，則以排序鍵值且縮排的格式輸出；
    /// 否則以原始 UTF-8 字串輸出。
    ///
    /// - Parameter data: 原始 JSON 資料。
    func printPrettyJSON(_ data: Data) {
        if let jsonObject = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(
               withJSONObject: jsonObject,
               options: [.prettyPrinted, .sortedKeys]
           ),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            print(prettyString)
        } else if let rawString = String(data: data, encoding: .utf8) {
            print(rawString)
        } else {
            print("  (unable to decode as UTF-8, \(data.count) bytes)")
        }
    }
}
