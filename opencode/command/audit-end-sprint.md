---
description: End-of-sprint code audit — run 9-dimension sweep (security, quality, tests, dead code, TODO/FIXME, perf, docs, deps, git hygiene) and post each finding as GitHub issue.
---

Run full audit, post findings as GitHub issues. Default sprint window = since last audit (atau last 7 days kalau first time).

## Usage

```
/audit-end-sprint [--window 14d] [--repo <owner/repo>] [--dry-run]
```

Examples:
```
/audit-end-sprint                    # last 7 days, current repo
/audit-end-sprint --window 14d       # last 14 days
/audit-end-sprint --repo Fqih/.mycc-setup
/audit-end-sprint --dry-run          # don't post, just preview
```

## Step 1: Verify gh + repo

```bash
gh auth status 2>&1 | grep -q "Logged in" || { echo "gh not authed"; exit 1; }

REPO="${REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
SPRINT_LABEL="audit-sprint-$(date +%Y-%m-%d)"
echo "Auditing: $REPO"
echo "Sprint label: $SPRINT_LABEL"
```

## Step 2: Detect sprint window

```bash
WINDOW_DAYS="${WINDOW_DAYS:-7}"
SPRINT_START=$(date -d "$WINDOW_DAYS days ago" +%Y-%m-%d)
SPRINT_END=$(date +%Y-%m-%d)
echo "Window: $SPRINT_START → $SPRINT_END"
```

## Step 3: Run audit dimensions

Create work dir untuk findings:

```bash
WORK=$(mktemp -d)
echo "Workdir: $WORK"
```

### Security
```bash
echo "=== SECURITY ===" | tee "$WORK/01-security.md"

# Secrets
~/.local/bin/gitleaks detect --no-git --source . --config .gitleaks.toml \
    --redact -v 2>&1 | tail -20 | tee -a "$WORK/01-security.md"

# Vuln deps
echo "--- pip-audit ---" >> "$WORK/01-security.md"
pip-audit --strict 2>&1 | tail -10 >> "$WORK/01-security.md" || true
```

### Quality
```bash
echo "=== QUALITY ===" > "$WORK/02-quality.md"
echo "--- ruff ---" >> "$WORK/02-quality.md"
ruff check . --statistics 2>&1 | tail -30 >> "$WORK/02-quality.md"
echo "--- mypy ---" >> "$WORK/02-quality.md"
mypy src/ 2>&1 | tail -20 >> "$WORK/02-quality.md" || true
```

### Test coverage
```bash
echo "=== TEST COVERAGE ===" > "$WORK/03-coverage.md"
pytest --cov=src --cov-report=term --cov-fail-under=0 2>&1 | tail -30 >> "$WORK/03-coverage.md" || true
```

### Dead code
```bash
echo "=== DEAD CODE ===" > "$WORK/04-deadcode.md"
vulture src/ --min-confidence 80 2>&1 | head -30 >> "$WORK/04-deadcode.md" || true
```

### TODO/FIXME
```bash
echo "=== TECH DEBT ===" > "$WORK/05-todo.md"
git grep -nE "TODO|FIXME|XXX|HACK" -- '*.py' '*.ts' '*.tsx' '*.js' 2>/dev/null | head -30 >> "$WORK/05-todo.md"
```

### Performance
```bash
echo "=== PERFORMANCE ===" > "$WORK/06-perf.md"
grep -rn "for .* in .*:" src/ 2>/dev/null | grep -v test | head -15 >> "$WORK/06-perf.md"
echo "--- N+1 candidates ---" >> "$WORK/06-perf.md"
grep -rn "\.all()" src/ 2>/dev/null | head -10 >> "$WORK/06-perf.md"
```

### Docs drift
```bash
echo "=== DOCS DRIFT ===" > "$WORK/07-docs.md"
grep -oE "[a-z_][a-z0-9_]*\(\)" README.md 2>/dev/null | sort -u > /tmp/doc-refs.txt || true
grep -roE "^def [a-z_][a-z0-9_]*" src/ 2>/dev/null | awk '{print $2}' | sed 's/(.*//' | sort -u > /tmp/code-defs.txt || true
echo "Doc refs missing in code:" >> "$WORK/07-docs.md"
comm -23 /tmp/doc-refs.txt /tmp/code-defs.txt 2>/dev/null | head -15 >> "$WORK/07-docs.md"
```

### Deps
```bash
echo "=== DEPS ===" > "$WORK/08-deps.md"
echo "--- outdated pip ---" >> "$WORK/08-deps.md"
pip list --outdated --format=columns 2>&1 | head -20 >> "$WORK/08-deps.md" || true
```

### Git hygiene
```bash
echo "=== GIT HYGIENE ===" > "$WORK/09-githygiene.md"
echo "--- large files (>1MB) ---" >> "$WORK/09-githygiene.md"
find . -type f -size +1M -not -path "./.git/*" -not -path "./node_modules/*" -not -path "./.venv/*" 2>/dev/null | head -10 >> "$WORK/09-githygiene.md"
echo "--- gitleaks history ---" >> "$WORK/09-githygiene.md"
~/.local/bin/gitleaks detect --source . --config .gitleaks.toml --redact 2>&1 | tail -10 >> "$WORK/09-githygiene.md" || true
```

## Step 4: Parse findings → issue list

```bash
cat > /tmp/audit-findings.txt <<'EOF'
[security][high] Leaked OpenAI key di src/config.py line 12
[quality][medium] mypy errors di src/avo/state.py
[quality][low] 12 ruff unused-import warnings
[test-coverage][high] src/avo/app_tools/sandbox.py only 47% covered
[tech-debt][low] 23 TODOs in src/avo/runtime.py — refactor pass needed
[perf][medium] N+1 di src/api/users.py:list_users()
[docs][low] README references removed function `parse_legacy_format`
[deps][medium] pydantic 2.5 outdated (latest 2.9)
[git-hygiene][info] .git size 450MB — large blobs check recommended
EOF
```

Adjust this based on actual $WORK/* output.

## Step 5: Post issues (skip kalau --dry-run)

```bash
if [ "${DRY_RUN:-false}" = "true" ]; then
    echo "DRY RUN — preview only, no issues posted"
    cat /tmp/audit-findings.txt
    exit 0
fi

while IFS='|' read -r category severity title; do
    # Strip brackets
    cat=$(echo "$category" | tr -d '[]')
    sev=$(echo "$severity" | tr -d '[]')
    title_clean=$(echo "$title" | sed 's/^ *//')

    body="## [$SPRINT_LABEL] $title_clean

**Category**: $cat
**Severity**: $sev
**Sprint window**: $SPRINT_START → $SPRINT_END
**Repo**: $REPO

### Observation
Detected by \`/audit-end-sprint\` automation.

### Suggested fix
See skill \`audit-workflow\` for dimension-specific remediation.

### Acceptance criteria
- [ ] Finding verified and either fixed or explicitly deferred with rationale.

---
Auto-generated by audit-end-sprint."

    gh issue create \
        --repo "$REPO" \
        --title "[$SPRINT_LABEL] $title_clean" \
        --label "$SPRINT_LABEL,audit,$cat,$sev" \
        --body "$body" 2>&1 | tail -3
done < /tmp/audit-findings.txt
```

## Step 6: Summary

```bash
echo "=== AUDIT COMPLETE ==="
echo "Sprint: $SPRINT_LABEL"
echo "Issues posted to: $REPO"
echo "View: gh issue list --repo $REPO --label $SPRINT_LABEL"
echo ""
echo "Cleanup workdir: $WORK (auto-deleted on shell exit)"
```

## Notes

- First time run: butuh `--window 30d` atau lebih untuk baseline
- Kalau `gh` belum authed: run `gh auth login` dulu
- Findings bisa di-tweak di `/tmp/audit-findings.txt` sebelum posting
- Sprint label format: `audit-sprint-YYYY-MM-DD`
- Old sprint labels biarkan untuk history; jangan bulk-close

Lihat skill `audit-workflow` untuk full methodology + per-dimension detail.
