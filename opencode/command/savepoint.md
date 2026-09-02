---
description: Save session state with git tag + stash for later resume
---

Create a recoverable checkpoint of current work:

```bash
# 1. ensure everything is committed
git add -A
git commit -m "savepoint: $(date -u +%Y-%m-%dT%H:%M:%SZ)" --allow-empty

# 2. stash any uncommitted (if step 1 produced empty commit)
git stash push -u -m "savepoint $(date -u +%H:%M)" 2>/dev/null || true

# 3. tag the state
TAG="savepoint-$(date -u +%Y%m%d-%H%M%S)"
git tag -a "$TAG" -m "manual savepoint"

echo "savepoint created: $TAG"
echo "to restore: git checkout $TAG  (or  git stash pop  for stashed uncommitted)"
```

Use at end of session (or hourly on overnight runs) so you can `git checkout savepoint-XXX` to recover.
