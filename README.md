# Riff

A native macOS app for multi-agent debates between local AI CLIs.

Riff runs Claude Code and Codex CLI side-by-side against the same prompt, takes their turns in sequence, and stores everything as plain files on disk — `conversation.json`, `transcript.jsonl`, and per-agent state under `agents/<id>/`. Each agent gets a working directory and can write markdown attachments that the next agent reads back as context.

- Three-pane SwiftUI window: conversations, chat transcript, file viewer
- Backed by `claude` and `codex` binaries on your `$PATH`
- Session IDs are persisted so each agent resumes its own CLI context across turns
- Conversations live in `~/.riff/conversations/` by default, or any folder you pick

## Install

Requires macOS 15+, Swift 6 toolchain (Xcode 16), and the CLIs you want to debate with: [Claude Code](https://docs.claude.com/en/docs/claude-code) and/or [Codex CLI](https://github.com/openai/codex).

```sh
git clone <repo-url> riff-swift
cd riff-swift
swift build -c release
.build/release/Riff
```

Or open `Package.swift` in Xcode and run the `Riff` scheme.

## Quick Start

1. Launch Riff. On first run it writes defaults to `~/.riff/configs/`:
   - `prompt.md` — the baseline instruction shared by every agent
   - `agents.json` — agent profiles (default: a Claude advocate and a Codex critic)
2. Click **New Conversation**, give it a title and a prompt, pick how many rounds to run.
3. Hit **Start**. Each agent takes a turn per round; the transcript streams into the chat pane and `transcript.jsonl`.
4. Type a follow-up at any time — it queues into the loop and lands as a `user` turn in the next iteration.

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

Conversation roots live under `~/.riff/conversations/<uuid>/` unless you create one in a custom folder via the new-conversation sheet.

## Config

`~/.riff/configs/prompt.md` is the baseline prompt prepended to every turn. Edit it to change what "participating in a Riff debate" means.

`~/.riff/configs/agents.json` is a list of agent profiles:

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

`runtime` is `claude` or `codex`. `model` is either `"default"` (let the CLI pick) or a specific model slug — Riff probes each binary at startup and falls back to a static list if discovery fails.

## How a Turn Works

For each turn the orchestrator:

1. Drains queued user messages and appends them to the transcript.
2. Picks the next agent in round-robin order.
3. Builds a prompt = baseline + conversation prompt + transcript so far.
4. Invokes the runtime CLI (`claude -p ...` or `codex exec ...`) with `--resume`/`exec resume` if a session ID exists.
5. Parses the response, captures the new session ID, and detects any markdown files the agent wrote into `files/`.
6. Appends a `TranscriptEntry` to `transcript.jsonl` and writes the session back.

Stop requests never interrupt an in-flight CLI turn — they take effect at the next turn boundary.

## Development

```sh
swift build              # debug build
swift test               # run RiffCoreTests
swift run Riff           # launch the app
```

`RiffCore` is pure logic (orchestrator, stores, parsers, runtime adapters) and is fully unit-tested. `RiffApp` is SwiftUI shell — `RootView` is a three-column `NavigationSplitView`, `AppModel` is the `@MainActor` glue.
