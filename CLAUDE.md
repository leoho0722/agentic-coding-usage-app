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

# 選單列應用程式（需先產生 Secrets.xcconfig，若已存在則跳過以免覆寫真實 secrets）
cd AgenticUsage && cp -n AgenticUsage/Configuration/Secrets.xcconfig.template AgenticUsage/Configuration/Secrets.xcconfig
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

- `MenuBarFeature`（Reducer）：協調層，管理生命週期、自動重新整理與更新邏輯，位於 `Features/MenuBar/MenuBarFeature.swift`
- `CopilotFeature`（Child Reducer）：管理 Copilot OAuth 認證與用量，位於 `Features/MenuBar/CopilotFeature.swift`
- `ClaudeCodeFeature`（Child Reducer）：管理 Claude Code 偵測與用量，位於 `Features/MenuBar/ClaudeCodeFeature.swift`
- `CodexFeature`（Child Reducer）：管理 Codex 偵測與用量，位於 `Features/MenuBar/CodexFeature.swift`
- `AntigravityFeature`（Child Reducer）：管理 Antigravity 偵測與用量，位於 `Features/MenuBar/AntigravityFeature.swift`
- `SettingsFeature`（Child Reducer）：管理設定視圖的狀態，作為 `MenuBarFeature` 的 child scope，位於 `Features/Settings/SettingsFeature.swift`
- 依賴服務透過 TCA 的 Dependencies 系統注入，定義於 `Services/Dependencies/`

#### View 層架構

- `MenuBarView`（組合層）：僅負責佈局組合與生命週期，不包含業務邏輯
- `SharedViews/` — 共用 View 元件（如 `UsageGaugeView`、`ErrorBannerView` 等）
- `Copilot/`、`Claude/`、`Codex/`、`Antigravity/` — 各工具獨立 View 目錄
- TCA Store 傳遞策略：工具卡片層級接收 `StoreOf<MenuBarFeature>`，純展示子視圖接收 plain data

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

版本號由根目錄的 `RELEASE_VERSION` 檔案控制（純文字 semver）。更新版本時需同步修改三處：

- `RELEASE_VERSION`（根目錄）— App 與 CD 共用
- `project.pbxproj` 中的 `MARKETING_VERSION`（Debug + Release 兩個 configuration）— App 版號
- `AgenticCLI/Sources/AgenticCLI/AgenticCLI.swift` 中 `CommandConfiguration` 的 `version` 參數 — CLI 版號

CD 會自動比對 `RELEASE_VERSION` 與最新 git tag，版本較新時建立對應的 git tag。

### Git Commit 訊息格式

- commit description（body）必須使用**列點**（`-`）條列變更項目，不使用純段落敘述

### Homebrew 發行

- Tap repo：`leoho0722/homebrew-tap`（`Formula/agentic.rb` + `Casks/agentic-usage.rb`）
- CD 流程在建立 GitHub Release 後，自動計算 SHA256 並 push 更新至 tap repo
- 需要 Actions secret `HOMEBREW_TAP_PAT`（Fine-grained PAT，scope 到 `leoho0722/homebrew-tap` 的 `Contents: Read and write`）
- 使用者安裝：`brew tap leoho0722/tap && brew install agentic`（CLI）/ `brew install --cask agentic-usage`（App）

## SwiftUI 編碼規範

撰寫或修改 View 時必須遵守以下規則：

- **禁止 `@ViewBuilder` computed property / method 回傳 `some View`**，一律拆為獨立 View struct 並各自獨立檔案
- **每個型別（struct / class / enum）各自一個 Swift 檔案**
- **禁止 `GeometryReader`**，改用 `scaleEffect`、`containerRelativeFrame()`、`visualEffect()` 等現代 API
- **禁止 `String(format:)` C 風格格式化**，改用 FormatStyle API（`.currency(code:)`、`.number.precision()` 等）
- **禁止 `foregroundColor()`**，一律用 `foregroundStyle()`
- **純圖示按鈕**必須用 `Button("文字標籤", systemImage: "icon") { }` + `.labelStyle(.iconOnly)`，確保 VoiceOver 可讀
- **泛型容器**的 `@ViewBuilder` slot 用 `@ViewBuilder var content: Content` 儲存已建構視圖，避免 `() -> Content` 逃逸閉包
- **按鈕動作**可用 `action:` 參數直接傳遞時，優先使用（如 `Button("Quit", action: onQuit)`）
- 按鈕內含邏輯時，抽至獨立 `private func`，不在 body 中 inline

## 多國語系注意事項

- 專案使用 String Catalogs（`.xcstrings`），支援 English（source）+ 繁體中文（zh-Hant）
- **關鍵**：View 屬性要傳入 `Text()` 且內容需翻譯時，型別必須用 `LocalizedStringKey` 而非 `String`。`Text(stringVar)` 其中 `stringVar: String` 等同 `Text(verbatim:)`，不會查詢翻譯目錄
- 重構移動字串後，需檢查 `.xcstrings` 中的 `extractionState: "stale"` 標記並清理
- 新增使用者可見字串時，須同步補上 zh-Hant 翻譯
- 品牌名稱（GitHub Copilot、Claude Code、OpenAI Codex、Google Antigravity）不翻譯

## Xcode 專案結構

- 專案使用 `PBXFileSystemSynchronizedRootGroup`（Xcode 16+ 自動同步），新增或刪除 Swift 檔案**不需**手動修改 `project.pbxproj`
- 檔案放入 `AgenticUsage/AgenticUsage/` 目錄下即自動納入建置

## 重要注意事項

- `Secrets.xcconfig` 不在版控中，建置 App 前需從 `.template` 複製或由 CI 產生
- App 未啟用 App Sandbox（`entitlements` 中 `app-sandbox = false`），以便存取檔案系統與 Keychain
- `SQLiteReader` 會複製 DB 至暫存目錄再讀取，避免鎖定衝突
- 所有網路操作使用 async/await + `URLSession`，符合 Swift 6 嚴格並行安全（`Sendable`）
- 所有使用者可見的程式註解與文件註解使用正體中文撰寫
