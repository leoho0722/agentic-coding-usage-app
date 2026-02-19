import Foundation
import AgenticCore
import ArgumentParser

// MARK: - UsageCommand

/// 顯示 AI 程式碼輔助工具用量的 CLI 子指令。
///
/// 支援查詢 Copilot、Claude Code、Codex 的用量，
/// 可透過 `--tool` 參數篩選特定工具或顯示全部。
struct UsageCommand: AsyncParsableCommand {

    /// CLI 指令的組態設定。
    static let configuration = CommandConfiguration(
        commandName: "usage",
        abstract: "Show your AI coding assistant usage for the current period.",
    )

    /// 要顯示用量的工具名稱，支援 `copilot`、`claude`、`codex` 或 `all`。
    @Option(name: .long, help: "Tool to show usage for: copilot, claude, codex, antigravity, or all (default: all).")
    var tool: String = "all"

    /// 依據篩選條件查詢並顯示各工具的用量資訊。
    ///
    /// 依序查詢 Copilot、Claude Code、Codex 的用量。
    /// 當篩選特定工具時，該工具的錯誤會直接拋出；
    /// 當顯示全部時，個別工具的錯誤僅印出訊息而不中斷流程。
    ///
    /// - Throws: 當工具名稱無效或所有工具均無可用資料時拋出錯誤。
    func run() async throws {
        let toolFilter = tool.lowercased()

        guard ["all", "copilot", "claude", "codex", "antigravity"].contains(toolFilter) else {
            print("Error: Unknown tool '\(tool)'. Use 'copilot', 'claude', 'codex', 'antigravity', or 'all'.")
            throw ExitCode.failure
        }

        // 追蹤是否有任何工具成功印出用量資訊
        var printed = false

        // 查詢 Copilot 用量
        if toolFilter == "all" || toolFilter == "copilot" {
            do {
                try await printCopilotUsage()
                printed = true
            } catch {
                // 僅篩選特定工具時才將錯誤往上拋出
                if toolFilter == "copilot" {
                    throw error
                }
                print("  [Copilot] \(error.localizedDescription)")
                print()
            }
        }

        // 查詢 Claude Code 用量
        if toolFilter == "all" || toolFilter == "claude" {
            if printed { print(String(repeating: "─", count: 40)); print() }
            do {
                try await printClaudeUsage()
                printed = true
            } catch {
                if toolFilter == "claude" {
                    throw error
                }
                print("  [Claude Code] \(error.localizedDescription)")
                print()
            }
        }

        // 查詢 Codex 用量
        if toolFilter == "all" || toolFilter == "codex" {
            if printed { print(String(repeating: "─", count: 40)); print() }
            do {
                try await printCodexUsage()
                printed = true
            } catch {
                if toolFilter == "codex" {
                    throw error
                }
                print("  [Codex] \(error.localizedDescription)")
                print()
            }
        }

        // 查詢 Antigravity 用量
        if toolFilter == "all" || toolFilter == "antigravity" {
            if printed { print(String(repeating: "─", count: 40)); print() }
            do {
                try await printAntigravityUsage()
                printed = true
            } catch {
                if toolFilter == "antigravity" {
                    throw error
                }
                print("  [Antigravity] \(error.localizedDescription)")
                print()
            }
        }

        if !printed {
            print("No usage data available. Make sure you're logged in.")
            throw ExitCode.failure
        }
    }
}
