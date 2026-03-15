import SwiftUI

// MARK: - ToolIconView

/// 工具的 Asset Catalog 圖示，封裝 `@Environment(\.colorScheme)` 依賴。
///
/// 有品牌色調的工具（Claude、Antigravity）使用 template 著色模式；
/// 無品牌色調的工具（Copilot、Codex）使用 original 原始圖片模式。
struct ToolIconView: View {

    /// 工具類型，決定圖片名稱與是否套用品牌色調
    let tool: ToolKind

    /// 系統目前的外觀模式，Copilot 需依此切換 Light/Dark 圖片
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let tint = tool.tintColor {
            Image(tool.imageName(for: colorScheme))
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .foregroundStyle(tint)
        } else {
            Image(tool.imageName(for: colorScheme))
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
        }
    }
}
