---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git commit:*)
description: Create a git commit (single-author, no Claude attribution per CLAUDE.md)
---

## Context

- Current git status: !`git status`
- Current git diff (staged and unstaged changes): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -10`

## Identity verification (WAJIB)

Sebelum commit, verify git identity:

```bash
git config user.name   # HARUS: Fqih
git config user.email  # HARUS: mhmdfkih21@gmail.com
```

Kalau salah, stop. Fix dengan `git config --global user.{name,email}` lalu retry.

## Your task

Based on the above changes, create a single git commit.

**Rules (per ~/.claude/CLAUDE.md):**
- Single-author only. NO `Co-Authored-By:` trailer of any kind.
- NO `🤖 Generated with [Claude Code]` tagline.
- Conventional commit format: `<type>: <subject>` — types: feat, fix, refactor, docs, test, chore, perf, ci.
- Subject max 72 chars, body wrap 72 chars.
- Imperative mood ("add" not "added").

**Pre-commit hook akan block commit kalau:**
- Identity salah
- Ada Claude/Anthropic co-author di staged content
- Gitleaks detect secret
- Ruff lint/format errors (Python files)

Stage dan create commit dalam satu message. Do not use other tools or do anything else. Do not send any other text besides tool calls.
