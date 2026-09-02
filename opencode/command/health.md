---
description: Project health check (git, tests, MCP, cost)
---

Run a project health snapshot.

```bash
echo "=== git status ==="
git status --short --branch
echo
echo "=== today tests ==="
TODAY=$(date -u +%Y-%m-%d)
grep -c "PASS" ~/.local/share/opencode/test-runs.log 2>/dev/null | xargs -I{} echo "PASS total: {}"
grep "$TODAY" ~/.local/share/opencode/test-runs.log 2>/dev/null | grep -c PASS | xargs -I{} echo "PASS today: {}"
grep "$TODAY" ~/.local/share/opencode/test-runs.log 2>/dev/null | grep -c FAIL | xargs -I{} echo "FAIL today: {}"
echo
echo "=== today cost (paid models) ==="
TODAY=$(date -u +%Y-%m-%d)
awk -v today="$TODAY" '$0 ~ today && /cost=/ {match($0, /cost=\$([0-9.]+)/, m); s+=m[1]} END {printf "today: $%.4f\n", s+0}' ~/.local/share/opencode/cost-tracker.log 2>/dev/null
echo
echo "=== compactions today ==="
TODAY=$(date -u +%Y-%m-%d)
grep "$TODAY" ~/.local/share/opencode/session-tracker.log 2>/dev/null | grep -c compaction | xargs -I{} echo "compactions: {}"
echo
echo "=== MCP servers ==="
ls ~/.local/share/opencode/auth.json 2>/dev/null > /dev/null && echo "credentials file: present" || echo "credentials: missing"
opencode providers list 2>/dev/null | grep -E '●' | head -5
```

Output interpretation:
- `git status`: uncommitted files, branch sync state
- tests today: how many pass/fail
- cost today: cumulative paid-model cost (excludes $0 subscription)
- compactions today: how many times context was auto-compacted
