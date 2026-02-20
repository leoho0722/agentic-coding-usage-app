# AgenticUsage

> 一款 macOS 選單列應用程式與 CLI 工具，用於監控 AI 程式碼助手的使用量。

[English](README.md)

## 概述

靈感來自開源專案 [**OpenUsage**](https://github.com/robinebers/openusage)，AgenticUsage 是由此啟發而誕生的 Side Project。它幫助開發者透過輕量的 macOS 選單列應用程式或 CLI 工具，追蹤與監控多種 AI 程式碼助手的使用量。

**支援的服務：**

- GitHub Copilot
- Claude Code
- OpenAI Codex
- Google Antigravity

## 功能

### 選單列應用程式

- 手風琴式卡片顯示各服務的使用量
- 即時使用量統計
- OAuth 認證流程
- 透過 macOS 鑰匙圈安全儲存 Token
- 使用量通知

### CLI 工具（`agentic`）

- `agentic login` — 使用 OAuth Device Flow 進行 GitHub 認證
- `agentic usage` — 顯示當前計費週期的 AI 助手使用量
- `agentic update` — 檢查更新並自動更新 CLI

## 系統需求

- **選單列應用程式**：macOS 15.0（Sequoia）或更新版本
- **CLI 工具**：macOS 15.0（Sequoia）或更新版本

## 安裝

從 [GitHub Releases](https://github.com/leoho0722/agentic-coding-usage-app/releases) 頁面下載最新的預建構二進位檔：

- **AgenticUsage-v\<version\>.zip** — 選單列應用程式
- **AgenticCLI-v\<version\>-arm64.zip** — CLI 二進位檔（Apple Silicon）

## 使用方式

### App

啟動 **AgenticUsage** — 它會常駐在 macOS 選單列。點擊圖示即可查看手風琴式卡片，顯示各已連結服務的使用量統計。

### CLI

```bash
# 進行 GitHub 認證
agentic login --client-id <YOUR_CLIENT_ID>

# 顯示所有服務的使用量（預設）
agentic usage

# 顯示特定服務的使用量
agentic usage --tool copilot
agentic usage --tool claude
agentic usage --tool codex
agentic usage --tool antigravity

# 檢查是否有更新
agentic update --check

# 自動更新至最新版本
agentic update
```

## 專案結構

```text
agentic-coding-usage-app/
├── AgenticCLI/                  # CLI 工具（Swift Package）
│   └── Sources/AgenticCLI/
│       ├── AgenticCLI.swift     # 進入點
│       └── Commands/            # login, usage, update
├── AgenticUsage/                # macOS 選單列應用程式
│   ├── AgenticUsage.xcodeproj/
│   └── AgenticUsage/
│       ├── Application/         # 應用程式生命週期
│       ├── Configuration/       # 建構設定、密鑰
│       ├── Features/            # MenuBar、Notification
│       ├── Services/            # 依賴注入（TCA）
│       ├── Resources/           # 資源檔
│       └── Utilities/
├── Packages/
│   ├── AgenticCore/             # 共用核心函式庫
│   │   └── Sources/AgenticCore/
│   │       ├── Auth/            # OAuth、鑰匙圈
│   │       ├── Networking/      # API 客戶端
│   │       ├── Models/          # 資料模型
│   │       └── Utilities/       # 日期、SQLite、Protobuf
│   └── AgenticUpdater/          # 自動更新函式庫
├── .github/workflows/           # CI/CD 流程
└── LICENSE
```

## 技術棧

- **Swift 6.0** — 程式語言
- **SwiftUI** — 選單列應用程式 UI
- **AppKit** — macOS 整合
- **The Composable Architecture（TCA）** — 狀態管理
- **swift-argument-parser** — CLI 框架
- **SQLite3** — 本機資料儲存
- **Keychain Services** — 安全憑證儲存

## 授權條款

本專案採用 [MIT 授權條款](LICENSE)。

## 貢獻

歡迎貢獻！請開啟 Issue 或提交 Pull Request。
