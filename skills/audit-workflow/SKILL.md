---
name: audit-workflow
description: Use when ending a sprint/cycle — run comprehensive code audit (security, quality, tests, dead code, deps, docs) and post findings as GitHub issues for next-cycle pickup. Trigger on "audit", "sprint review", "end of cycle", "/audit-end-sprint".
---

# audit-workflow

Comprehensive audit methodology untuk end-of-sprint. Generate GitHub issues per finding — next sprint langsung ada backlog.

## Filosofi

Audit = "cermin" bukan "penilaian". Tujuannya:
1. Temukan apa yang luput dari sprint ini
2. Buat visibility untuk next-cycle planning
3. Track debt accumulation
4. Bukan gate — selesai sprint bukan berarti harus fix semua

## Dimensi audit

| Dimensi | Cek | Tool |
|---|---|---|
| **Security** | Leaked secrets, vuln deps, auth issues | gitleaks, pip-audit, npm audit, security-reviewer agent |
| **Code quality** | Lint, type, complexity | ruff, mypy, radon, lizard |
| **Test coverage** | % covered, gap areas | pytest --cov, nyc, istanbul |
| **Dead code** | Unused imports, vars, branches, exports | vulture, knip, ts-prune |
| **TODO/FIXME** | Accumulated tech debt | `git grep -nE "TODO\|FIXME\|XXX\|HACK"` |
| **Performance** | N+1 queries, slow paths | py-spy, cProfile, EXPLAIN ANALYZE |
| **Docs drift** | Code vs README mismatch | grep for documented-but-missing APIs |
| **Dependency freshness** | Outdated, deprecated, EOL | pip list --outdated, npm outdated, cargo update |
| **Git hygiene** | Large files, secrets in history | gitleaks detect --source, repo size check |

## Sprint audit template

Run these checks. Each finding → 1 issue.

### 1. Security sweep

```bash
# Secrets (staged + working tree)
~/.local/bin/gitleaks detect --no-git --source . --config .gitleaks.toml \
    --exit-code 2 --redact -v

# Python deps vuln
pip-audit --strict --requirement requirements.txt 2>/dev/null || true

# Node deps vuln (kalau ada)
npm audit --audit-level=moderate 2>/dev/null || true

# OWASP quick check via security-reviewer agent (lihat subagents)
```

Findings → issues dengan label `security`, `audit-sprint-YYYY-MM-DD`.

### 2. Quality sweep

```bash
# Python
ruff check . --statistics
mypy src/ --strict 2>&1 | tail -50
radon cc src/ -s -n C  # complexity, find C+ functions
radon mi src/ -s -n B  # maintainability index, find B- modules

# TypeScript / JS
npx eslint . --max-warnings=0 2>/dev/null || true
npx tsc --noEmit 2>/dev/null || true
```

Findings → issues label `quality`, `audit-sprint-YYYY-MM-DD`.

### 3. Test coverage

```bash
pytest --cov=src --cov-report=term-missing --cov-fail-under=80 2>/dev/null || true

# Identify files < 80% coverage
coverage report | grep -E "^[^-].*[0-9]+%" | awk '$NF+0 < 80 {print}'
```

Findings → issues label `test-coverage`, `audit-sprint-YYYY-MM-DD`.

### 4. Dead code

```bash
# Python
vulture src/ --min-confidence 80

# JavaScript / TypeScript
npx knip 2>/dev/null || true
npx ts-prune 2>/dev/null || true

# Unused exports across all
git ls-files | xargs grep -lE "^export " | xargs grep -c "import" | sort -t: -k2 -n
```

Findings → issues label `dead-code`, `audit-sprint-YYYY-MM-DD`.

### 5. TODO/FIXME accumulation

```bash
git grep -nE "TODO|FIXME|XXX|HACK" -- '*.py' '*.ts' '*.tsx' '*.js' '*.go' '*.rs'
```

Group by file. Too many TODOs in one file → 1 issue: "refactor N TODOs out of `<file>`". Few TODOs scattered → 1 issue per significant TODO.

Label: `tech-debt`, `audit-sprint-YYYY-MM-DD`.

### 6. Performance hotspots

```bash
# Python profiling samples
py-spy record -o profile.svg -- python -m mymodule 2>/dev/null || true

# DB query audit (kalau ada ORM)
grep -rnE "\.all\(\)|for .* in .*\.objects" src/ | head -20

# Look for N+1 patterns
grep -rn "for .* in .*:" src/ | grep -v "test" | head -30
```

Label: `performance`, `audit-sprint-YYYY-MM-DD`.

### 7. Doc drift

```bash
# Functions documented di README tapi tidak exist di code
grep -oE "[a-z_][a-z0-9_]*\(\)" README.md docs/*.md 2>/dev/null | sort -u > /tmp/doc-refs.txt

# Functions defined di code
grep -roE "^(def|async def|function|export function) [a-z_][a-z0-9_]*" src/ | awk '{print $NF}' | sed 's/(.*//' | sort -u > /tmp/code-defs.txt

# Doc references yang missing di code
comm -23 /tmp/doc-refs.txt /tmp/code-defs.txt
```

Label: `docs`, `audit-sprint-YYYY-MM-DD`.

### 8. Dependency freshness

```bash
# Python
pip list --outdated --format=columns

# Node
npm outdated 2>/dev/null || true

# Cargo
cargo outdated 2>/dev/null || true
```

Critical (security CVEs, EOL) → issues with `priority:critical` or `priority:high`. Minor → 1 grouped issue.

Label: `deps`, `audit-sprint-YYYY-MM-DD`.

### 9. Git hygiene

```bash
# Large files (>1MB)
find . -type f -size +1M -not -path "./.git/*" -not -path "./node_modules/*" -not -path "./.venv/*" 2>/dev/null

# Secrets in history (full scan)
~/.local/bin/gitleaks detect --source . --config .gitleaks.toml \
    --exit-code 2 --redact 2>&1 | tail -10

# Repo size
du -sh .git/ 2>/dev/null
```

Label: `git-hygiene`, `audit-sprint-YYYY-MM-DD`.

## Issue template

```markdown
## [audit-sprint-YYYY-MM-DD] <finding title>

**Category**: security | quality | test-coverage | dead-code | tech-debt | performance | docs | deps | git-hygiene
**Severity**: critical | high | medium | low
**Location**: `<file>:<line>` atau `<module>`

### Observation
<apa yang salah / apa yang missing>

### Why it matters
<impact kalau dibiarin>

### Suggested fix
<concrete steps atau reference ke skill yang relevan>

### Acceptance criteria
- [ ] Specific measurable outcome

---
Auto-generated by `audit-end-sprint` skill on YYYY-MM-DD.
Sprint window: <start-date> → <end-date>
```

## Issue posting

Post via `gh` CLI:

```bash
gh issue create \
    --title "[audit-sprint-$(date +%Y-%m-%d)] <finding title>" \
    --label "audit,audit-sprint-$(date +%Y-%m-%d),<category>,<severity>" \
    --body "<issue body>"
```

Bulk post:
```bash
while IFS= read -r finding; do
    title=$(echo "$finding" | head -1)
    body=$(echo "$finding" | tail -n +2)
    gh issue create \
        --title "[audit-sprint-$(date +%Y-%m-%d)] $title" \
        --label "audit,audit-sprint-$(date +%Y-%m-%d),${CATEGORY:-quality}" \
        --body "$body"
done < /tmp/audit-findings.txt
```

## Sprint tracking

Tambahkan label per sprint agar mudah filter:
- `audit-sprint-2026-09-02` (this sprint)
- `audit-sprint-2026-09-16` (next)

View all open issues per sprint:
```bash
gh issue list --label "audit-sprint-$(date +%Y-%m-%d)" --state all
```

Close old sprint issues when next sprint starts (atau biarkan untuk history).

## Cadence

| Sprint length | Audit frequency |
|---|---|
| 1 week | Daily quick check, weekly full audit |
| 2 weeks | Mid-sprint quick, end full audit |
| 1 month | Weekly quick, monthly full audit |
| Ad-hoc | After major feature merge |

Quick check = security + lint + tests (~5 min).
Full audit = all 9 dimensions (~30-60 min, mostly automated).

## Stop hook reminder (optional)

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "if [ -d .git ] && [ $(git rev-list --since='7 days ago' HEAD | wc -l) -gt 20 ]; then echo '💡 20+ commits in last 7 days — consider /audit-end-sprint'; fi"
      }]
    }]
  }
}
```

Reminds when many commits accumulated since last audit.

## Anti-patterns

❌ **Audit tanpa action**: kalau cuma write ke file lokal, bukan ke issue, akan hilang
❌ **Audit setiap hari**: noise, jadi ignored
❌ **Bulk close old issues tanpa review**: kehilangan history + signal
❌ **Single mega-issue per audit**: susah track, susah close sebagian
❌ **Skip security dimension**: paling bahaya kalau lewat
❌ **Audit tanpa skill/agent delegation**: max 30 min, kalau lebih = scope creep

## Invokation

Auto-trigger:
- User sebut "audit", "end of sprint", "review"
- Stop hook detects high commit count
- Slash command: `/audit-end-sprint`
