import ArgumentParser

@main
struct AgenticCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "agentic",
        abstract: "Monitor your AI coding assistant usage (GitHub Copilot, Claude Code, and more).",
        version: "1.6.0",
        subcommands: [LoginCommand.self, UsageCommand.self],
        defaultSubcommand: UsageCommand.self
    )
}
