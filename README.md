<div align="center">

# 🎸 Riff

**Multi-agent debates between local AI CLIs.**

*One window. Claude and Codex, taking turns, on disk.*

</div>

A native macOS app that runs Claude Code and Codex CLI side-by-side against the same prompt, rotates their turns, and stores everything as plain files — `conversation.json`, `transcript.jsonl`, and per-agent state under `agents/<id>/`. No database, no cloud, just files you can read, diff, and git track.

- **Three-pane SwiftUI window** — conversations sidebar, chat transcript, and a live file viewer for attachments
- **Round-robin debates** — agents take turns per round; configure how many rounds to run
- **File-backed** — every turn lands in `transcript.jsonl`, every attachment in `files/`
- **Resumable sessions** — per-agent CLI session IDs are persisted so each agent keeps its own context across turns
- **Markdown attachments** — agents write supporting detail to disk; the next agent reads them back as context
- **Live user injection** — type during a run; your message queues into the next iteration as a `user` turn
- **Runtime detection** — probes `claude` and `codex` on `$PATH` at startup, falls back to known model lists
- **Custom conversation roots** — keep a debate inside any folder you pick, or use the default `~/.riff/conversations/`

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

On first launch Riff writes defaults to `~/.riff/configs/`:

- `prompt.md` — the baseline instruction shared by every agent
- `agents.json` — agent profiles (default: a Claude advocate and a Codex critic)

Then click **New Conversation**, give it a title and a prompt, set rounds, hit **Start**.

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
        ├── session.json     # CLI session ID for resume
        └── cwd/             # the agent's working directory
```

Conversation roots live under `~/.riff/conversations/<uuid>/` unless you create one in a custom folder via the new-conversation sheet. Recent locations are remembered in `~/.riff/configs/recent-conversations.json`.

## How a Turn Works

For each turn the orchestrator:

1. Drains queued user messages and appends them to the transcript.
2. Picks the next agent in round-robin order.
3. Builds a prompt = baseline + conversation prompt + transcript so far.
4. Invokes the runtime CLI (`claude -p ...` or `codex exec ...`), passing `--resume`/`exec resume` when a session ID exists.
5. Parses the response, captures the new session ID, and detects any markdown files the agent wrote into `files/`.
6. Appends a `TranscriptEntry` to `transcript.jsonl` and writes the session back.

## Agents

Configure agents in `~/.riff/configs/agents.json`:

```json
[
  {
    "id": "claude-advocate",
    "name": "Claude Advocate",
    "role": "Advocate",
    "runtime": "claude",
    "model": "sonnet",
    "instructions": "Argue for the strongest version of the proposal..."
  },
  {
    "id": "codex-critic",
    "name": "Codex Critic",
    "role": "Critic",
    "runtime": "codex",
    "model": "default",
    "reasoning": "medium",
    "instructions": "Probe assumptions, implementation risk, and missing evidence..."
  }
]
```

| Field | Description |
|-------|-------------|
| `id` | Stable identifier — used as the directory name under `agents/` |
| `name` | Display name in the chat pane |
| `role` | Short role label, used in attachment filenames (`turn-003.critic.codex.md`) |
| `runtime` | `claude` or `codex` |
| `model` | `"default"` (let the CLI pick) or a specific model slug |
| `reasoning` | Codex-only: `low` / `medium` / `high` reasoning effort |
| `instructions` | Per-agent system prompt appended after the baseline |

## Baseline Prompt

`~/.riff/configs/prompt.md` is prepended to every turn. The default asks each agent for a ~280-word direct argument and tells them to write long appendices to the attachment path instead of pasting them into the chat bubble.

Edit it to change what "participating in a Riff debate" means for your agents.

## Runtimes

Riff probes for the CLIs at startup:

| Runtime | Binary | Detection |
|---------|--------|-----------|
| Claude Code | `claude` (or `openclaude`) | `claude --version`, static fallback model list |
| Codex CLI | `codex` | `codex --version` + `codex debug models` for live model list |

If a binary isn't on `$PATH`, that runtime shows as unavailable but its agents can still be configured. The "model" picker in the new-conversation sheet uses live results when available and falls back to a hand-curated list otherwise.

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
| `~/.riff/configs/prompt.md` | Baseline prompt prepended to every turn |
| `~/.riff/configs/agents.json` | Agent profiles |
| `~/.riff/configs/recent-conversations.json` | Sidebar history |
| `~/.riff/conversations/<uuid>/` | Default conversation root |

---

> Personal hack — a UI for watching two CLIs argue. Feel free to fork and adapt.
