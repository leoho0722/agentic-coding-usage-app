# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 專案概述

AgenticUsage 是一款 macOS 選單列應用程式與 CLI 工具，用於監控多種 AI 程式碼助手（GitHub Copilot、Claude Code、OpenAI Codex、Google Antigravity）的使用量。以 Swift 6.0 撰寫，最低支援 macOS 15.0（Sequoia）。

## 常用指令

### 建置

```bash
# CLI 工具（Debug）
cd AgenticCLI && swift build

# CLI 工具（Release，Apple Silicon）
cd AgenticCLI && swift build -c release --arch arm64

# 核心函式庫
cd Packages/AgenticCore && swift build

# 選單列應用程式（需先產生 Secrets.xcconfig）
cd AgenticUsage && cp AgenticUsage/Configuration/Secrets.xcconfig.template AgenticUsage/Configuration/Secrets.xcconfig
cd AgenticUsage && xcodebuild build -project AgenticUsage.xcodeproj -scheme AgenticUsage -configuration Release
```

### 測試

```bash
# AgenticCore 單元測試
cd Packages/AgenticCore && swift test

# AgenticUsage 單元測試（跳過 UI 測試與 Macro 驗證，略過簽署）
cd AgenticUsage && xcodebuild test \
  -project AgenticUsage.xcodeproj \
  -scheme AgenticUsage \
  -destination 'platform=macOS' \
  -skip-testing:AgenticUsageUITests \
  -skipMacroValidation \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

## 架構

### 三大模組

```text
AgenticCLI/          → CLI 可執行檔（依賴 AgenticCore + AgenticUpdater）
AgenticUsage/        → macOS 選單列應用程式（Xcode 專案，依賴 AgenticCore + AgenticUpdater）
Packages/
  AgenticCore/       → 共用核心函式庫（Auth、Networking、Models、Utilities）
  AgenticUpdater/    → 自動更新函式庫（GitHub Releases API）
```

CLI 與 App 共用 `AgenticCore` 中的認證、API 客戶端與資料模型，各自獨立組裝。

### 狀態管理（App）

選單列應用程式使用 **The Composable Architecture（TCA）** 進行狀態管理：

- `MenuBarFeature`（Reducer）：處理所有業務邏輯，位於 `Features/MenuBar/MenuBarFeature.swift`
- 依賴服務透過 TCA 的 Dependencies 系統注入，定義於 `Services/Dependencies/`

### API 客戶端模式

每個支援的服務皆有獨立的 API 客戶端（位於 `AgenticCore/Networking/`），以 struct + closure 實作依賴注入：

- `GitHubAPIClient` — Copilot 使用量
- `ClaudeAPIClient` — Claude Code 使用量
- `CodexAPIClient` — OpenAI Codex 使用量
- `AntigravityAPIClient` — Google Antigravity 使用量

### 憑證儲存策略

| 服務        | 儲存方式                                                  |
|-------------|-----------------------------------------------------------|
| Copilot     | macOS Keychain（`KeychainService`）                         |
| Claude Code | `~/.claude/.credentials.json`，Keychain 為備援             |
| Codex       | VSCode state SQLite DB（`SQLiteReader`）                    |
| Antigravity | VSCode state SQLite DB + Protobuf 解碼（`ProtobufDecoder`） |

### CLI 指令結構

CLI 使用 `swift-argument-parser`，進入點為 `AgenticCLI.swift`，子指令位於 `Commands/`：

- `LoginCommand` — OAuth Device Flow 認證
- `UsageCommand` — 查詢使用量（各服務邏輯以 extension 分檔：`UsageCommand+Claude.swift` 等）
- `UpdateCommand` — 自我更新

## CI/CD

- **CI**（`.github/workflows/ci.yml`）：push/PR 至 `main` 時觸發，執行 AgenticCore 測試、CLI 建置、App 測試
- **CD**（`.github/workflows/cd.yml`）：CI 通過後自動比對 `RELEASE_VERSION` 與最新 git tag，版本較新時建置並發佈 GitHub Release

### 版本管理

版本號由根目錄的 `RELEASE_VERSION` 檔案控制（純文字 semver）。更新版本時修改此檔即可，CD 會自動建立對應的 git tag。

## 重要注意事項

- `Secrets.xcconfig` 不在版控中，建置 App 前需從 `.template` 複製或由 CI 產生
- App 未啟用 App Sandbox（`entitlements` 中 `app-sandbox = false`），以便存取檔案系統與 Keychain
- `SQLiteReader` 會複製 DB 至暫存目錄再讀取，避免鎖定衝突
- 所有網路操作使用 async/await + `URLSession`，符合 Swift 6 嚴格並行安全（`Sendable`）
