---
description: Show today's session activity (compactions, messages, tests)
---

Today's session summary:

```bash
LOG=~/.local/share/opencode/session-tracker.log
TEST=~/.local/share/opencode/test-runs.log
TODAY=$(date -u +%Y-%m-%d)

echo "=== compactions today ==="
grep "$TODAY" "$LOG" 2>/dev/null | grep compaction | wc -l
echo "=== messages today ==="
grep "$TODAY" "$LOG" 2>/dev/null | grep "msg " | wc -l
echo "=== test runs today ==="
grep "$TODAY" "$TEST" 2>/dev/null | wc -l
echo "=== test pass / fail ==="
grep "$TODAY" "$TEST" 2>/dev/null | grep -c PASS
grep "$TODAY" "$TEST" 2>/dev/null | grep -c FAIL
echo "=== last 10 events ==="
tail -10 "$LOG" 2>/dev/null
echo "=== last 5 test runs ==="
tail -5 "$TEST" 2>/dev/null
```
