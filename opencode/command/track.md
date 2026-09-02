---
description: Show session tracking log (compactions + messages)
---

Run this to see session activity:

```
tail -n 50 ~/.local/share/opencode/session-tracker.log
```

Show summary:
```
echo "=== compaction events today ==="
grep "$(date +%Y-%m-%d)" ~/.local/share/opencode/session-tracker.log | grep compaction | wc -l
echo "=== total messages today ==="
grep "$(date +%Y-%m-%d)" ~/.local/share/opencode/session-tracker.log | grep "msg " | wc -l
echo "=== last 10 events ==="
tail -10 ~/.local/share/opencode/session-tracker.log
```
