# Findings — AI Island × Boring Notch

## Repo facts (verified)

- Entry: `DynamicNotchApp` + `AppDelegate` in `boringNotchApp.swift`
- Notch window: `BoringNotchSkyLightWindow` hosts `ContentView` + `BoringViewModel`
- Tabs today: `NotchViews` = `.home` | `.shelf` only
- Home composes Music + optional Calendar + Mirror (not separate tabs)
- Adapter precedent: `MediaControllerProtocol` → `MusicManager` facade → UI
- State: Combine + `@Published` + `Defaults` package
- HUD: `BoringViewCoordinator.toggleSneakPeek` / `SneakContentType`
- No XCTest target today
- Packaging: explicit PBX file lists + `PBXFileSystemSynchronizedRootGroup` for `private/`
- License: GPL-3
- Full Xcode may be missing (CLI tools only) — build verification may need `xcode-select -s`

## Integration decisions

| Decision | Choice | Why |
|----------|--------|-----|
| Surface | New tab `.aiIsland` | Mirrors Shelf; keeps Home intact |
| Domain seam | `AgentAdapter` protocol | Same depth pattern as media controllers |
| Facade | `AgentManager.shared` | UI never talks to adapters directly |
| File packaging | Synchronized group `AIIsland/` | Avoid hand-editing dozens of pbxproj entries |
| Closed state | Compact attention chip + sneak peek `.agent` | Reuse HUD path, no spam |
| Credentials | Never read/store API keys | Local process/workspace signals only |
| Incomplete integrations | Capability flags + Open/Focus fallback | Honest, not fake |

## Real integration surfaces (investigation targets)

- Cursor: process name, workspace folders under `~/Library/Application Support/Cursor`, CLI `cursor`
- Claude Code: CLI `claude`, session files if present under known local paths — verify before claiming
- Codex / Gemini / OpenCode / Qwen / Kimi / Copilot: detect install + open/focus; status only if evidence exists

## Constraints

- Preserve all existing Boring Notch features
- Match existing animation/typography/spacing
- Local-first, no auto-approve permissions
- Graceful failure per adapter
