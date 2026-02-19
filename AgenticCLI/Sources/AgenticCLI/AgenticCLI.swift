import ArgumentParser

// MARK: - AgenticCLI

/// AgenticCLI 的主進入點，定義 CLI 工具的根指令結構。
///
/// 提供 `login`、`usage` 與 `update` 三個子指令，預設執行 `usage`。
@main
struct AgenticCLI: AsyncParsableCommand {

    /// CLI 指令的組態設定，包含指令名稱、說明、版本號與子指令。
    static let configuration = CommandConfiguration(
        commandName: "agentic",
        abstract: "Monitor your AI coding assistant usage (GitHub Copilot, Claude Code, Google Antigravity, and more).",
        version: "1.8.0",
        subcommands: [LoginCommand.self, UsageCommand.self, UpdateCommand.self],
        defaultSubcommand: UsageCommand.self,
    )
}
