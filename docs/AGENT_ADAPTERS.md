# Agent Adapters

## Protocol

`AgentAdapter` (`boringNotch/AIIsland/Adapter/AgentAdapter.swift`)

Required:

- `kind`, `capabilities`, `isAvailable`, `availabilityMessage`
- `sessionsPublisher`
- `startObserving` / `stopObserving` / `refresh`
- permission / question / plan / stop / restart / open / focus actions

Default implementations return `.unsupported` for bridges that are not available.

## Capability flags

| Flag | Meaning |
|------|---------|
| `supportsPermission` | Can send Allow/Deny back to agent |
| `supportsQuestions` | Can answer multiple-choice in-notch |
| `supportsPlanReview` | Can Approve/Reject/Feedback |
| `supportsUsage` | Has local usage numbers |
| `supportsSessionControl` | Can manage session lifecycle |
| `supportsTerminalFocus` | Can focus terminal/IDE |
| `supportsRemoteSession` | SSH/remote architecture |
| `supportsStop` / `supportsRestart` | Session control |
| `supportsOpenApp` | Can open the related app |

UI disables or falls back (`Open Agent`) when a capability is false.

## Built-in adapters

| Adapter | Detection | Live status bridge |
|---------|-----------|--------------------|
| `CursorAdapter` | App running + `~/Library/Application Support/Cursor` + `cursor` CLI | **No** — Open/Focus + workspace folders only |
| `ClaudeCodeAdapter` | `claude` CLI + `~/.claude` | **No** — Open Terminal |
| `CodexAdapter` | `codex` / `~/.codex` | Detection only |
| `GeminiCLIAdapter` | `gemini` / `~/.gemini` | Detection only |
| `OpenCodeAdapter` | `opencode` | Detection only |
| `QwenAdapter` | `qwen` | Detection only |
| `KimiAdapter` | `kimi` | Detection only |
| `CopilotCLIAdapter` | `gh` present | Detection only |
| `RemoteAgentAdapter` | `ssh` present | Architecture stub |
| `MockAgentAdapter` | Always | Full demo permission/question/plan |

## Adding a new agent

1. Add `AgentKind` case + display metadata  
2. Subclass `DetectingAgentAdapter` (or implement `AgentAdapter`)  
3. Register in `AgentManager.registerDefaultAdapters()`  
4. Document real capabilities honestly — never fake a bridge  

## Focus

`AppFocusService` uses `NSWorkspace` activation and optional `AppleScriptHelper` activate. Prefer bundle IDs in `KnownAgentApps`.
