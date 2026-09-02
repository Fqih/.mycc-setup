---
description: List available skills (opencode reads ~/.claude/skills)
---

List all skills opencode can load:

```bash
ls ~/.claude/skills/ 2>/dev/null | while read d; do
  if [ -f ~/.claude/skills/"$d"/SKILL.md ]; then
    name=$(grep -m1 '^name:' ~/.claude/skills/"$d"/SKILL.md | sed 's/name:[[:space:]]*//')
    desc=$(grep -m1 '^description:' ~/.claude/skills/"$d"/SKILL.md | sed 's/description:[[:space:]]*//' | head -c 80)
    printf "%-30s %s\n" "${name:-$d}" "$desc..."
  fi
done
```

Trigger a skill by name (opencode auto-matches keywords in the description):

> Use the `tdd-workflow` skill when writing tests first
