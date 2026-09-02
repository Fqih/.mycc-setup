#!/usr/bin/env bash
# Pre-push hook: identity check + full history gitleaks scan + remote verify
# Symlink atau copy ke .git/hooks/pre-push di setiap repo
#
# Install per repo:
#   ln -sf ~/.claude/hooks/pre-push.sh .git/hooks/pre-push

set -e

# ============================================================
# 1. Identity check (final guard sebelum push)
# ============================================================
EXPECTED_NAME="Fqih"
EXPECTED_EMAIL="mhmdfkih21@gmail.com"

ACTUAL_NAME=$(git config user.name || echo "")
ACTUAL_EMAIL=$(git config user.email || echo "")

if [ "$ACTUAL_NAME" != "$EXPECTED_NAME" ] || [ "$ACTUAL_EMAIL" != "$EXPECTED_EMAIL" ]; then
    echo "BLOCKED: git identity wrong before push"
    echo "  name:  '$ACTUAL_NAME' (want '$EXPECTED_NAME')"
    echo "  email: '$ACTUAL_EMAIL' (want '$EXPECTED_EMAIL')"
    echo "Fix: git config --global user.{name,email} \"$EXPECTED_NAME\" \"$EXPECTED_EMAIL\""
    exit 1
fi

# ============================================================
# 2. Remote must be Fqih's GitHub
# ============================================================
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [ -n "$REMOTE_URL" ]; then
    if echo "$REMOTE_URL" | grep -qiE "(faqihhakim|fqihhakim|gunadarma)"; then
        echo "BLOCKED: remote points to forbidden school alias account"
        echo "  $REMOTE_URL"
        echo "Update to: https://github.com/Fqih/<repo>.git"
        exit 1
    fi
fi

# ============================================================
# 3. Verify push target
# ============================================================
while read local_ref local_sha remote_ref remote_sha; do
    BRANCH=$(echo "$local_ref" | sed 's|refs/heads/||')
    echo "→ pushing $BRANCH ($local_sha)"

    # Block force push ke main/master
    if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
        if [ "$remote_sha" != "0000000000000000000000000000000000000000" ]; then
            echo "BLOCKED: force push ke $BRANCH not allowed"
            exit 1
        fi
    fi
done

# ============================================================
# 4. Full history gitleaks scan (slow, last line of defense)
# ============================================================
GITLEAKS="${HOME}/.local/bin/gitleaks"
if [ -x "$GITLEAKS" ]; then
    CONFIG_FLAG=""
    [ -f ".gitleaks.toml" ] && CONFIG_FLAG="--config .gitleaks.toml"

    if ! "$GITLEAKS" detect \
        --source . \
        $CONFIG_FLAG \
        --exit-code 2 \
        --redact 2>/dev/null; then
        echo ""
        echo "BLOCKED: Secret detected in git history"
        echo "Rotate the leaked credential immediately"
        echo "Untuk removal: git filter-repo (s) atau BFG Repo-Cleaner"
        exit 1
    fi
fi

# ============================================================
# 5. Notify (optional, kalau tg-notify ada)
# ============================================================
if [ -x "${HOME}/.local/bin/tg-notify" ]; then
    BRANCH=$(git branch --show-current)
    REMOTE=$(git remote get-url origin 2>/dev/null | sed 's|.*github.com[:/]||;s|\.git$||')
    "${HOME}/.local/bin/tg-notify "pushing → $REMOTE/$BRANCH" 2>/dev/null || true
fi

exit 0
