# AI Island Development

## Prerequisites

- macOS 14+
- Full **Xcode** (not only Command Line Tools) to build `boringNotch.xcodeproj`
- Apple Silicon or Intel

## Run

1. Open `boringNotch.xcodeproj`
2. Select scheme **boringNotch**
3. Build & Run
4. Hover the notch → tab **AI**
5. Settings → **AI Island**
   - Confirm Cursor/Claude detection matches your machine

## Project layout

```text
boringNotch/AIIsland/
  Domain/          AgentSession, status, attention, capabilities
  Adapter/         protocol, detection, concrete adapters
  Manager/         AgentManager facade
  Focus/           AppFocusService
  UI/              AIIslandView, settings
```

## Tests

Domain attention/priority tests live in:

```text
tools/AIIslandDomainTests/
```

Run:

```bash
cd tools/AIIslandDomainTests && swift test
```

## Honest integration checklist

Before claiming a live bridge for an agent:

1. Document the local IPC/file/CLI evidence  
2. Prove read path without credentials  
3. Prove write-back for permission/question if advertised  
4. Set capability flags accordingly  
5. Keep Open/Focus fallback  

## Common issues

| Symptom | Fix |
|---------|-----|
| Empty AI tab | Enable agents in Settings → AI Island |
| No sneak peek | Check `aiIslandNotifications` |
| Tabs missing | `aiIslandEnabled` or Shelf flags |
| Build fails with CLI tools only | Install Xcode and `xcode-select -s /Applications/Xcode.app` |
