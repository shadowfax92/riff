<div align="center">

# 🎸 Riff

**Multi-agent debates between local AI CLIs.**

*One window. Claude and Codex, taking turns, on disk.*

</div>

A native macOS app that runs Claude Code and Codex CLI side-by-side against the same prompt, rotates their turns, and stores everything as plain files — `conversation.json`, `transcript.jsonl`, and per-agent state under `agents/<id>/`. No database, no cloud, just files you can read, diff, and git track.

- **Three-pane SwiftUI window** — conversations sidebar, chat transcript, and a live file viewer for attachments
- **iMessage-style bubbles** with full-width inline markdown rendering and a word-count footer per turn
- **Live thinking indicator** — avatar, dots, and a ticking elapsed-time bubble while a CLI turn is in flight
- **Round-robin debates** — agents take turns per round; defaults to 10 rounds, configurable 1–12
- **Per-conversation roles** — define agents inline when you create the debate (no global config to maintain)
- **File-backed** — every turn lands in `transcript.jsonl`, every attachment in `files/`
- **Resumable sessions + incremental context** — per-agent CLI session IDs are persisted; each turn only sends *new* messages since the agent last spoke, so prompts stay small as debates grow
- **Markdown attachments** — agents write supporting detail to disk; the next agent reads them back as context
- **Live user injection** — type during a run; your message queues into the next iteration as a `user` turn
- **Runtime detection** — probes `claude` and `codex` on `$PATH` at startup, falls back to known model lists
- **Settings sheet** — edit the baseline prompt and the CLI search path without leaving the app
- **Light / dark / system theme toggle** in the toolbar
- **Custom conversation roots** — keep a debate inside any folder you pick, or use the default `~/.riff/conversations/`
- **Delete conversations** from the sidebar

---

## Install

Requires macOS 15+, Swift 6 toolchain (Xcode 16), and the CLIs you want to debate with: [Claude Code](https://docs.claude.com/en/docs/claude-code) and/or [Codex CLI](https://github.com/openai/codex).

```sh
git clone <repo-url> riff-swift
cd riff-swift
make
open Riff.app
```

To install the app bundle:

```sh
make install
open ~/Applications/Riff.app
```

Or open `Package.swift` in Xcode and run the `Riff` scheme.

## Quick Start

```sh
make open
```

Use the app bundle for normal launches. `swift run Riff` runs the raw SwiftPM executable, which is useful for debugging but may not activate like a regular macOS app.

On first launch Riff creates `~/.riff/config/` (migrating any pre-existing `~/.riff/configs/prompt.md` if you upgraded from an earlier build):

- `base_prompt.md` — the baseline instruction shared by every agent
- `runtime.json` — CLI search path overrides
- `recent-conversations.json` — sidebar history

Then click **New chat** in the sidebar, give the debate a title and a prompt, set rounds, add your roles (each role becomes one agent), and hit **Start**.

## Status Flow

```
idle  →  running  →  stopped
```

`Start` flips the conversation to `running` and kicks the orchestrator loop. `Stop` requests a stop — it never interrupts an in-flight CLI turn, only the next turn boundary.

## On-disk Layout

A conversation is just a directory:

```
<conversation-root>/
├── conversation.json        # title, prompt, agents, status, maxRounds
├── transcript.jsonl         # append-only turn-by-turn log
├── files/                   # markdown attachments written by agents
│   └── turn-003.critic.codex.md
└── agents/
    └── <agent-id>/
        ├── agent.json       # frozen profile snapshot
        ├── session.json     # CLI session ID + lastContextTurn cursor
        └── cwd/             # the agent's working directory
```

Conversation roots live under `~/.riff/conversations/<uuid>/` unless you pick a custom folder in the new-conversation sheet. Recent locations are remembered in `~/.riff/config/recent-conversations.json`.

## How a Turn Works

For each turn the orchestrator:

1. Drains queued user messages and appends them to the transcript.
2. Picks the next agent in round-robin order.
3. Reads the agent's `session.json` to get its CLI session ID and `lastContextTurn`.
4. Builds a prompt = baseline + conversation prompt + **incremental context** (only transcript entries newer than `lastContextTurn` and not authored by this agent — its CLI session already remembers what *it* said).
5. Invokes the runtime CLI (`claude -p ...` or `codex exec ...`), passing `--resume`/`exec resume` when a session ID exists.
6. Parses the response, captures the new session ID, and detects any markdown files the agent wrote into `files/`.
7. Appends a `TranscriptEntry` to `transcript.jsonl` and writes back `session.json` with an updated `lastContextTurn`.

This keeps prompt size roughly constant per turn instead of growing quadratically with debate length.

## Roles

Roles are defined **per conversation** in the New Chat sheet, not in a global config file. Each role becomes an `AgentProfile`:

| Field | Description |
|-------|-------------|
| `roleName` | Display name in the chat pane; also used in attachment filenames (`turn-003.critic.codex.md`) |
| `runtime` | `claude` or `codex` |
| `model` | `"default"` (let the CLI pick) or a specific model slug |
| `reasoning` | Codex-only: `low` / `medium` / `high` reasoning effort |
| `rolePrompt` | Per-agent instructions appended after the baseline prompt on the first turn |

Add more roles to a single debate with the **Add Role** button. There's no minimum — even one role is a valid "Riff" against the user.

The first turn for an agent sends `baseline + role prompt + response contract + debate prompt + context`. Subsequent turns rely on the CLI session and only send the new context delta.

## Baseline Prompt

`~/.riff/config/base_prompt.md` is prepended to every agent's first turn. The default asks each agent for a ~280-word direct argument and tells them to write long appendices to the attachment path instead of pasting them into the chat bubble.

Edit it via **Settings** in the sidebar (or open the file directly) to change what "participating in a Riff debate" means for your agents.

## Settings

The Settings sheet (gear icon in the sidebar) exposes:

- **Base prompt** — multi-line editor backed by `~/.riff/config/base_prompt.md`
- **CLI path** — colon-separated `PATH` used when launching `claude` / `codex`. Defaults to the user's login shell `PATH`. Useful if your CLIs live somewhere `LaunchServices` doesn't see (e.g. `~/.local/bin`, `nvm` shims).

Saving the CLI path triggers an immediate re-probe of both runtimes.

## Runtimes

Riff probes for the CLIs at startup using the `PATH` from `runtime.json`:

| Runtime | Binary | Detection |
|---------|--------|-----------|
| Claude Code | `claude` (or `openclaude`) | `claude --version`, static fallback model list |
| Codex CLI | `codex` | `codex --version` + `codex debug models` for live model list |

If a binary isn't found, that runtime shows as unavailable but its agents can still be configured. The model picker in the new-conversation sheet uses live results when available and falls back to a hand-curated list otherwise.

## Development

```sh
make                     # build Riff.app
make open                # build and launch Riff.app
make install             # install to ~/Applications/Riff.app
swift test               # run RiffCoreTests
```

- `RiffCore` — pure logic (orchestrator, stores, parsers, runtime adapters). Fully unit-tested.
- `RiffApp` — SwiftUI shell. `RootView` is a three-column `NavigationSplitView`; `AppModel` is the `@MainActor` glue.

## Config Locations

| Path | Purpose |
|------|---------|
| `~/.riff/config/base_prompt.md` | Baseline prompt prepended to every agent's first turn |
| `~/.riff/config/runtime.json` | CLI search path overrides |
| `~/.riff/config/recent-conversations.json` | Sidebar history |
| `~/.riff/conversations/<uuid>/` | Default conversation root |

Pre-`71a0257` installations using `~/.riff/configs/prompt.md` are migrated automatically on first launch.

---

> Personal hack — a UI for watching two CLIs argue. Feel free to fork and adapt.
