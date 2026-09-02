# Fqih's Claude Code Setup

Mirror konfigurasi global Claude Code. Sync antar device via git.

## Apa ini

Mirror skill/rule/agent/command dari `~/.claude/` global. Markdown langsung — copy atau symlink ke `~/.claude/` di device baru.

**Struktur:**
```
.
├── README.md
├── CONTRIBUTING.md   # commit convention + checklist
├── LICENSE           # MIT
├── NOTICE.md         # attribution untuk forked content
├── .gitignore
├── .gitleaks.toml    # config untuk secret-scan
├── rules/            # 9 markdown rules
├── skills/           # 27 markdown skills
├── agents/           # 9 agent definitions
└── commands/         # 25 slash commands
```

Lihat [NOTICE.md](NOTICE.md) untuk attribution dari [WorldFlowAI/everything-claude-code](https://github.com/WorldFlowAI/everything-claude-code) (MIT).

## Profil

- Primary: AI engineer + Data Scientist (Python, ML/DL, ipynb)
- Secondary: Fullstack web (Next.js, TypeScript, Tailwind)
- Stack: Linux Fedora 44 + Windows 11, Tailscale mesh, ROCm + CUDA

## Device

| Device | OS | GPU | Role |
|---|---|---|---|
| ASUS ROG Zephyrus | Fedora 44 | AMD RX 6700S (ROCm, 8GB) | Primary dev + training |
| HP Pavilion | Windows 11 | NVIDIA GTX 1650 (CUDA, 4GB) | Secondary dev, inference ringan |
| HP Android | — | — | Mobile client via Tailscale |

Detail per device di skill [`local-ml-gpu`](skills/local-ml-gpu/SKILL.md).

## Identity rules (WAJIB)

- `user.name`: `Fqih`
- `user.email`: `mhmdfkih21@gmail.com`
- NO Claude co-author di commit message
- NO `🤖 Generated with [Claude Code]` footer

Skill `atomic-github-push` hard-block violation. Skill `secret-scan` hard-block secret leak.

## Skills

Full list di `skills/`. Highlight custom Fqih:

| Skill | Fungsi |
|---|---|
| `atomic-github-push` | Commit + push atomik. Identity + secret scan + ruff lint + rebase + push. |
| `secret-scan` | gitleaks wrapper. Block secret dari nyampe ke GitHub. |
| `telegram-notify` | Notifikasi ke HP via Telegram bot saat long-running job selesai. |
| `remote-workflow` | Tailscale + SSH + code-server. Akses laptop dari HP/Pavilion. |
| `local-ml-gpu` | ROCm (Zephyrus) + CUDA (Pavilion) workflow. |
| `audit-workflow` | 9-dimension audit end-of-sprint, post findings ke GitHub issues. |
| `document-intelligence` | PDF/Word reader + extractor + summarizer (PyMuPDF + python-docx). |
| `natural-writing` | Anti-AI-tells style guide untuk docs + commit messages. |
| `api-docs` | OpenAPI/Swagger auto-gen + MkDocs Material setup. |
| `dependency-audit` | pip-audit + npm audit + SBOM + license compliance. |
| `sql-patterns` | Query optimization + per-engine (Postgres/BigQuery/ClickHouse/DuckDB). |

Plus AI/ML standard: `rag-patterns`, `ml-deployment`, `agent-design`, `llm-engineering`, `eval-harness`, `ds-workflow`, `notebook-hygiene`. Plus fullstack: `fullstack-web`, `backend-patterns`, `frontend-patterns`, `coding-standards`, `docker-patterns`, `tdd-workflow`. Total **27 skills** (17 forked dari ECC + 10 custom Fqih).

## Rules + agents + commands

**9 rules** di `rules/`: agents, coding-style, git-workflow, hooks, patterns, performance, security, testing, scientific-python

**9 agents** di `agents/`: architect, build-error-resolver, code-reviewer, doc-updater, e2e-runner, planner, refactor-cleaner, security-reviewer, tdd-guide

**25 commands** di `commands/` — highlight custom:

| Command | Fungsi |
|---|---|
| `/atomic-push` | Full atomic push workflow |
| `/secret-scan` | Manual gitleaks scan |
| `/pdf-read` | Baca PDF/Word + extract + summarize |
| `/gpu-check` | Verify ROCm/CUDA + compute sanity |
| `/experiment-init` | Init ML experiment dir dengan mlflow + seed |
| `/notebook-strip` | nbstripout output removal |
| `/audit-end-sprint` | 9-dimension audit + post GitHub issues |

Plus forked: `/build-fix`, `/checkpoint`, `/code-review`, `/e2e`, `/eval`, `/learn`, `/orchestrate`, `/plan`, `/refactor-clean`, `/setup-pm`, `/tdd`, `/test-coverage`, `/update-codemaps`, `/update-docs`, `/verify`, `/commit`, `/commit-push-pr`, `/clean_gone`.

## MCP servers

Di `~/.claude.json` → `mcpServers`:

| Server | Purpose |
|---|---|
| `jupyter` | Notebook execution via [datalayer/jupyter-mcp-server](https://github.com/datalayer/jupyter-mcp-server). Butuh `jupyter lab` di port 8888. |
| `filesystem` | File access ke `~/Project` |
| `github` | GitHub API (issues, PRs, repo info) |
| `playwright` | Browser automation + E2E |
| `postgres` | Postgres DB query |

## System tools

| Tool | Versi | Install |
|---|---|---|
| `gitleaks` | 8.30.1+ | Binary ke `~/.local/bin/` (lihat skill `secret-scan`) |
| `mlflow` | 3.15.2+ | `pip install --user mlflow` |
| `nbstripout` | 0.9.1+ | `pip install --user nbstripout` |
| `uvx` | latest | Untuk jupyter-mcp-server isolated env |
| `tailscale` | latest | `curl -fsSL https://tailscale.com/install.sh \| sh` |
| `pymupdf` | 1.28+ | `pip install --user pymupdf` (PDF read) |
| `python-docx` | 1.0+ | `pip install --user python-docx` (Word read) |
| `pypandoc` | 1.10+ | `pip install --user pypandoc` (universal converter) |

## Install di device baru

### Linux (Fedora/Ubuntu/Debian)

```bash
# 1. Clone
git clone https://github.com/Fqih/.mycc-setup.git ~/.mycc-setup

# 2. Git identity (WAJIB)
git config --global user.name "Fqih"
git config --global user.email "mhmdfkih21@gmail.com"

# 3. System tools
pip install --user mlflow nbstripout pymupdf python-docx pypandoc
mkdir -p ~/.local/bin
curl -sL -o /tmp/gitleaks.tar.gz \
    "https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz"
tar xzf /tmp/gitleaks.tar.gz -C ~/.local/bin/ gitleaks
rm /tmp/gitleaks.tar.gz
export PATH="$HOME/.local/bin:$PATH"

# 4. Copy mirror
mkdir -p ~/.claude/{rules,skills,agents,commands}
cp -r ~/.mycc-setup/skills/* ~/.claude/skills/
cp ~/.mycc-setup/rules/*.md ~/.claude/rules/
cp ~/.mycc-setup/agents/*.md ~/.claude/agents/
cp ~/.mycc-setup/commands/*.md ~/.claude/commands/

# 5. Setup git templateDir untuk auto-install hooks di setiap new repo
mkdir -p ~/.claude/git-template/hooks
ln -sf ~/.claude/hooks/pre-commit.sh ~/.claude/git-template/hooks/pre-commit
ln -sf ~/.claude/hooks/pre-push.sh ~/.claude/git-template/hooks/pre-push
git config --global init.templateDir ~/.claude/git-template

# 6. Verify
git config --global user.name   # harus: Fqih
git config --global user.email  # harus: mhmdfkih21@gmail.com
~/.local/bin/gitleaks version
mlflow --version
```

### Windows 11

```powershell
# 1. Clone
git clone https://github.com/Fqih/.mycc-setup.git $HOME\.mycc-setup

# 2. Git identity
git config --global user.name "Fqih"
git config --global user.email "mhmdfkih21@gmail.com"

# 3. Tools
py -m pip install --user mlflow nbstripout pymupdf python-docx pypandoc

# gitleaks: download .zip dari release, ekstrak ke folder di PATH

# 4. Copy mirror
$src = "$HOME\.mycc-setup"
$dst = "$env:USERPROFILE\.claude"
New-Item -ItemType Directory -Force -Path "$dst\rules", "$dst\skills", "$dst\agents", "$dst\commands" | Out-Null
Copy-Item -Recurse -Force "$src\skills\*" "$dst\skills\"
Copy-Item -Force "$src\rules\*.md" "$dst\rules\"
Copy-Item -Force "$src\agents\*.md" "$dst\agents\"
Copy-Item -Force "$src\commands\*.md" "$dst\commands\"
```

## Tailscale mesh

Semua device via akun Tailscale yang sama:

```bash
# Zephyrus (Linux)
curl -fsSL https://tailscale.com/install.sh | sh
sudo systemctl enable --now tailscaled
sudo tailscale up

# Pavilion (Windows)
winget install Tailscale.Tailscale

# HP (Android/iOS)
# install dari Play Store / App Store
```

Setelah login, semua device saling reachable via `100.x.y.z`. SSH: `ssh <user>@100.x.y.z`.

Detail di skill `remote-workflow`.

## Atomic push workflow

Trigger: bilang "commit and push" / "atomic push" / `/atomic-push`.

Urutan step:

1. `git status` clean
2. Identity = `Fqih / mhmdfkih21@gmail.com`
3. Scan secret via `git diff --cached | gitleaks detect --pipe --no-git`
4. Strip notebook output (`nbstripout`)
5. `ruff check .` + `ruff format --check .`
6. Commit message: NO `Co-Authored-By: ...Claude/Anthropic`, NO `🤖 Generated with...`
7. `git commit`
8. `git pull --rebase`
9. Pre-push scan secret (full)
10. `git push`

Step gagal → abort. Tidak ada commit setengah jadi, tidak ada push tanpa verifikasi.

## Audit end-of-sprint

Setiap akhir sprint (default 7 hari window):

```
/audit-end-sprint
```

Run 9-dimension sweep (security, quality, tests, dead code, tech-debt, perf, docs, deps, git-hygiene). Setiap finding → GitHub issue dengan label `audit-sprint-YYYY-MM-DD` + dimension + severity.

Next sprint: `gh issue list --label "audit-sprint-$(date +%Y-%m-%d)"`.

## Security

- Telegram bot token: `~/.config/telegram.env` (chmod 600), **JANGAN** commit
- Tailscale IP: dinamis, tidak perlu dirahasiakan (private mesh)
- SSH keys: `~/.ssh/id_ed25519`, backup ke password manager
- API keys: `~/.config/<service>.env`, `<service>.env.example` di-commit sebagai template

Skill `secret-scan` aktif di atomic push. Hard block `.env`/token di staged files.

## File map

```
~/.claude/
├── rules/          # 9 markdown rules
├── skills/         # 27 markdown skills
├── agents/         # 9 agent definitions
├── commands/       # 25 slash commands
├── hooks/          # pre-commit.sh + pre-push.sh
└── settings.json

~/.claude.json      # MCP servers + user preferences

~/.config/
├── telegram.env    # TELEGRAM_BOT_TOKEN + CHAT_ID (chmod 600)
└── ...

~/.local/bin/
├── gitleaks        # 8.30.1 binary
└── ...
```

## License

MIT. Base content dari [WorldFlowAI/everything-claude-code](https://github.com/WorldFlowAI/everything-claude-code) (MIT).

## Credits

- [WorldFlowAI/everything-claude-code](https://github.com/WorldFlowAI/everything-claude-code) — base skills/rules/agents/commands
- [datalayer/jupyter-mcp-server](https://github.com/datalayer/jupyter-mcp-server) — Jupyter MCP
- [gitleaks/gitleaks](https://github.com/gitleaks/gitleaks) — secret scanner
- [mlflow/mlflow](https://github.com/mlflow/mlflow) — experiment tracking
- [tailscale/tailscale](https://github.com/tailscale/tailscale) — mesh VPN
- [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official) — superpowers + commit-commands
- [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman) — terse output mode
