# opencode setup

Personal opencode config on dedicated branch `opencode`.

## Layout

```
opencode/
├── opencode.jsonc   # global config
├── agent/           # 9 subagent (migrated from Claude Code)
├── command/         # 25 slash commands (migrated from Claude Code)
└── README.md
```

## Role to model

| Agent | Model | Provider |
|---|---|---|
| `build` (default) | `minimax-coding-plan/MiniMax-M3` | MiniMax (free) |
| `plan` | `minimax-coding-plan/MiniMax-M3` | MiniMax (free) |
| `pm` | `minimax-coding-plan/MiniMax-M3` | MiniMax (free) |
| `coder` | `openrouter/qwen/qwen3.8-27b` | OpenRouter (paid, reasoning capped 2k) |
| `coder-minimax` | `minimax-coding-plan/MiniMax-M2.7` | MiniMax (free) |
| `coder-deepseek` | `deepseek/deepseek-v4-flash` | DeepSeek ($0.14/M, fallback) |
| `general` | `minimax-coding-plan/MiniMax-M2.7-highspeed` | MiniMax (free) |
| `explore` | `minimax-coding-plan/MiniMax-M2.7-highspeed` | MiniMax (free) |
| `reviewer` | `minimax-coding-plan/MiniMax-M2.7-highspeed` | MiniMax (free) |
| `title`, `summary` | `minimax-coding-plan/MiniMax-M2.7-highspeed` | MiniMax (free) |
| `copilot-free` | `github-copilot/gpt-4.1` | GitHub Copilot (free) |
| `local-coder` | `ollama/qwen2.5-coder:7b-ctx` | Ollama (local, free) |
| `local-general` | `ollama/qwen3.5:9b-ctx` | Ollama (local, free) |

Qwen is the code specialist, invoked on demand by `build` or `pm`. Routine code stays on `coder-minimax`. If MiniMax is rate-limited, fallback is `coder-deepseek`.

## Compaction

`auto: true`, `tail_turns: 15`, `preserve_recent_tokens: 200000`, `prune: true`, `reserved: 12000`. `small_model` is `ollama/qwen3.5:9b-ctx` so summarization is free.

## Token saving (no accuracy loss)

- Caveman-style prompts: terse, no greeting, no recap, bullets only
- `tool_output.max_lines: 120`, `max_bytes: 6144`
- `security.md` loaded via `references.security-rules`, not auto-injected
- `experimental.primary_tools` restricted to six core tools

## Overnight workflow

See `rules/performance.md` in the main repo. Plugin `~/.config/opencode/plugin/tg-track.ts` logs compactions and chats to `~/.local/share/opencode/session-tracker.log` and sends Telegram on each compaction.

## Project setup

For each project, create an `AGENTS.md` at the project root with stack, conventions, test commands, and local dev steps. opencode reads `AGENTS.md` automatically. Use `/init-project` to scaffold.

## Commands

- `/init-project`: scaffold project context (`AGENTS.md`)
- `/daily-summary`: show today's compactions, messages, test pass/fail counts
- `/track`: tail session-tracker log
- `/commit`, `/commit-push-pr`: git workflow with pre-commit tests

## Plugins

`~/.config/opencode/plugin/tg-track.ts`:

- sends Telegram on each compaction event
- runs project tests on `git commit`, sends pass/fail to Telegram
- logs compactions, messages, and test runs to `~/.local/share/opencode/`

## MCP

- `filesystem` and `playwright` enabled by default
- `jupyter`, `github`, `postgres` lazy (`enabled: false`); enable via `/mcp` after providing credentials
- credentials via env: `{env:GITHUB_TOKEN}` for GitHub, `{env:DATABASE_URI}` for Postgres

## Install on a new device

1. Clone and checkout branch:

```bash
git clone -b opencode https://github.com/Fqih/.mycc-setup.git ~/.mycc-setup
```

2. Sync config:

```bash
mkdir -p ~/.config/opencode/{agent,command}
cp ~/.mycc-setup/opencode/opencode.jsonc ~/.config/opencode/opencode.jsonc
cp ~/.mycc-setup/opencode/agent/*.md ~/.config/opencode/agent/
cp ~/.mycc-setup/opencode/command/*.md ~/.config/opencode/command/
```

3. Sync skills (opencode reads `~/.claude/skills`):

```bash
mkdir -p ~/.claude/skills
cp -r ~/.mycc-setup/skills/* ~/.claude/skills/
```

4. Ollama num_ctx variants:

```bash
ollama create qwen2.5-coder:7b-ctx -f - <<'EOF'
FROM qwen2.5-coder:7b
PARAMETER num_ctx 32768
EOF
ollama create qwen3.5:9b-ctx -f - <<'EOF'
FROM qwen3.5:9b
PARAMETER num_ctx 32768
EOF
```

5. Ollama service override:

```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null <<'EOF'
[Service]
Environment="OLLAMA_NUM_PARALLEL=1"
Environment="OLLAMA_KEEP_ALIVE=10m"
EOF
sudo systemctl daemon-reload && sudo systemctl restart ollama
```

6. Restart opencode.

## Manual setup

- `mcp.github.environment.GITHUB_PERSONAL_ACCESS_TOKEN`: replace with a real PAT, or set `enabled: false`
- `mcp.postgres.environment.DATABASE_URI`: replace with a real URI, or set `enabled: false`
- `GITHUB_TOKEN` env var required for GitHub Copilot provider

## Commit rules

- `user.name` = `Fqih`, `user.email` = `mhmdfkih21@gmail.com`
- No `Co-Authored-By:` trailer, no `Generated with [Claude Code]` footer
- Subject max 72 chars, imperative mood, no emoji
- See `rules/git-workflow.md` for the full style guide
