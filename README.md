# AgenticUsage

> A macOS menu bar app & CLI tool for monitoring AI coding assistant usage.

[正體中文](README.zh-TW.md)

## Overview

Inspired by the open-source project [**OpenUsage**](https://github.com/robinebers/openusage) — this side project was born from that inspiration. AgenticUsage helps developers track and monitor their AI coding assistant usage across multiple services, all from a lightweight macOS menu bar app or a CLI tool.

**Supported services:**

- GitHub Copilot
- Claude Code
- OpenAI Codex
- Google Antigravity

## Features

### Menu Bar App

- Accordion-style cards displaying usage for each service
- Real-time usage statistics
- OAuth authentication flow
- Secure token storage via macOS Keychain
- Usage notifications

### CLI Tool (`agentic`)

- `agentic login` — Authenticate with GitHub using OAuth Device Flow
- `agentic usage` — Show AI assistant usage for the current billing period
- `agentic update` — Check for updates and self-update the CLI

## Requirements

- **Menu Bar App**: macOS 15.0 (Sequoia) or later
- **CLI Tool**: macOS 15.0 (Sequoia) or later

## Installation

Download the latest pre-built binaries from the [GitHub Releases](https://github.com/leoho0722/agentic-coding-usage-app/releases) page:

- **AgenticUsage-v\<version\>.zip** — Menu bar app
- **AgenticCLI-v\<version\>-arm64.zip** — CLI binary (Apple Silicon)

## Usage

### App

Launch **AgenticUsage** — it lives in the macOS menu bar. Click the icon to view accordion-style cards showing usage stats for each connected service.

### CLI

```bash
# Authenticate with GitHub
agentic login --client-id <YOUR_CLIENT_ID>

# Show usage for all services (default)
agentic usage

# Show usage for a specific service
agentic usage --tool copilot
agentic usage --tool claude
agentic usage --tool codex
agentic usage --tool antigravity

# Check for updates
agentic update --check

# Self-update to latest version
agentic update
```

## Project Structure

```text
agentic-coding-usage-app/
├── AgenticCLI/                  # CLI tool (Swift Package)
│   └── Sources/AgenticCLI/
│       ├── AgenticCLI.swift     # Entry point
│       └── Commands/            # login, usage, update
├── AgenticUsage/                # macOS menu bar app
│   ├── AgenticUsage.xcodeproj/
│   └── AgenticUsage/
│       ├── Application/         # App lifecycle
│       ├── Configuration/       # Build settings, secrets
│       ├── Features/            # MenuBar, Notification
│       ├── Services/            # Dependencies (TCA)
│       ├── Resources/           # Assets
│       └── Utilities/
├── Packages/
│   ├── AgenticCore/             # Shared core library
│   │   └── Sources/AgenticCore/
│   │       ├── Auth/            # OAuth, Keychain
│   │       ├── Networking/      # API clients
│   │       ├── Models/          # Data models
│   │       └── Utilities/       # Date, SQLite, Protobuf
│   └── AgenticUpdater/          # Self-update library
├── .github/workflows/           # CI/CD pipelines
└── LICENSE
```

## Tech Stack

- **Swift 6.0** — Language
- **SwiftUI** — Menu bar app UI
- **AppKit** — macOS integration
- **The Composable Architecture (TCA)** — State management
- **swift-argument-parser** — CLI framework
- **SQLite3** — Local data storage
- **Keychain Services** — Secure credential storage

## License

This project is licensed under the [MIT License](LICENSE).

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.
