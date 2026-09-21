# Progress — AI Island

## Session 2026-09-21

### Done
- Phase 1 analysis of Boring Notch architecture
- Domain model (status, capabilities, session, event, attention)
- AgentAdapter + DetectingAgentAdapter + Mock + concrete adapters
- AgentManager facade + AppFocusService
- AI Island UI (list, detail, permission/question/plan, collapsed chip)
- Wired `NotchViews.aiIsland`, tabs, ContentView, Settings, sneak peek `.agent`
- Defaults keys for enable/demo/notifications/agents
- Docs under `docs/`
- Domain test package + script (blocked by missing full Xcode / SDK mismatch)

### Verification
- `swift test` / `swift script` / `xcodebuild`: **blocked** — only Command Line Tools installed; SDK/compiler patch mismatch; no Xcode.app
- Manual review of integration points completed against MediaManager pattern

### Next for human
1. Install Xcode and select it: `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
2. Open `boringNotch.xcodeproj`, Build & Run
3. Settings → AI Island → enable Demo Mode to validate UI flows
4. Turn off Demo Mode; confirm Cursor/Claude detection matches your machine
