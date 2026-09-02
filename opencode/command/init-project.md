---
description: Scaffold a new project with AGENTS.md and config
---

Create project context for opencode.

## Steps

1. Check current directory:
   ```bash
   pwd
   ```
2. Detect project type:
   - Python: `ls pyproject.toml setup.py requirements.txt 2>/dev/null`
   - TypeScript: `ls package.json tsconfig.json 2>/dev/null`
   - ML/Data: `ls *.ipynb 2>/dev/null`
3. Generate `AGENTS.md` (if absent) with sections:
   - Project name and one-line purpose
   - Tech stack
   - Conventions (Python -> ruff; TS -> eslint/prettier)
   - Test command (pytest / npm test / etc)
   - Local dev commands
4. Add `instructions` field to project's `opencode.json` (if present) or print recommended snippet.
5. Initial commit: `git add AGENTS.md && git commit -m "docs: add AGENTS.md with project context"`

## AGENTS.md template

```markdown
# <project-name>

<one-line purpose>

## Stack

- <runtime and frameworks>

## Conventions

- Python: ruff format + ruff check
- TypeScript: eslint + prettier
- Commits: conventional, no Co-Authored-By

## Test command

\`\`\`
<pytest | npm test | cargo test>
\`\`\`

## Local dev

\`\`\`
<dev server / build commands>
\`\`\`
```
