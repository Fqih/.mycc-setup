---
allowed-tools: Bash(git checkout:*), Bash(git branch:*), Bash(git add:*), Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git push:*), Bash(git commit:*), Bash(gh pr create:*)
description: Commit, push, and open a PR (single-author, no Claude attribution)
---

## Context

- Current git status: !`git status`
- Current git diff (staged and unstaged changes): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -10`

## Identity verification (WAJIB)

```bash
git config user.name   # HARUS: Fqih
git config user.email  # HARUS: mhmdfkih21@gmail.com
```

## Your task

Based on the above changes:

1. **Branch**: kalau di `main`/`master`, create feature branch `<type>/<short-desc>` (e.g., `feat/add-rag-pipeline`)
2. **Commit**: stage + create single commit, conventional format, **NO Claude co-author, NO Generated with Claude Code line**
3. **Push**: `git push -u origin <branch>`
4. **PR**: `gh pr create` dengan body yang include:
   - Summary (1-3 bullets)
   - Test plan checklist
   - **NO Claude attribution**

**Single-author only per CLAUDE.md.** Pre-commit + pre-push hooks enforce this.

Stage, commit, push, dan create PR dalam satu message. Do not use other tools. Do not send other text besides tool calls.
