import SwiftUI

// MARK: - MenuBarFooterView

/// 底部動作列，提供設定與結束應用程式的按鈕。
struct MenuBarFooterView: View {

    /// 結束應用程式的動作
    let onQuit: () -> Void

    /// 開啟設定視窗的環境動作
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        HStack {
            // 設定按鈕：啟動 App 後開啟設定視窗
            Button {
                openSettingsWindow()
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .font(.caption)
            }
            .buttonStyle(.borderless)

            Spacer()

            // 結束應用程式按鈕
            Button("Quit", action: onQuit)
                .buttonStyle(.borderless)
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Private

    /// 啟動 App 視窗並開啟設定頁面。
    private func openSettingsWindow() {
        NSApp.activate()
        openSettings()
    }
}
