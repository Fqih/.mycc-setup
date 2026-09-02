# Contributing

Single-author repo (Fqih / mhmdfkih21@gmail.com). No Claude co-author. No "Generated with" footer.

## Commit message convention

Format: `<type>(<scope>): <subject>`

### Types

| Type | Use for |
|---|---|
| `feat` | New skill, command, agent, hook, or capability |
| `fix` | Bug fix in hooks, scripts, or config |
| `refactor` | Reorganize without behavior change |
| `docs` | README, CONTRIBUTING, or doc-only edits |
| `test` | Add or modify tests |
| `chore` | Maintenance, deps, cleanup |
| `perf` | Performance improvements |
| `ci` | CI/CD, hooks automation |

### Scopes

| Scope | Covers |
|---|---|
| `skills` | Anything under `skills/` |
| `commands` | Anything under `commands/` |
| `hooks` | Anything under `hooks/` |
| `rules` | Anything under `rules/` |
| `agents` | Anything under `agents/` |
| `repo` | Repo-level: README, LICENSE, .gitignore, .gitleaks.toml |
| `docs` | General documentation |
| `ci` | CI/CD workflows |

### Subject rules

- Max 72 characters total
- Imperative mood ("add" not "added")
- Lowercase after the colon
- No trailing period
- Be specific: prefer "add rag-patterns skill" over "update skills"

### Body rules

- Wrap at 72 characters per line
- Blank line between subject and body
- Use bullet points for lists (start with `-`)
- Explain *why*, not just *what* (the diff shows what)

### Examples

```
feat(skills): add document-intelligence

PDF/Word/Universal reader with PyMuPDF + python-docx + pypandoc.
Covers extract, summarize, chunk, cite patterns.
Local-first by default — no cloud upload.

Refs: user request for PDF/Word reading capability.
```

```
fix(hooks): correct push guard logic

Old logic blocked all pushes after first commit.
Now detects true non-fast-forward only.
Force push still allowed via explicit --force flag.
```

```
docs(repo): add description and topics

About: Fqih's personal Claude Code setup.
Topics: claude-code, ai-tools, ai-engineer, data-science,
rag, mlops, productivity, developer-tools, claude.
```

## Pre-commit checklist

Before commit, verify:

- [ ] `git config user.name` → `Fqih`
- [ ] `git config user.email` → `mhmdfkih21@gmail.com`
- [ ] No Claude/Anthropic co-author in staged content
- [ ] No "Generated with Claude Code" tagline
- [ ] Gitleaks scan clean (`/secret-scan` or auto via hook)
- [ ] Ruff lint + format pass (Python files)
- [ ] nbstripout run on `.ipynb` files

## Pre-push checklist

- [ ] Remote points to `https://github.com/Fqih/<repo>.git` (not school alias)
- [ ] Not force-pushing to `main`/`master`
- [ ] Full history gitleaks scan clean

## Identity rules (per CLAUDE.md)

- Display name: `Fqih`
- Email: `mhmdfkih21@gmail.com`
- GitHub: `Fqih` (capital F)
- NO `Co-Authored-By:` trailer of any kind
- NO `🤖 Generated with [Claude Code]` line

Forbidden identifiers (auto-rejected):
- `faqihhakim` (any case)
- `fqihhakim@student.gunadarma.ac.id`
- `faqihhakim@users.noreply.github.com`
