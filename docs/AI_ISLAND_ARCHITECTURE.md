# AI Island Architecture

Boring Notch × Vibe Island — native macOS AI Command Center inside the existing notch.

## Goals

- Keep all existing Boring Notch features
- Add **AI Island** as a first-class notch tab
- Multi-agent architecture with pluggable adapters
- Local-first, explicit user approval, no fake integrations

## Data flow

```text
AI Agent (Cursor / Claude Code / …)
        ↓
  AgentAdapter (detect + optional bridge)
        ↓
  AgentSession[] + AgentEvent
        ↓
  AgentManager (facade / merge / attention)
        ↓
  Notch UI (AIIslandView + collapsed chip + sneak peek)
```

## Seam

`AgentAdapter` mirrors `MediaControllerProtocol`:

| Media | AI Island |
|-------|-----------|
| `MediaControllerProtocol` | `AgentAdapter` |
| `MusicManager` | `AgentManager` |
| `PlaybackState` | `AgentSession` |
| `Defaults[.mediaController]` | `Defaults[.aiIslandEnabledAgents]` |

UI never talks to adapters directly.

## Status machine

`idle → starting → working → waiting | permissionRequired | question | planReview → completed | failed | disconnected`

Attention priority (lower = higher):

1. permissionRequired  
2. question  
3. failed  
4. planReview  
5. completed  
6. working / starting  
7. waiting  
8. idle  
9. disconnected  

## Notch integration

- `NotchViews.aiIsland` tab
- `ContentView` routes to `AIIslandView`
- Collapsed chip when attention > 0
- `SneakContentType.agent` (does not require HUD replacement)
- Settings → **AI Island**

## Packaging

Sources live under `boringNotch/AIIsland/` as a `PBXFileSystemSynchronizedRootGroup` so new files compile without hand-editing `pbxproj`.

## Performance

- Adapters refresh on a 5s timer (not aggressive polling)
- Attention sneak peeks are signature-debounced (no spam)
- Per-adapter failure is isolated inside `AgentManager`
