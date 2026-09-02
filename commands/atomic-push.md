---
description: Atomic commit + scan + push ke GitHub dengan identity check, ruff lint, gitleaks secret scan.
---

# /atomic-push

Atomic push: stage → identity check → ruff lint → gitleaks scan → commit → rebase → push.

Jalankan step berikut sebagai satu workflow atomik. Kalau ada yang fail, stop, jangan push.

## Step 1: Pre-flight checks

```bash
# Verify identity
git config user.name
git config user.email

# Both HARUS:
#   name:  Fqih
#   email: mhmdfkih21@gmail.com
```

Kalau salah, stop. Fix dengan:
```bash
git config --global user.name "Fqih"
git config --global user.email "mhmdfkih21@gmail.com"
```

## Step 2: Stage + scan staged content

```bash
git add -A
git status --short
```

## Step 3: Gitleaks scan (WAJIB)

```bash
# v8 detect tidak punya --staged; pakai --pipe dengan git diff
git diff --cached | ~/.local/bin/gitleaks detect \
  --no-git \
  --pipe \
  --config .gitleaks.toml \
  --redact \
  --exit-code 2 \
  -v
```

Kalau exit code ≠ 0, **STOP**. Ada secret leak. Jangan commit, jangan push. Show user output dan minta fix.

## Step 4: Ruff lint + format check (kalau Python files changed)

```bash
# Deteksi file Python yang changed
changed_py=$(git diff --cached --name-only --diff-filter=ACM | grep '\.py$' || true)

if [ -n "$changed_py" ]; then
    ruff check $changed_py
    ruff format --check $changed_py
fi
```

Kalau ada error, **STOP**. Fix dulu, atau `ruff check --fix` + `ruff format`.

## Step 5: Verify no Claude co-author di staged commit message

```bash
git diff --cached | grep -i "co-authored-by\|claude\|anthropic\|noreply@anthropic" && echo "FAIL: claude co-author detected" && exit 1 || echo "OK"
```

Kalau ada match, **STOP**. Edit commit message, hapus co-author trailer.

## Step 6: Commit

```bash
# Default message: kalau ada staged, generate dari diff
if [ -z "$(git diff --cached --name-only)" ]; then
    echo "Nothing to commit"
    exit 0
fi

# Generate conventional commit message dari staged files
type="feat"  # default; bisa "fix", "refactor", "docs", "chore"
scope=""
subject=""

# Quick heuristic
if git diff --cached --name-only | grep -q "^test"; then type="test"; fi
if git diff --cached --name-only | grep -q "^\.md\|^docs/"; then type="docs"; fi

# Subject dari user-provided $1 (kalau ada)
if [ -n "$1" ]; then
    subject="$1"
else
    # Auto-generate dari file changes
    changed=$(git diff --cached --name-only | head -3 | xargs -I{} basename {} | tr '\n' ',' | sed 's/,$//')
    subject="update $changed"
fi

msg="${type}: ${subject}"
git commit -m "$msg"
```

## Step 7: Pre-push hook runs

.git/hooks/pre-push sudah auto-run gitleaks detect + identity check via script di `~/.claude/hooks/`. Kalau hook fail, **STOP**.

## Step 8: Rebase + push

```bash
# Pull + rebase untuk avoid diverge
git fetch origin
current_branch=$(git branch --show-current)

if git rev-parse --verify "origin/$current_branch" >/dev/null 2>&1; then
    git rebase origin/$current_branch
fi

# Push
git push origin "$current_branch"
```

## Step 9: Notify (optional)

```bash
~/.local/bin/tg-notify "pushed $current_branch to $(git remote get-url origin)" || true
```

## Error recovery

| Fail | Action |
|---|---|
| Identity wrong | Re-set git config, retry from step 1 |
| Gitleaks leak | Edit file, replace secret dengan env var ref, retry from step 2 |
| Ruff error | Run `ruff check --fix` + `ruff format`, retry from step 2 |
| Co-author found | `git commit --amend -m "$new_msg"` (no Claude trailer), retry from step 7 |
| Push rejected | Likely non-fast-forward, `git pull --rebase` then retry step 8 |
| Hook fail | Read hook output, fix root cause, retry |

## Notes

- This workflow designed untuk single-author commits per CLAUDE.md
- No `Co-Authored-By:` trailer of any kind
- No `🤖 Generated with [Claude Code]` line
- Gitleaks runs in `--no-git` mode karena v8 `protect --staged` bug
