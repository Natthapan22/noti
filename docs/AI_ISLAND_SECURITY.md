# AI Island Security

## Hard rules

- Never hardcode or store API keys / tokens / credentials
- Never scrape cloud quotas by impersonating a user session
- Never upload source code, terminal logs, or prompts
- Never auto-approve commands, file access, tool calls, or network actions
- Never silently enable Accessibility or Apple Events permissions
- Never execute arbitrary shell from agent-supplied strings inside Boring Notch

## Permission UX

Allow / Deny is always an **explicit user action**.

If the adapter cannot send the decision back to the agent:

- show the request for awareness
- provide **Open Agent** / **Open Terminal**
- do not pretend the agent received Allow

## Trust boundary

| Input | Handling |
|-------|----------|
| Adapter session fields | Treated as untrusted display text |
| Permission detail strings | Display only — not executed |
| Workspace paths | Existence-checked before Finder open |
| AppleScript app names | Escaped quotes/backslashes |

## Local-first

All detection uses:

- `NSWorkspace.runningApplications`
- executable presence on disk (`which`-style PATH scan)
- optional support directories under the user home

No network calls are made by AI Island core for agent status.
