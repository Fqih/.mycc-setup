# Codex setup

Codex-native packaging for this repository. The repository root contains
`AGENTS.md`, and `.agents/skills` points at the shared skill catalog so Codex
can discover the workflows automatically when launched inside a checkout.

## What is included

- `AGENTS.md`: persistent repository instructions for Codex.
- `.agents/skills`: repository-discoverable skills from `skills/`.
- `config.toml.example`: safe user-level defaults for `~/.codex/config.toml`.
- `command-mapping.md`: mapping from legacy Claude slash commands to Codex
  prompts and skills.
- `install.sh` and `install.ps1`: install the shared skills and optional
  user-level Codex configuration on Linux/macOS or Windows.

## Install

From the repository root:

```bash
./codex/install.sh
```

The script copies skills to `~/.agents/skills` and creates
`~/.codex/config.toml` from the example only when that file does not already
exist. It never overwrites existing Codex configuration.

On Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\codex\install.ps1
```

Repository-scoped `AGENTS.md` remains in the checkout and is loaded when
Codex starts in this repository. User-level configuration is intentionally
kept generic; authentication, model providers, MCP servers, and tokens stay
machine-local.

## Verification

```bash
codex --version
codex mcp list
codex --ask-for-approval on-request --sandbox workspace-write
```

The last command starts an interactive session with the recommended approval
and sandbox defaults; stop it with `/exit` after verifying startup.
