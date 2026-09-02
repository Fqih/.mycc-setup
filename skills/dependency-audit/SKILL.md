---
name: dependency-audit
description: Use when auditing third-party dependencies — known CVEs, outdated packages, supply chain risk, SBOM generation, license compliance. Trigger on "pip-audit", "npm audit", "vulnerability", "CVE", "SBOM", "/audit-deps".
---

# dependency-audit

Audit third-party dependencies untuk known vulnerabilities, outdated versions, dan supply chain risk. Local-first, otomatis.

## Per-ecosystem tools

| Ecosystem | Tool | Notes |
|---|---|---|
| **Python** | `pip-audit`, `safety`, `osv-scanner` | pip-audit paling comprehensive |
| **Node** | `npm audit`, `yarn audit`, `osv-scanner` | npm audit built-in |
| **Go** | `govulncheck`, `osv-scanner` | official dari Go team |
| **Rust** | `cargo-audit`, `osv-scanner` | RustSec database |
| **Java/Kotlin** | `dependency-check` (OWASP), `osv-scanner` | OWASP database |
| **Multi** | `osv-scanner` | Cross-ecosystem, OSV database |
| **Docker** | `trivy`, `grype`, `snyk` | Image + filesystem scan |

**Default**: `osv-scanner` untuk cross-ecosystem audit (covers semua dari 1 tool).

## pip-audit (Python)

```bash
pip install pip-audit

# Audit current env
pip-audit

# Strict mode (exit 1 kalau ada vuln)
pip-audit --strict

# Specific requirements file
pip-audit --requirement requirements.txt

# JSON output untuk automation
pip-audit --format json --output audit.json

# Fix otomatis (kalau compatible upgrade ada)
pip-audit --fix
```

Output example:
```
Name       Version  ID                  Fix Versions
---------- -------- ------------------- ------------
requests   2.28.0   PYSEC-2023-xxx      2.31.0
pillow     9.0.0    GHSA-xxx            10.0.1
```

## npm audit (Node)

```bash
npm audit

# JSON output
npm audit --json

# Auto-fix (compatible upgrades only)
npm audit fix

# Force fix (kalau break OK)
npm audit fix --force

# Production-only (skip devDeps)
npm audit --omit=dev
```

Output:
```
3 vulnerabilities (1 low, 2 high)

  high  prototype pollution in lodash
  Package: lodash
  Patched in: >=4.17.21
  Path: lodash@4.17.15
```

## osv-scanner (cross-ecosystem)

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/google/osv-scanner/main/install.sh | sh
sudo mv osv-scanner /usr/local/bin/

# Scan Python project
osv-scanner -r requirements.txt

# Scan Node project
osv-scanner -L lockfile:package-lock.json

# Scan mixed
osv-scanner -r requirements.txt -L lockfile:package-lock.json

# Recursive scan semua manifest files
osv-scanner -r .

# Sarif output untuk GitHub Actions
osv-scanner -r . --format sarif --output osv.sarif
```

## License compliance

```bash
# Python
pip install pip-licenses
pip-licenses --format=markdown --output-file=LICENSES.md

# Per-package list
pip-licenses --format=csv

# Allowlist specific licenses
pip-licenses --allow-only="MIT;BSD;Apache-2.0;ISC"
```

Fail kalau ada GPL (untuk proprietary project) atau unknown.

## SBOM (Software Bill of Materials)

SBOM = list semua dependencies + versions. Untuk compliance, supply chain security, audit.

```bash
# CycloneDX (standard format)
pip install cyclonedx-bom
cyclonedx-py environment -o sbom.json

# For Python requirements
cyclonedx-py requirements requirements.txt -o sbom.json

# SPDX format
pip install spdx-tools
```

## CI integration

### GitHub Actions

```yaml
# .github/workflows/audit.yml
name: Dependency audit
on:
  push:
    paths:
      - 'requirements.txt'
      - 'package.json'
      - 'package-lock.json'
  pull_request:
  schedule:
    - cron: '0 6 * * 1'  # weekly Monday 6am

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: pip-audit
        run: |
          pip install pip-audit
          pip-audit --strict --requirement requirements.txt

      - name: npm audit (kalau ada package.json)
        if: hashFiles('package.json') != ''
        run: |
          npm ci
          npm audit --audit-level=high

      - name: OSV scan
        uses: google/osv-scanner-action@v1
        with:
          scan-args: |-
            -r .
```

## Pre-commit integration

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/pypa/pip-audit
    rev: v2.7.3
    hooks:
      - id: pip-audit
        args: [--strict, --requirement, requirements.txt]
```

## Cadence

| Trigger | Frequency |
|---|---|
| Pre-commit | Quick check (changed deps only) |
| PR | Full audit, block kalau high+ |
| Weekly cron | Full audit, post issue kalau ada finding baru |
| Release | Full audit + SBOM generation |
| Post-incident | Audit specific package atau scope |

## Severity classification

| Severity | Action |
|---|---|
| **Critical** (RCE, auth bypass) | Immediate patch, deploy ASAP |
| **High** (data leak, privilege escalation) | Patch dalam sprint, block release |
| **Medium** (DoS, info disclosure) | Patch dalam 1-2 sprint |
| **Low** (theoretical, hard to exploit) | Backlog, batch fix |

## Auto-update strategy

### Renovate (recommended)

```json5
// renovate.json
{
  "extends": ["config:recommended"],
  "packageRules": [
    {
      "matchDatasources": ["npm"],
      "matchUpdateTypes": ["minor", "patch"],
      "automerge": true,
      "automergeType": "pr"
    },
    {
      "matchDatasources": ["pypi"],
      "schedule": ["every weekend"],
      "groupName": "python deps"
    }
  ]
}
```

### Dependabot (GitHub native)

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "pip"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
```

## Supply chain security

Additional defenses beyond CVE matching:

| Risk | Mitigation |
|---|---|
| **Typosquatting** | `requests` vs `reqests` — pin exact versions, verify hash |
| **Maintainer hijack** | Mirror ke internal registry (Artifactory, npm proxy) |
| **Malicious post-install** | Disable scripts: `npm config set ignore-scripts true` |
| **Dependency confusion** | Scope private packages, use `.npmrc` registry pin |
| **Backdoor in dep** | Sigstore / in-toto verification |

### Hash pinning

Python — `pip install --require-hashes`:
```
# requirements.txt
package==1.2.3 --hash=sha256:abc123...
```

Node — `package-lock.json` auto-pins integrity hash.

## Common pitfalls

| Pitfall | Fix |
|---|---|
| `--fix` breaks runtime | Test in branch, manual upgrade kalau breaking |
| Transitive vuln di devDep | Production-only check (`--omit=dev`) |
| Audit noise dari low-severity | Filter by severity level (`--audit-level=high`) |
| No fix available | Document acceptable risk, schedule revisit |
| Audit fails karena offline | Cache vulnerability DB: `pip-audit --no-deps` atau pre-populate cache |

## Integration dengan audit-workflow

```bash
# Tambahkan ke audit-end-sprint sebagai dimensi tambahan
pip-audit --strict --requirement requirements.txt 2>&1 | tail -10
```

Output → GitHub issue dengan label `deps`, `security`, `audit-sprint-YYYY-MM-DD`.

## Invokation

Auto-trigger:
- Edit `requirements.txt`, `pyproject.toml`, `package.json`, `go.mod`, `Cargo.toml`
- User sebut "vulnerability", "CVE", "outdated", "supply chain"
- Slash command: `/audit-deps`, `/gen-sbom`
