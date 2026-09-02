---
description: Scan working directory untuk secrets — gitleaks detect mode, custom rules, fail-fast kalau ada leak.
---

# /secret-scan

Scan working directory (staged + unstaged) untuk secret leak. Fail-fast kalau ditemukan.

## Mode 1: Scan staged only (before commit)

```bash
# v8 detect tidak punya --staged; pakai --pipe dengan git diff
git diff --cached | ~/.local/bin/gitleaks detect \
  --no-git \
  --pipe \
  --config .gitleaks.toml \
  --redact \
  --exit-code 2 \
  -v
```

## Mode 2: Scan full working tree

```bash
~/.local/bin/gitleaks detect \
  --no-git \
  --source . \
  --config .gitleaks.toml \
  --redact \
  --exit-code 2 \
  -v
```

## Mode 3: Scan git history

```bash
~/.local/bin/gitleaks detect \
  --source . \
  --config .gitleaks.toml \
  --redact \
  --exit-code 2 \
  -v
```

⚠️ Mode 3 scan seluruh history — bisa lambat untuk repo besar. Untuk repo shared, **jangan rewrite history** tanpa koordinasi tim. Rotate secret yang ke-expose lalu commit removal.

## Mode 4: Scan single file

```bash
~/.local/bin/gitleaks detect \
  --no-git \
  --source path/to/file.py \
  --config .gitleaks.toml \
  --redact \
  -v
```

## Output interpretation

### Clean (exit 0)
```
No leaks found
```

### Leak detected (exit 2)
```
Finding:  api_key
File:    src/config.py
Line:    12
Match:   sk-proj-***REDACTED***<YOUR_KEY>
Secret:  <YOUR_OPENAI_API_KEY_HERE>
```

`--redact` flag sembunyikan sebagian secret tapi tetap tunjukkan bahwa leak ada.

## Custom rules (.gitleaks.toml)

Buat `.gitleaks.toml` di root repo:

```toml
title = "My project secrets"

[extend]
useDefault = true  # include gitleaks built-in rules

[[rules]]
id = "openai-api-key"
description = "OpenAI API key"
regex = '''sk-(proj-)?[A-Za-z0-9]{20,}'''
keywords = ["sk-"]

[[rules]]
id = "anthropic-api-key"
description = "Anthropic API key"
regex = '''sk-ant-[A-Za-z0-9-]{20,}'''
keywords = ["sk-ant-"]

[[rules]]
id = "github-pat"
description = "GitHub Personal Access Token"
regex = '''ghp_[A-Za-z0-9]{36}'''
keywords = ["ghp_"]

[[rules]]
id = "aws-access-key"
description = "AWS Access Key ID"
regex = '''AKIA[0-9A-Z]{16}'''
keywords = ["AKIA"]

[[rules]]
id = "telegram-bot-token"
description = "Telegram Bot API token"
regex = '''[0-9]{8,10}:AAG-[A-Za-z0-9_-]{35}'''
keywords = ["AAG-"]

[[rules]]
id = "generic-password"
description = "Hardcoded password"
regex = '''(?i)(password|passwd|pwd)\s*[=:]\s*["']([^"']{8,})["']'''
keywords = ["password", "passwd", "pwd"]

[allowlist]
description = "Allow test/example secrets"
paths = [
    '''tests/fixtures/.*''',
    '''.*\.example''',
    '''.*\.sample''',
]
regexes = [
    '''test[-_]?key[-_]?here''',
    '''sk-test-.*''',
    '''your[-_]?api[-_]?key[-_]?here''',
]
```

## Install gitleaks (kalau belum)

```bash
# Check
command -v gitleaks || echo "gitleaks not installed"

# Install Linux
GITLEAKS_VERSION="8.30.1"
wget -q "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_amd64.tar.gz" \
    -O /tmp/gitleaks.tar.gz
mkdir -p ~/.local/bin
tar -xzf /tmp/gitleaks.tar.gz -C ~/.local/bin gitleaks
~/.local/bin/gitleaks version
```

Lihat skill `secret-scan` untuk full setup.

## If leak found in own code

```bash
# 1. Rotate the secret IMMEDIATELY (don't just delete from git)
#    - OpenAI: revoke at platform.openai.com
#    - GitHub: revoke at github.com/settings/tokens
#    - AWS: rotate IAM access key

# 2. Replace with env var reference
# Before:
api_key = "<YOUR_OPENAI_API_KEY_HERE>"

# After:
import os
api_key = os.environ["OPENAI_API_KEY"]

# 3. Add to .gitignore
echo ".env" >> .gitignore

# 4. Verify
~/.local/bin/gitleaks detect --no-git --source . --redact -v

# 5. Commit fix
git add .
git commit -m "fix: rotate leaked API key, use env var"
git push
```

## If leak found in public repo (already pushed)

1. **Rotate secret immediately** (assume compromised)
2. Force-push removal (kalau repo pribadi):
   ```bash
   git filter-branch --force --index-filter \
     "git rm --cached --ignore-unmatch path/to/file.py" \
     --prune-empty -- --all
   git push --force
   ```
3. Atau accept the leak dan rotate — force-push tidak efektif kalau repo sudah di-fork.

## Pre-commit + pre-push integration

Lihat skill `atomic-github-push` atau setup di `.git/hooks/`:

```bash
#!/bin/bash
# .git/hooks/pre-commit
~/.local/bin/gitleaks detect \
  --staged \
  --no-git \
  --source . \
  --config .gitleaks.toml \
  --exit-code 2 \
  || { echo "SECRET LEAK DETECTED — commit aborted"; exit 1; }
```

## Notes

- `gitleaks protect --staged` v8 punya bug — exit 0 even with leaks. Always pakai `detect --staged --no-git`
- `--no-git` flag avoid issue dengan git index yang corrupt
- `--redact` flag sembunyikan sebagian secret di output (still detects)
- Custom rules di `.gitleaks.toml` lebih reliable dari default rules
- Default rules kadang miss standard test keys (e.g., `sk-test1234`); custom rules catch these
