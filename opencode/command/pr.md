---
description: Open a PR for the current branch (commit, push, gh pr create)
---

Open a PR for current work. Single message, no extra text.

## Steps

```bash
# verify identity (block if wrong)
test "$(git config user.name)" = "Fqih" || { echo "BLOCKED: git identity wrong"; exit 1; }

# ensure branch is not main/master
BR=$(git branch --show-current)
case "$BR" in main|master)
  echo "BLOCKED: on $BR; switch to a feature branch first"
  exit 1 ;;
esac

# commit any pending changes (use existing /commit style)
git status --short
git add -A
git commit -m "$(git log -1 --format=%s 2>/dev/null || echo 'wip')" --allow-empty || true

# push with upstream
git push -u origin "$BR" 2>&1 | tail -5

# create PR (gh CLI assumed installed and authenticated)
gh pr create --fill --base main 2>&1
```
