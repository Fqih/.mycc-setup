#!/usr/bin/env bash
# Pre-commit hook: identity check + gitleaks scan + ruff lint
# Symlink atau copy ke .git/hooks/pre-commit di setiap repo
#
# Install per repo:
#   ln -sf ~/.claude/hooks/pre-commit.sh .git/hooks/pre-commit

set -e

# ============================================================
# 1. Identity check
# ============================================================
EXPECTED_NAME="Fqih"
EXPECTED_EMAIL="mhmdfkih21@gmail.com"

ACTUAL_NAME=$(git config user.name || echo "")
ACTUAL_EMAIL=$(git config user.email || echo "")

if [ "$ACTUAL_NAME" != "$EXPECTED_NAME" ]; then
    echo "BLOCKED: git user.name='$ACTUAL_NAME', expected '$EXPECTED_NAME'"
    echo "Fix: git config --global user.name \"$EXPECTED_NAME\""
    exit 1
fi

if [ "$ACTUAL_EMAIL" != "$EXPECTED_EMAIL" ]; then
    echo "BLOCKED: git user.email='$ACTUAL_EMAIL', expected '$EXPECTED_EMAIL'"
    echo "Fix: git config --global user.email \"$EXPECTED_EMAIL\""
    exit 1
fi

# ============================================================
# 2. Block Claude / Anthropic co-author trailers di staged content
# (proper trailer format: leading "Co-Authored-By:" + name with Claude/Anthropic)
# ============================================================
if git diff --cached | grep -qiE "^Co-Authored-By:.*(Claude|Anthropic|noreply@anthropic)"; then
    echo "BLOCKED: Claude/Anthropic co-author trailer detected"
    echo "Per CLAUDE.md rule, commits must be single-author (Fqih only)"
    exit 1
fi

# Generated tagline: must be at line start + standalone (avoid matching docs that quote the string as anti-pattern)
if git diff --cached | grep -qE "^🤖 Generated with \[Claude Code\]"; then
    echo "BLOCKED: 'Generated with Claude Code' tagline at line start (looks like real commit footer)"
    exit 1
fi

# ============================================================
# 3. Gitleaks scan (detect mode, --no-git workaround untuk v8 bug)
# ============================================================
GITLEAKS="${HOME}/.local/bin/gitleaks"
if [ ! -x "$GITLEAKS" ]; then
    echo "WARNING: gitleaks not found at $GITLEAKS — skipping secret scan"
    echo "Install: see ~/.claude/skills/secret-scan/SKILL.md"
else
    CONFIG_FLAG=""
    if [ -f ".gitleaks.toml" ]; then
        CONFIG_FLAG="--config .gitleaks.toml"
    fi

    # v8 detect doesn't support --staged; use --pipe against cached diff
    if ! git diff --cached | "$GITLEAKS" detect \
        --no-git \
        --pipe \
        $CONFIG_FLAG \
        --exit-code 2 \
        --redact 2>/dev/null; then
        echo ""
        echo "BLOCKED: Secret detected in staged files"
        echo "Rotate the leaked credential immediately, then replace with env var"
        echo "See ~/.claude/skills/secret-scan/SKILL.md"
        exit 1
    fi
fi

# ============================================================
# 4. Ruff lint + format check (Python only)
# ============================================================
STAGED_PY=$(git diff --cached --name-only --diff-filter=ACM | grep '\.py$' || true)
if [ -n "$STAGED_PY" ] && command -v ruff &>/dev/null; then
    if ! ruff check $STAGED_PY 2>/dev/null; then
        echo "BLOCKED: ruff lint errors"
        echo "Fix: ruff check --fix $STAGED_PY"
        exit 1
    fi

    if ! ruff format --check $STAGED_PY 2>/dev/null; then
        echo "BLOCKED: ruff format errors"
        echo "Fix: ruff format $STAGED_PY"
        exit 1
    fi
fi

# ============================================================
# 5. nbstripout untuk staged notebook
# ============================================================
STAGED_IPYNB=$(git diff --cached --name-only --diff-filter=ACM | grep '\.ipynb$' || true)
if [ -n "$STAGED_IPYNB" ] && command -v nbstripout &>/dev/null; then
    for nb in $STAGED_IPYNB; do
        nbstripout "$nb"
        git add "$nb"
    done
fi

exit 0
