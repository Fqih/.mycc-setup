# Fqih's Claude Code Setup

Setup Claude Code pribadi saya (Fqih). Repo publik ini jadi **sumber kebenaran** untuk konfigurasi global Claude Code yang sinkron antar device.

## Apa ini

Bukan plugin atau marketplace. Ini adalah **dokumentasi + referensi path** ke skill/rule/command yang saya pakai di `~/.claude/` global, plus script setup untuk device baru.

## Profil

- **Primary**: AI engineer + Data Scientist (Python, ML/DL, ipynb)
- **Secondary**: Fullstack web (Next.js, TypeScript, Tailwind)
- **Stack**: Linux (Fedora 44) + Windows 11, Tailscale mesh VPN, ROCm + CUDA GPU

## Device

| Device | OS | GPU | Role |
|---|---|---|---|
| ASUS ROG Zephyrus | Fedora 44 | AMD RX 6700S (ROCm, 8GB) | Primary dev + training |
| HP Pavilion | Windows 11 | NVIDIA GTX 1650 (CUDA, 4GB) | Secondary dev, inference ringan |
| HP Android | — | — | Mobile client via Tailscale |

Lihat skill [`local-ml-gpu`](skills/local-ml-gpu/SKILL.md) untuk detail setup per device.

## Identity rules (WAJIB)

- `user.name`: `Fqih`
- `user.email`: `mhmdfkih21@gmail.com`
- **NO** Claude co-author di commit message
- **NO** `🤖 Generated with [Claude Code]` footer

Skill `atomic-github-push` hard-block violation. Skill `secret-scan` hard-block secret leak.

## Skills custom (5)

Semua skill terinstall di `~/.claude/skills/`:

| Skill | Fungsi |
|---|---|
| `atomic-github-push` | Commit + push satu unit atomik. Cek identity, scan secret, ruff lint, no Claude co-author, rebase, push. |
| `secret-scan` | gitleaks wrapper. Block secret (API key, token, password) dari nyampe ke GitHub. |
| `telegram-notify` | Notifikasi ke HP via Telegram bot saat long-running job selesai. |
| `remote-workflow` | Tailscale + SSH + code-server. Akses laptop dari HP/Pavilion. |
| `local-ml-gpu` | ROCm (Zephyrus) + CUDA (Pavilion) workflow. |

## Skills, rules, commands terinstall

Base dari [WorldFlowAI/everything-claude-code](https://github.com/WorldFlowAI/everything-claude-code) (MIT, cherry-picked).

**8 rules** di `~/.claude/rules/`:
- agents, coding-style, git-workflow, hooks, patterns, performance, security, testing, scientific-python

**20 skills** di `~/.claude/skills/` — lihat list di setup script.

**9 agents** di `~/.claude/agents/`:
- architect, build-error-resolver, code-reviewer, doc-updater, e2e-runner, planner, refactor-cleaner, security-reviewer, tdd-guide

**15 commands** di `~/.claude/commands/`:
- `/build-fix`, `/checkpoint`, `/code-review`, `/e2e`, `/eval`, `/learn`, `/orchestrate`, `/plan`, `/refactor-clean`, `/setup-pm`, `/tdd`, `/test-coverage`, `/update-codemaps`, `/update-docs`, `/verify`

## MCP servers

Konfigurasi di `~/.claude.json` → `mcpServers`:

| Server | Purpose |
|---|---|
| `jupyter` | Jupyter notebook execution via [datalayer/jupyter-mcp-server](https://github.com/datalayer/jupyter-mcp-server). Butuh `jupyter lab` running di port 8888. |

## System tools

| Tool | Versi | Install |
|---|---|---|
| `gitleaks` | 8.30.1+ | Download binary ke `~/.local/bin/` (lihat skill `secret-scan`) |
| `mlflow` | 3.15.2+ | `pip install --user mlflow` |
| `nbstripout` | 0.9.1+ | `pip install --user nbstripout` |
| `uvx` | latest | Untuk jupyter-mcp-server isolated env |
| `tailscale` | latest | `curl -fsSL https://tailscale.com/install.sh \| sh` |

## Cara install di device baru

### Linux (Fedora/Ubuntu/Debian)

```bash
# 1. Clone repo ini
git clone https://github.com/Fqih/.mycc-setup.git ~/.mycc-setup

# 2. Setup git identity (WAJIB, jangan skip)
git config --global user.name "Fqih"
git config --global user.email "mhmdfkih21@gmail.com"

# 3. Install system tools
pip install --user mlflow nbstripout
mkdir -p ~/.local/bin
curl -sL -o /tmp/gitleaks.tar.gz \
    "https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz"
tar xzf /tmp/gitleaks.tar.gz -C ~/.local/bin/ gitleaks
rm /tmp/gitleaks.tar.gz
export PATH="$HOME/.local/bin:$PATH"

# 4. Install skills/rules/agents/commands dari source
# Base: WorldFlowAI/everything-claude-code
git clone --depth 1 https://github.com/WorldFlowAI/everything-claude-code.git /tmp/ecc
mkdir -p ~/.claude/{rules,skills,agents,commands}
cp /tmp/ecc/rules/*.md ~/.claude/rules/
cp -r /tmp/ecc/skills/* ~/.claude/skills/
cp /tmp/ecc/agents/*.md ~/.claude/agents/
cp /tmp/ecc/commands/*.md ~/.claude/commands/
rm -rf /tmp/ecc

# 5. Install skill custom dari repo ini
cp -r ~/.mycc-setup/skills/* ~/.claude/skills/

# 6. Setup MCP jupyter di ~/.claude.json
# (merge ke mcpServers section — lihat ~/.mycc-setup/mcp-servers.example.json)

# 7. Verify
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
py -m pip install --user mlflow nbstripout

# gitleaks: download .zip dari release, ekstrak ke folder di PATH

# 4. Skills: copy manual isi ~/.mycc-setup/skills/* ke %USERPROFILE%\.claude\skills\

# 5. Edit %USERPROFILE%\.claude.json — tambah mcpServers.jupyter section
```

## Tailscale mesh

Semua device masuk mesh via akun Tailscale yang sama:

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

Setelah login, semua device saling reachable via IP `100.x.y.z`. SSH antar device: `ssh fqih@100.x.y.z`.

Detail di skill `remote-workflow`.

## Atomic push workflow

Trigger: bilang "commit and push" / "atomic push" / `/atomic-push`.

Urutan step (lihat skill untuk lengkap):

1. Cek `git status` clean
2. Cek identity = `Fqih / mhmdfkih21@gmail.com`
3. **Scan secret** dengan `gitleaks detect --staged --no-git --source .`
4. Strip notebook output (`.ipynb` via `nbstripout`)
5. Run `ruff check .` + `ruff format --check .`
6. Cek commit message: **NO** `Co-Authored-By: ...Claude/Anthropic`, **NO** `🤖 Generated with...`
7. `git commit`
8. `git pull --rebase`
9. Pre-push scan secret (full)
10. `git push`

Setengah jalan gagal → abort. Tidak ada commit setengah jadi, tidak ada push tanpa verifikasi.

## Security

- Telegram bot token: simpan di `~/.config/telegram.env` (chmod 600), **JANGAN** commit
- Tailscale IP: dinamis, tidak perlu dirahasiakan (private mesh)
- SSH keys: `~/.ssh/id_ed25519`, backup ke password manager
- API keys (OpenAI/Anthropic/AWS): simpan di `~/.config/<service>.env`, `<service>.env.example` di-commit sebagai template

Skill `secret-scan` aktif secara default di atomic push. Hard block kalau ada `.env`/token di staged files.

## File map

```
~/.claude/
├── rules/          # 9 markdown rules
├── skills/         # 20 markdown skills (5 custom + 15 dari ECC)
├── agents/         # 9 agent definitions
├── commands/       # 15 slash commands
└── settings.json   # model + permission + plugin config

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
