import ArgumentParser

@main
struct AgenticCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "agentic",
        abstract: "Monitor your AI coding assistant premium request usage.",
        version: "1.0.0",
        subcommands: [LoginCommand.self, UsageCommand.self],
        defaultSubcommand: UsageCommand.self
    )
}
