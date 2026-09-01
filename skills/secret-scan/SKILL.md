---
name: secret-scan
description: Use when committing, pushing, or auditing code — blocks any secret (API key, token, password, private key, .env contents) from reaching GitHub. Combines gitleaks scan + custom grep fallback for known-bad patterns. Trigger on "secret", "leak", ".env", "API key", "token", "/secret-scan", "before push".
---

# secret-scan

Cegah env var / API key / token / password bocor ke GitHub. Hard block sebelum commit atau push.

## Tools

### Primary: gitleaks (gold standard, 100+ rules built-in)

**Install satu kali** (binary standalone, zero deps):

```bash
# Versi terbaru cek: https://github.com/gitleaks/gitleaks/releases/latest
# Linux x64:
mkdir -p ~/.local/bin
cd /tmp
curl -sL -o gitleaks.tar.gz \
    "https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz"
tar xzf gitleaks.tar.gz
mv gitleaks ~/.local/bin/
rm gitleaks.tar.gz
chmod +x ~/.local/bin/gitleaks

# macOS (arm64):
curl -sL -o gitleaks.tar.gz \
    "https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_darwin_arm64.tar.gz"
tar xzf gitleaks.tar.gz && mv gitleaks ~/.local/bin/

# Windows: download .zip dari release page, ekstrak, taruh di PATH

# Verify
~/.local/bin/gitleaks version
```

Tambah ke `~/.bashrc` kalau `~/.local/bin` belum di PATH:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

### Fallback: detect-secrets (Python)

```bash
pip install --user detect-secrets
```

### Fallback terakhir: custom grep (zero-install, false positives tinggi)

Lihat section "Pattern grep fallback" di bawah.

## Workflow

### ⚠️ gitleaks v8 binary reality check

Binary release `gitleaks_8.30.1_*` di beberapa versi **tidak bundle default rules dengan benar**. `detect` default mode return exit 1 (good), tapi `protect --staged` return exit 0 walaupun leak (BUG). Solusi:

1. **Selalu pakai `detect --staged --no-git --source .`** (bukan `protect --staged`).
2. **Sediakan custom `.gitleaks.toml`** di root repo (lihat template di bawah). Default rules via `[extend].useDefault = true` lebih reliable di beberapa environment.

### 1. Pre-commit check (sebelum commit, scan staged files)

```bash
# pakai detect mode (exit code reliable)
gitleaks detect \
    --no-banner \
    --no-git \
    --source . \
    --config .gitleaks.toml \
    --exit-code 1

# exit code: 0 = clean, 1 = leak detected
```

**Kalau exit 1: BLOCK. Jangan commit. Jangan `--no-verify`.**

### Template `.gitleaks.toml` (taruh di root repo)

```toml
title = "Avo secrets baseline"

[extend]
useDefault = true

# Custom rules (backup kalau default tidak detect)
[[rules]]
id = "openai-api-key"
description = "OpenAI API Key"
regex = '''sk-(proj-|svcacct-)?[A-Za-z0-9]{20,}(T3BlbkFJ[A-Za-z0-9]{20})?'''
tags = ["key", "openai"]

[[rules]]
id = "anthropic-api-key"
description = "Anthropic API Key"
regex = '''sk-ant-[A-Za-z0-9-]{32,}'''
tags = ["key", "anthropic"]

[[rules]]
id = "github-pat"
description = "GitHub Personal Access Token"
regex = '''ghp_[A-Za-z0-9]{36}'''
tags = ["key", "github"]

[[rules]]
id = "aws-access-key-id"
description = "AWS Access Key ID"
regex = '''AKIA[0-9A-Z]{16}'''
tags = ["key", "aws"]

[[rules]]
id = "generic-secret-assignment"
description = "Generic secret assignment in code"
regex = '''(?i)(api[_-]?key|apikey|secret|token|password|bearer|authorization)\s*[=:]\s*['"]?[A-Za-z0-9_\-.]{20,}['"]?'''
tags = ["generic"]
```

`.gitleaksignore` (root repo):

```gitignore
# Allow test fixtures / docs to have fake secrets
tests/fixtures/dummy-secret.txt:test-001
docs/examples/api-auth.md:rule-2
README.md:generic-secret-assignment
```

### 2. Pre-push check (sebelum push, scan seluruh history)

```bash
# scan semua commits yang akan di-push
gitleaks protect --redact --no-banner -v

# atau scan working tree untuk file yang belum di-commit
gitleaks detect --no-banner -v
```

### 3. Manual audit (scan seluruh repo)

```bash
# detect semua secret di working tree
gitleaks detect --no-banner -v --source .

# atau scan staged only
gitleaks detect --staged --no-banner -v
```

### 4. Output format

```bash
# JSON output untuk CI/parsing
gitleaks detect --no-banner --report-format json --report-path gitleaks-report.json

# redact (tampilkan tapi sembunyikan nilai)
gitleaks detect --no-banner --redact -v
```

## Pattern grep fallback (kalau gitleaks tidak ada)

```bash
# scan staged files untuk pattern umum
STAGED=$(git diff --cached --name-only --diff-filter=ACM)

if [ -n "$STAGED" ]; then
    # cek file yang staged
    echo "$STAGED" | xargs grep -E -n -H \
        -e '(?i)(api[_-]?key|apikey|secret|token|password|passwd|pwd|bearer|authorization)\s*[=:]\s*["\047]?[A-Za-z0-9_\-\.]{16,}' \
        -e '(?i)(aws|amazon)[_-]?(access|secret)?[_-]?key' \
        -e '-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----' \
        -e 'ghp_[A-Za-z0-9]{36}' \
        -e 'sk-[A-Za-z0-9]{20,}' \
        -e 'xox[baprs]-[A-Za-z0-9-]+' \
        -e 'AKIA[0-9A-Z]{16}' \
        && { echo "BLOCKED: possible secret in staged files"; exit 1; }
fi
```

Pattern di atas cover:
- Generic `key=value` / `key: value` (16+ char)
- AWS access key
- PEM private key headers
- GitHub PAT (`ghp_*`)
- OpenAI/Anthropic key (`sk-*`)
- Slack token (`xox*`)
- AWS secret access key ID (`AKIA*`)

**False positives**: dokumentasi, test fixtures, dummy data. Whitelist per-repo via `.gitleaksignore`:

```gitignore
# .gitleaksignore (di root repo)
tests/fixtures/dummy-secret.txt:test-001
docs/examples/api-auth.md:rule-2
```

## Integration dengan atomic-github-push

Skill `atomic-github-push` WAJIB invoke `secret-scan` step **sebelum** commit. Tambahkan ke workflow:

```markdown
1. Cek git status
2. Cek identity (Fqih / mhmdfkih21@gmail.com)
3. **Scan staged files untuk secret (skill secret-scan)** ← TAMBAH INI
4. Stage files
5. Strip notebook output (jika .ipynb)
6. Run ruff checks
7. Cek commit message (no Claude co-author)
8. Commit
9. Pull --rebase
10. Pre-push scan
11. Push
```

## .gitignore patterns WAJIB

Setiap repo harus punya `.gitignore` yang exclude file sensitif:

```gitignore
# Secrets
.env
.env.*
!.env.example
*.pem
*.key
*.p12
*.pfx
credentials.json
service-account.json
secrets.yaml
secrets.yml
```

Gunakan `.env.example` untuk template:
```bash
# .env.example (commit-able)
OPENAI_API_KEY=sk-your-key-here
DATABASE_URL=postgresql://user:pass@localhost:5432/db
```

`.env` asli ada di lokal, di `.gitignore`. Production deploy inject env via Netlify/Cloudflare/Railway dashboard, bukan commit.

## Common pitfalls

| Pitfall | Solusi |
|---|---|
| `.env` terlanjur ter-commit | `git rm --cached .env` + `git commit` + **ROTATE semua secret** (anggap compromised) |
| False positive di test fixture | Tambah ke `.gitleaksignore` atau prefix dengan `EXAMPLE_` |
| `BEGIN PRIVATE KEY` di documentation | Tambah ke `.gitleaksignore` per file:line |
| Secret di git history lama | `git filter-repo` untuk rewrite history, atau rotate secret dan accept history leak |
| gitleaks version lama tidak detect format baru | Update binary ke versi terbaru, cek rule di https://github.com/gitleaks/gitleaks/releases |
| Push ditolak GitHub karena secret | GitHub punya push protection juga. Rotate secret + push ulang setelah fix |

## Kalau secret terlanjur bocor

1. **ROTATE** secret langsung (anggap compromised)
2. Hapus dari staged/working tree
3. Untuk history: `git filter-repo --path sensitive-file --invert-paths` (rewrite history = force push)
4. Atau terima history leak + rotate (kalau repo internal/private)
5. Cek GitHub secret scanning alerts (kalau repo publik)
6. Audit access log platform terkait (AWS, GitHub, OpenAI dashboard)

## Invokation

Auto-trigger saat:
- User sebut "secret", "leak", "API key", "token", ".env", "scan"
- Skill `atomic-github-push` jalan
- Pre-commit/pre-push stage
- Manual: panggil skill ini langsung atau `/secret-scan`
